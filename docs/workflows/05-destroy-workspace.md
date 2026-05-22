# Workflow 5 — Destroy Workspace

**Playbook:** [`playbooks/05_destroy_workspace.yml`](../../playbooks/05_destroy_workspace.yml)

Safely tears a workspace down: destroy run → wait → delete the workspace
shell.

## What it does

1. Looks up the workspace ID.
2. Triggers a `is_destroy: true, auto_apply: true` run and waits up to
   30 minutes.
3. Deletes the (now empty) workspace.

Safe by default — `state: absent` on a workspace with managed resources
will refuse to delete unless `force_delete: true`.

## Modules used

`workspace_info`, `run`, `workspace`.

## How to run locally

```bash
ansible-playbook playbooks/05_destroy_workspace.yml \
  -e target_workspace=billing-pr-1234 \
  -e force_delete=false
```

## AAP wiring

| AAP object | Value |
| ---------- | ----- |
| Job Template name | `05 - Destroy Workspace` |
| Survey | `target_workspace`*, `force_delete` (choice true/false, default false) |
| Notifications | wire to ops Slack on **Started** and **Success** |

> Strongly consider gating this Job Template behind an Approval node in a
> Workflow Template even when run as a one-shot. Operators have been
> known to typo workspace names.

## Common extensions

* **PR-environment teardown**: fire this from a CI webhook when a PR
  closes. Match `target_workspace` to your PR-naming convention
  (`billing-pr-<num>`).
* **Scheduled cleanup of stale PR envs**: combine with the
  `auto_destroy_activity_duration` on the project so TFC fires destroys
  on its own, and use this Job Template just for the workspace-deletion
  step.
