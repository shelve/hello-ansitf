# Workflow 7 — Dev → Stage → Prod Promotion

**Playbook:** [`playbooks/07_promotion_pipeline.yml`](../../playbooks/07_promotion_pipeline.yml)

A single playbook parameterised by `source_stage` and `target_stage`. Run
it once per stage in a Workflow Template — the run trigger between
workspaces propagates the change forward, and the per-stage policy gate
controls whether it goes further.

## What each invocation does

1. Ensures a `run_trigger` exists from `source_stage` → `target_stage`
   (skipped on the first stage where source is empty).
2. Kicks off a plan in `target_stage`.
3. Calls `promote_run` to apply ONLY if policy passes
   (`allow_advisory_failures: false` for stricter gating as you move
   toward prod).

## Modules used

`run_trigger`, `run`, `promote_run`.

## Suggested AAP Workflow Template

Three Job Templates (one per stage), each with hard-coded extra_vars:

| Node | Job Template name | extra_vars |
| ---- | ----------------- | ---------- |
| 1 | `07 - Promote: dev` | `target_stage=aap-demo-app-dev` |
| 2 | `07 - Promote: stage` | `target_stage=aap-demo-app-stage`, `source_stage=aap-demo-app-dev` |
| 3 | `07 - Promote: prod` | `target_stage=aap-demo-app-prod`, `source_stage=aap-demo-app-stage` |

Insert Approval nodes between stages:

```
[ dev ] ──► [ Approval: stage? ] ──► [ stage ] ──► [ Approval: prod? ] ──► [ prod ]
```

## Stricter gates higher up the pipeline

The playbook hard-codes `allow_advisory_failures: false` — even soft
policy failures block. If you want different per-stage gating, copy the
file to three variants or thread a `gate_strictness` extra_var through
`promote_run`'s options.

## Why use a run_trigger instead of just calling `run` on the next stage?

Run triggers let TFC kick the next workspace **automatically** if it's
the only thing in the path. The AAP-driven version we use here keeps a
human gate; the run trigger you create is the safety net for the next
PR-merged change that wasn't initiated from AAP.
