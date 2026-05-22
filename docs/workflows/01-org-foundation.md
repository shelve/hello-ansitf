# Workflow 1 — Org Foundation

**Playbook:** [`playbooks/01_org_foundation.yml`](../../playbooks/01_org_foundation.yml)

The first thing platform engineers run in a fresh TFC/TFE tenant.
Idempotent — re-run any time you want to update the org or its shared
variable sets.

## What it does

1. Creates / updates the **organization** (cost estimation on, drift
   assessments enforced, 2FA mandatory).
2. Creates / updates a **project** with a 30-day auto-destroy default.
3. Creates two **global variable sets** (`shared-cloud-creds`,
   `global-tags`) that workspaces inherit.

## Modules used

`organizations`, `project`, `variable_sets`.

## How to run locally

```bash
ansible-playbook playbooks/01_org_foundation.yml \
  -e tfc_organization=my-tfc-org \
  -e tfc_project=aap-demo \
  -e admin_email=platform@example.com
```

## AAP wiring

| AAP object | Value |
| ---------- | ----- |
| Job Template name | `01 - Org Foundation` |
| Inventory | `Local (TFC ops)` |
| Project | `Terraform Collection Demo` |
| Playbook | `playbooks/01_org_foundation.yml` |
| Credentials | `TFC – my-tfc-org` |
| Survey | `tfc_organization` (required), `tfc_project` (required), `admin_email` |

## Variations

* **Skip the variable sets** for a minimal foundation: comment out the
  last two tasks. The org + project alone are enough to start onboarding
  workspaces.
* **Per-environment projects**: parameterise `tfc_project` and run the
  playbook three times (`-e tfc_project=dev / stage / prod`).
