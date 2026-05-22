# Workflow 8 — Rotate Workspace Secrets

**Playbook:** [`playbooks/08_rotate_secrets.yml`](../../playbooks/08_rotate_secrets.yml)

Bulk-pushes sensitive variables across one or more workspaces. The
canonical use: an AAP Schedule fires this monthly with values pulled from
HashiCorp Vault / AWS Secrets Manager / 1Password.

## What it does

For each `(workspace, var)` pair, calls `hashicorp.terraform.variable`
with `sensitive: true`. Adds a fresh `description` containing the
rotation timestamp so you can audit when each var last moved.

## Modules used

`variable`.

## How to run locally

```bash
ansible-playbook playbooks/08_rotate_secrets.yml \
  -e tfc_organization=my-tfc-org \
  -e tfc_workspace=aap-demo-app \
  -e aws_access_key_id=AKIA... \
  -e aws_secret_access_key=...
```

(You'd usually pull the latter two from a credential, not type them in.)

## AAP wiring — recommended pattern

1. Create a **Custom Credential Type** for "AWS Rotation Secrets" with
   two fields (`aws_access_key_id`, `aws_secret_access_key`, both
   `secret: true`).
2. The injector should set `extra_vars:` with both names.
3. Attach the credential to the Job Template — no survey needed.
4. Add a **Schedule** (monthly, 03:00 UTC).

If you generate the keys on-demand (e.g. from Vault), front this Job
Template with another Job Template that:

1. Calls Vault to mint a fresh key pair.
2. Emits them via `set_stats` (as `extra_vars`).
3. Triggers this Job Template as the next node.

## Important caveat (v2.0.0)

From the `variable` module doc:

> Once a variable is marked sensitive, the stored value is write-only;
> the API will not return it. When `sensitive=true`, the module cannot
> detect drift on `value` alone and will treat re-runs with the same
> input as idempotent.

In practice: the module always issues an update for sensitive vars on
re-run, but cannot tell you whether the value actually changed
server-side. The `description: "Rotated by AAP at <timestamp>"` trick is
a clean way to make rotations visible in the audit log.

## Multi-workspace fan-out

```yaml
vars:
  workspaces_to_rotate:
    - billing-prod
    - billing-stage
    - billing-dev
```

The `product()` filter in the play fans every var across every workspace.
For 50 workspaces × 5 vars that's 250 API calls — keep an eye on the
TFC rate limit (30 req/sec/org at time of writing).
