# Workflows

End-to-end customer scenarios. Each one maps to a single playbook in
[`playbooks/`](../../playbooks/) and (usually) one Job Template in AAP. The
plan/apply story spans two Job Templates connected by an approval node.

| # | Workflow | Playbook | Doc |
| - | -------- | -------- | --- |
| 1 | Org foundation (org + project + var-sets) | `playbooks/01_org_foundation.yml` | [01-org-foundation.md](01-org-foundation.md) |
| 2 | Workspace onboarding (one-shot bootstrap) | `playbooks/02_workspace_onboarding.yml` | [02-workspace-onboarding.md](02-workspace-onboarding.md) |
| 3 | Plan + apply (with diff) | `playbooks/03_plan_and_apply.yml` | [03-plan-apply.md](03-plan-apply.md) |
| 4 | Policy-gated apply | `playbooks/04_policy_gated_apply.yml` | [04-policy-gated-apply.md](04-policy-gated-apply.md) |
| 5 | Destroy workspace | `playbooks/05_destroy_workspace.yml` | [05-destroy-workspace.md](05-destroy-workspace.md) |
| 6 | Configure hosts via dynamic inventory | `playbooks/06_configure_inventory_targets.yml` | [06-dynamic-inventory.md](06-dynamic-inventory.md) |
| 7 | Dev → Stage → Prod promotion | `playbooks/07_promotion_pipeline.yml` | [07-promotion-pipeline.md](07-promotion-pipeline.md) |
| 8 | Rotate workspace secrets | `playbooks/08_rotate_secrets.yml` | [08-rotate-secrets.md](08-rotate-secrets.md) |
| 9 | Scheduled drift audit | `playbooks/09_drift_audit.yml` | [09-drift-audit.md](09-drift-audit.md) |
| 10 | **End-to-end modules-only** (no action plugins — safe on stock EE) | `playbooks/10_e2e_modules_only.yml` | [10-e2e-modules-only.md](10-e2e-modules-only.md) |

> 💡 **Which workflow should I run first on a fresh AAP install?**
> Workflow **#10**. It uses only modules (no action plugins) so it runs
> reliably on the stock "Default execution environment" with the runtime
> pytfe bootstrap. Once you've validated it end-to-end, move on to the
> action-plugin workflows (`02`, `04`, `07`) — those need pytfe in the
> controller python, which usually means a custom EE.
