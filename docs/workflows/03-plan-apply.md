# Workflow 3 — Plan & Apply (with diff)

**Playbook:** [`playbooks/03_plan_and_apply.yml`](../../playbooks/03_plan_and_apply.yml)

Uploads a Terraform configuration directory, kicks off a plan, prints the
diff, and (optionally) auto-applies. In AAP, this is the **first half** of
a two-step Workflow Template — the second half is workflow 4 with a human
approval in between.

## What it does

1. Uploads `files/sample_tf_config/` (or any `tf_config_dir` you pass) as
   a new **configuration version**.
2. Triggers a **run** against that CV. Defaults to `plan_only: true`.
3. Renders the **plan diff** via `view_plan` so it shows up in the job
   stdout.
4. Calls `ansible.builtin.set_stats` to expose `tfc_run_id` to any
   downstream Workflow Template node.

## Modules used

`configuration_version`, `run`, `view_plan`.

## How to run locally — plan only

```bash
ansible-playbook playbooks/03_plan_and_apply.yml \
  -e tfc_organization=my-tfc-org \
  -e tfc_workspace=aap-demo-app \
  -e tf_config_dir=$(pwd)/files/sample_tf_config \
  -e auto_apply=false
```

## How to run locally — auto-apply (skip the approval gate)

```bash
ansible-playbook playbooks/03_plan_and_apply.yml \
  -e tfc_organization=my-tfc-org \
  -e tfc_workspace=aap-demo-app \
  -e auto_apply=true
```

## AAP wiring (recommended — two Job Templates)

### Job Template A — "03 - Plan"

| AAP object | Value |
| ---------- | ----- |
| Playbook | `playbooks/03_plan_and_apply.yml` |
| Extra vars | `auto_apply: false` (hard-coded) |
| Survey | `tfc_workspace`*, `tf_config_dir` (optional) |

### Job Template B — "04 - Policy-Gated Apply"

| AAP object | Value |
| ---------- | ----- |
| Playbook | `playbooks/04_policy_gated_apply.yml` |
| Extra vars | (none — gets `tfc_run_id` from prior node) |

### Workflow Template

```
[ 03 - Plan ] ──success──► [ Approval node ] ──approved──► [ 04 - Apply ]
```

In the Approval node, set a long timeout (e.g. 24h) and write a clear
message that includes the workspace + diff hint (`Approve apply for
workspace {{ tfc_workspace }} – check job output for plan diff`).

> **Important:** in the Workflow Template's *Variables* section, check
> **"Variables from prior nodes"** so `tfc_run_id` is auto-promoted into
> the apply job's extra_vars.

## Where the Terraform config comes from

* The default `files/sample_tf_config/main.tf` uses the `random` provider
  so the demo costs nothing.
* For real use, swap `tf_config_dir` for any directory or `.tar.gz` you
  want — the module accepts both. AAP can either ship that directory in
  the same project repo, or pull it from a separate Project synced into
  the EE.

## Common questions

**Q: Can I commit the diff back to git?**
Yes — register `plan_diff.diff`, write it out with `ansible.builtin.copy`,
push it via the `community.general` git module.

**Q: Why not use the `auto_apply` flag on the workspace itself?**
That puts the apply decision *inside* TFC and outside AAP's audit trail.
Driving apply explicitly from AAP keeps the entire pipeline observable in
one place.
