# Workflow 2 — Workspace Onboarding

**Playbook:** [`playbooks/02_workspace_onboarding.yml`](../../playbooks/02_workspace_onboarding.yml)

Self-service workspace creation. Drive it from an AAP survey so an
application team can request a workspace without touching the TFC UI.

## What it does

1. Resolves the demo **project ID** via `project_info`.
2. Creates a **workspace shell** inside that project with the right
   Terraform version, execution mode, drift detection, etc.
3. Uses the v2.0.0 **`workspace_bootstrap`** action to converge the rest
   of the baseline in a single idempotent task — variables, variable-set
   attachments, run triggers, notifications.

## Modules used

`project_info`, `workspace`, `workspace_bootstrap`.

## How to run locally

```bash
ansible-playbook playbooks/02_workspace_onboarding.yml \
  -e tfc_organization=my-tfc-org \
  -e tfc_project=aap-demo \
  -e new_workspace=billing-prod \
  -e environment_tag=prod \
  -e region=us-east-1 \
  -e slack_webhook_url=https://hooks.slack.com/services/XXX/YYY/ZZZ
```

## AAP wiring

| AAP object | Value |
| ---------- | ----- |
| Job Template name | `02 - Workspace Onboarding` |
| Inventory | `Local (TFC ops)` |
| Playbook | `playbooks/02_workspace_onboarding.yml` |
| Credentials | `TFC – my-tfc-org` (+ a Slack credential if you split it out) |
| Survey | `new_workspace`* `environment_tag` (choice: nonprod/stage/prod), `region` (choice list), `slack_webhook_url` (Password type) |

`*` = required.

## Why `workspace_bootstrap` over individual modules?

Pre-2.0.0 a workspace baseline was 4+ separate plays. The action plugin:

* Runs everything in a **single API session** (fewer round trips).
* Reports a structured **change summary** per component (`vars`, `var_sets`,
  `run_triggers`, `notifications`).
* Handles **`reconcile: true`** which removes stale entries that exist on
  the workspace but aren't in the desired state.

Use the individual modules when you only need to tweak one thing at a time
(e.g. rotate a single secret — see workflow 8).

## Common extensions

* **Per-team templates**: store team-specific defaults in
  `group_vars/<team>.yml` and select via `-e teamvars=billing`.
* **Schedule destroy**: set `auto_destroy_at` on the workspace shell to
  guarantee teardown of PR / sandbox environments.
