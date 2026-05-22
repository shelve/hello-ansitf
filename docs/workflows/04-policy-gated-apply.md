# Workflow 4 — Policy-Gated Apply

**Playbook:** [`playbooks/04_policy_gated_apply.yml`](../../playbooks/04_policy_gated_apply.yml)

Wrapper around the v2.0.0 **`promote_run`** action plugin. Given a run
ID, waits for it to be appliable, evaluates its Sentinel / OPA policy
checks, and applies only if the configured gates pass.

## What it does

* `require_policy_pass: true` — mandatory policy failures block.
* `allow_advisory_failures: true` — soft-mandatory failures don't block.
* `wait: true` — block until the run is appliable (or timeout).
* `auto_apply_when_eligible: true` — actually apply (set to `false` to
  evaluate-only).

Returns a `gates` dict telling you WHY it did or didn't apply.

## Modules used

`promote_run`.

## Inputs

| Variable | Where it comes from |
| -------- | ------------------- |
| `run_id` | A prior Workflow node's `set_stats` (recommended), an extra_var, or a survey when running standalone. |

## How to run locally

```bash
ansible-playbook playbooks/04_policy_gated_apply.yml \
  -e run_id=run-abcd1234efgh5678
```

## AAP wiring

Two patterns:

### Pattern A — second node of a Workflow (the common case)

Job Template `04 - Policy-Gated Apply` with NO survey. The upstream plan
job emits `tfc_run_id` via `set_stats`; the apply job picks it up
automatically.

### Pattern B — standalone "apply this run" Job Template

Same Job Template + a one-field Survey: `run_id` (required).

## Tuning the gates

| You want to… | Set… |
| ------------ | ---- |
| Block on ANY policy failure (incl. advisory) | `allow_advisory_failures: false` |
| Bypass policy entirely for emergency hotfix | `require_policy_pass: false` |
| Evaluate but never apply (audit mode) | `auto_apply_when_eligible: false` |
| Increase wait window for slow plans | `timeout: 1800` |

## How it integrates with TFC notification

If the workspace also has a Slack notification (set up in workflow 2),
both AAP **and** TFC will post — AAP from the job output, TFC from the
workspace events. That's fine; they're complementary (AAP says "the
operator launched the job", TFC says "the apply finished").
