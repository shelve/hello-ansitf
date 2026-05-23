# Workflow 6 — Configure hosts via Terraform-sourced inventory

**Playbook:** [`playbooks/06_configure_inventory_targets.yml`](../../playbooks/06_configure_inventory_targets.yml)
**Inventory configs:**
* [`inventories/tfc_statefile_single/tfc_inventory.yml`](../../inventories/tfc_statefile_single/tfc_inventory.yml)
* [`inventories/tfc_outputs_single/tfc_inventory.yml`](../../inventories/tfc_outputs_single/tfc_inventory.yml)

The classic Ansible-after-Terraform handoff: Terraform provisions
infrastructure, the `tfc_inv` v2.0.0 inventory plugin reads either the
state or the outputs, and Ansible configures the resulting hosts.

## Two sources, two use cases

### `source: statefile`

The plugin downloads the latest state version via pytfe, walks
`resources[]`, and emits one Ansible host per matching resource
instance. Provider mapping is built in for AWS, Azure, GCP; extend with
`provider_mapping:` for others.

Use when:
* Your Terraform code wasn't written with Ansible in mind.
* You want EVERY EC2/Compute/VM Terraform manages.
* You're OK with cloud-provider-shaped attributes as host_vars.

> **Sensitive attribute stripping**: any Terraform attribute that the
> provider flags as sensitive is dropped — not masked — before host_vars
> are built. References to them in `compose:` / `hostnames:` simply
> won't resolve.

### `source: outputs`

The plugin reads named outputs and shapes hosts from their content. The
output's Terraform type (`object`, `list(object)`, `map(object)`,
primitives) controls how hosts are produced — see the inventory plugin
doc for the full table.

Use when:
* You want explicit "Ansible should configure these" intent in your TF code.
* You want clean field names (no `aws_instance.*` clutter).
* You need a SUBSET of resources Ansible-controllable.

Example output that drives the file `inventories/tfc_outputs_single/`:

```hcl
output "ansible_host" {
  value = {
    for n, i in aws_instance.app : n => {
      public_ip = i.public_ip
      env       = i.tags.Environment
      role      = i.tags.Role
    }
  }
}
```

The `map(object)` shape means each map key becomes a hostname, and the
inner dict fields (`public_ip`, `env`, `role`) become top-level host_vars.

## Running it

### Locally

```bash
ansible-inventory \
  -i inventories/tfc_outputs_single/tfc_inventory.yml \
  --graph

ansible-playbook \
  -i inventories/tfc_outputs_single/tfc_inventory.yml \
  playbooks/06_configure_inventory_targets.yml
```

### On AAP

1. **Resources → Inventories → Add** a new Inventory called
   `TFC outputs — aap-demo-app`.
2. Add a **Source** of type **"Sourced from a Project"**, point at
   `inventories/tfc_outputs_single/tfc_inventory.yml`, attach the `TFC` credential.
3. Sync the source. Hosts should appear.
4. Create a Job Template:
   - Inventory: this new dynamic inventory.
   - Playbook: `playbooks/06_configure_inventory_targets.yml`.
   - Credentials: `TFC` **and** any SSH/Machine credential the target
     hosts need.

## Tuning the inventory file

| You want to… | Add this to the YAML |
| ------------ | -------------------- |
| Use AWS private IPs instead of public | `compose: { ansible_host: private_ip }` |
| Group hosts by tag.Environment | `keyed_groups: [{ key: tags.Environment, prefix: env }]` |
| Pull in DigitalOcean droplets too | add `provider_mapping:` entry |
| Connect to outputs source by ID instead of name | replace `organization`/`workspace` with `workspace_id` |
| Switch which output drives the inventory | set `hosts_from:` to a list of `{output, type}` entries |

## Why no caching?

The v2.0.0 plugin documentation calls out that it **does not support
caching**. For repos with thousands of hosts, schedule the Inventory
Source update on an interval (every 5–15 min) rather than running it on
every job launch.
