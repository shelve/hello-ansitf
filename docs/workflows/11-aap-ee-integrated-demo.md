# Workflow 11 - AAP Integrated Demo (Custom EE + AWS resource + Dynamic Inventory)

**Provisioning playbook:** [`playbooks/11_e2e_aws_inventory_demo_ee.yml`](../../playbooks/11_e2e_aws_inventory_demo_ee.yml)
**Host-config playbook:** [`playbooks/12_demo_configure_targets_from_dynamic_inventory.yml`](../../playbooks/12_demo_configure_targets_from_dynamic_inventory.yml)
**Terraform config:** [`files/aws_ec2_demo_config/main.tf`](../../files/aws_ec2_demo_config/main.tf)

This workflow demonstrates a full AAP story:

1. create/update workspace
2. upload Terraform configuration
3. plan + apply
4. create AWS EC2 resource
5. pull host(s) via Terraform dynamic inventory
6. run Ansible against discovered host(s)

## Prerequisites

- AAP Job Template uses the custom EE image with pytfe baked in.
- `TFE_TOKEN` injected via credential.
- Workspace has AWS auth available (for remote Terraform runs), typically via variable set env vars.
- Inventory Source uses one of:
  - `inventories/tfc_outputs_wildcard/tfc_inventory.yml` (recommended for workflow demo)
  - or a single-workspace outputs inventory adjusted to your workspace.

## AAP Job Templates to create

1. `11 - Demo - Provision AWS (Custom EE)`
   - Playbook: `playbooks/11_e2e_aws_inventory_demo_ee.yml`
   - Inventory: localhost inventory
   - Credential: TFC token credential
   - Suggested survey vars:
     - `tfc_organization`
     - `tfc_project_id_default`
     - `new_workspace`
     - `region` (default `us-east-1`)
     - `environment_tag` (default `demo`)
     - `app_name` (default `aap-demo-app`)
     - `instance_type` (default `t3.micro`)
     - `ssh_ingress_cidr` (default `0.0.0.0/0`)

2. `Inventory Source Sync - Terraform Outputs`
   - Use inventory source update node in workflow (same source used for tfc_inv outputs).

3. `12 - Demo - Configure Targets (Dynamic Inventory)`
   - Playbook: `playbooks/12_demo_configure_targets_from_dynamic_inventory.yml`
   - Inventory: dynamic inventory where source is tfc_inv outputs
   - Extra vars:
     - `target_hosts: env_demo:&role_web`
     - or `target_hosts: "{{ demo_env_group }}:&{{ demo_role_group }}"` if you pass prior-node vars

## Workflow Template graph

```text
11 - Demo - Provision AWS (Custom EE)
    -> Inventory Source Sync - Terraform Outputs
    -> 12 - Demo - Configure Targets (Dynamic Inventory)
```

Enable variable handoff between nodes in workflow template.
The provisioning playbook sets:

- `tfc_workspace`
- `tfc_workspace_id`
- `tfc_run_id`
- `tfc_configuration_version_id`
- `demo_env_group`
- `demo_role_group`

## Validation checkpoints

After node 1:
- Run reaches `applied`.
- Outputs include `instance_id` and `public_ip`.

After inventory sync:
- `ansible-inventory --graph` equivalent in AAP includes `env_demo` and `role_web` groups.

After node 3:
- `/etc/aap-demo-marker` exists on target host.
- `nginx` installed and running.

## Cleanup

Use `playbooks/05_destroy_workspace.yml` to destroy and remove workspace:

```bash
ansible-playbook playbooks/05_destroy_workspace.yml \
  -e tfc_organization=<org> \
  -e target_workspace=<workspace>
```
