# Workflow 9 — Scheduled Drift / Failure Audit

**Playbook:** [`playbooks/09_drift_audit.yml`](../../playbooks/09_drift_audit.yml)

Runs on a schedule (daily). For each watched workspace, pulls the recent
run event timeline and prints a summary. Designed to feed into a
Slack/email notification, or to be the body of an Ops dashboard.

## What it does

1. Looks up each workspace's `current-run-id`.
2. For each, calls the `tf_run_events` lookup with `since=24h ago` to
   pull the timeline.
3. Builds a `recent_events` dict keyed by workspace name.

## Plugins used

`workspace_info`, `tf_run_events` lookup.

## How to run locally

```bash
ansible-playbook playbooks/09_drift_audit.yml \
  -e tfc_organization=my-tfc-org \
  -e tfc_workspace=aap-demo-app
```

## AAP wiring

| AAP object | Value |
| ---------- | ----- |
| Job Template | `09 - Drift Audit` |
| Schedule | Daily, 06:00 UTC |
| Notification | wire to Slack on **Success** so the digest is posted |

## Extending it

* **Watch every workspace in the org**: replace the hard-coded
  `audit_workspaces` list with a loop over `organization_info` (when
  that becomes available) or maintain a curated list in
  `group_vars/all/main.yml`.
* **Filter to only failed runs**: add a `selectattr('action', 'equalto',
  'errored')` filter when consuming `recent_events`.
* **Post directly to Slack from the playbook**: use the
  `community.general.slack` module after building the digest.

## Why `tf_run_events` not the `run_info` module?

`run_info` returns the run object once. The events lookup returns the
**timeline** (state transitions, comments, policy outcomes), which is
exactly what an "audit" play wants. The two are complementary — use
`run_info` for the latest snapshot, `tf_run_events` for what happened
over a window.
