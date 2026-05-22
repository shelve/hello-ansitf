# Examples — one feature per file

Each playbook under [`examples/`](../../examples/) demonstrates exactly one
module, lookup, or inventory-driven idea. Read these to learn what a single
piece of the collection does; for end-to-end customer scenarios go to
[`workflows/`](../workflows/).

| # | File | What it shows |
| - | ---- | ------------- |
| 01 | [`01_organization.yml`](../../examples/01_organization.yml) | `organizations` module — create / update a TFC org |
| 02 | [`02_project.yml`](../../examples/02_project.yml) | `project` + `project_info` — manage projects, look one up by name |
| 03 | [`03_workspace.yml`](../../examples/03_workspace.yml) | `workspace` + `workspace_info` — create, update, lock, unlock |
| 04 | [`04_workspace_bootstrap.yml`](../../examples/04_workspace_bootstrap.yml) | **`workspace_bootstrap` action** — converge vars, var-sets, triggers, notifications in one task |
| 05 | [`05_variable.yml`](../../examples/05_variable.yml) | `variable` — single workspace var, including a sensitive env var |
| 06 | [`06_variable_sets.yml`](../../examples/06_variable_sets.yml) | `variable_sets` — manage a set and reconcile its workspace attachments |
| 07 | [`07_configuration_version.yml`](../../examples/07_configuration_version.yml) | `configuration_version` — upload a `.tf` directory as a new CV |
| 08 | [`08_run.yml`](../../examples/08_run.yml) | `run` — plan-only run, then conditionally apply |
| 09 | [`09_view_plan.yml`](../../examples/09_view_plan.yml) | `view_plan` — diff and JSON renderings of a run's plan |
| 10 | [`10_promote_run.yml`](../../examples/10_promote_run.yml) | **`promote_run` action** — policy-gated apply |
| 11 | [`11_output.yml`](../../examples/11_output.yml) | `output` module + `tf_output` lookup |
| 12 | [`12_notification_configuration.yml`](../../examples/12_notification_configuration.yml) | `notification_configuration` — Slack + email |
| 13 | [`13_run_trigger.yml`](../../examples/13_run_trigger.yml) | `run_trigger` — cross-workspace fan-out |
| 14 | [`14_ssh_keys.yml`](../../examples/14_ssh_keys.yml) | `ssh_keys` — org SSH key for private module repos |
| 15 | [`15_lookup_policy_checks.yml`](../../examples/15_lookup_policy_checks.yml) | `tf_policy_checks` + `tf_run_events` lookups |
| 16 | [`16_lookup_variable_set_vars.yml`](../../examples/16_lookup_variable_set_vars.yml) | `tf_variable_set_vars` lookup |

## Running an example locally

```bash
export TFE_TOKEN=…
ansible-playbook examples/03_workspace.yml \
  -e tfc_organization=my-tfc-org \
  -e tfc_workspace=demo
```

Every example `import_playbook:`s `playbooks/bootstrap_pytfe.yml` at the
top, so pytfe is guaranteed available before any module call.

## Running an example as an AAP Job Template

The recipe is identical to the workflow Job Templates — see
[`../02-aap-integration.md`](../02-aap-integration.md#step-6--create-job-templates-one-per-playbook).
The only practical difference: examples are mostly "trial it" jobs, so
you typically want the `LAUNCH` button enabled and may not bother with a
survey.
