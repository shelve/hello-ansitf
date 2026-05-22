# Workflow 10 — End-to-end Terraform run (modules-only, no action plugins)

**Playbook:** [`playbooks/10_e2e_modules_only.yml`](../../playbooks/10_e2e_modules_only.yml)
**Terraform code:** [`files/null_tf_config/main.tf`](../../files/null_tf_config/main.tf) — uses the `null` + `random` providers, zero cloud cost.

A single Job Template that walks the full Terraform lifecycle:

```
project_info → workspace → variable (×3) → configuration_version → run (plan)
       → run_info → run (apply) → output → set_stats
```

Every step is a **module**. No action plugins are invoked.

---

## Why a modules-only path

This playbook exists to dodge an EE / interpreter mismatch that bites people
running this collection on the **stock AAP "Default execution environment"**:

| Plugin type | Where it executes | Where `pip install pytfe` lands by default |
| ----------- | ----------------- | ------------------------------------------ |
| **Module** (workspace, variable, configuration_version, run, run_info, output, …) | Target host's Python (here: localhost → EE's task python) | Same place → **works**. |
| **Action plugin** (workspace_bootstrap, promote_run, view_plan) | Controller's Python — the EE's interpreter running `ansible-playbook` itself | Often a **different** Python on multi-Python EEs → action plugin fails to `import pytfe` even though the modules later succeed. |

`ansible.builtin.pip` (from `bootstrap_pytfe.yml`) installs into the
interpreter resolved by `ansible_python_interpreter`. On most EEs that's the
target-task python, not the controller python. The modules don't care
because they're shipped there anyway. Action plugins do — they need pytfe
*in the controller's site-packages, before the playbook even starts running
the first task*.

**Two ways out:**

1. **Use modules only** — this playbook. Safe on the stock EE. Tradeoff:
   no `workspace_bootstrap` one-shot, no `promote_run` policy gate, no
   `view_plan` diff rendering.
2. **Build a custom EE** that bakes pytfe in at image build time. Then the
   bootstrap play becomes a no-op and the action-plugin workflows
   ([`02_workspace_onboarding.yml`](../../playbooks/02_workspace_onboarding.yml),
   [`04_policy_gated_apply.yml`](../../playbooks/04_policy_gated_apply.yml)) work cleanly.
   See [`docs/02-aap-integration.md` → Execution Environment](../02-aap-integration.md#execution-environment--pytfe--custom-ees-deep-dive).

Use this playbook today; migrate to the action-plugin variants once you
have a custom EE.

---

## What it does, step by step

| # | Task | Module / plugin (all modules) | What it produces |
| - | ---- | ----------------------------- | ---------------- |
| 1 | Resolve project | `project_info` | `proj.project.id` |
| 2 | Create / update workspace inside that project | `workspace` | `ws.workspace.id` |
| 3 | Set three input variables (`region`, `environment`, `app_name`) | `variable` × 3 | drift-reconciled vars |
| 4 | Upload `files/null_tf_config/` as a configuration version | `configuration_version` | `cv.configuration_version.id` |
| 5 | Plan run (plan_only=false, auto_apply=false) | `run` | `planned.run.id`, status `planned` |
| 6 | Read back the planned run's metadata | `run_info` | summary printed to stdout |
| 7 | Apply the run via `state: applied` | `run` | run reaches `applied` |
| 8 | Read all workspace outputs | `output` | `outs.outputs` printed |
| 9 | Expose IDs to downstream Workflow nodes | `ansible.builtin.set_stats` | `tfc_workspace_id`, `tfc_run_id`, `tfc_configuration_version_id` |

Re-running with the same survey inputs: steps 1–3 + 7–9 are idempotent;
step 4 always creates a new CV; step 5 always creates a new run (which then
either does or doesn't have changes depending on whether the vars moved).

---

## Local smoke test (before pushing to AAP)

```bash
export TFE_TOKEN='…'
ansible-playbook playbooks/10_e2e_modules_only.yml \
  -e tfc_organization=my-tfc-org \
  -e tfc_project=aap-demo \
  -e new_workspace=modules-only-demo \
  -e environment_tag=nonprod \
  -e region=us-east-1 \
  -e app_name=aap-demo-app
```

Re-run with a different `region` to see a non-trivial plan diff (the
`null_resource.deployment` resource is `triggers`-bound to all three input
vars, so changing any of them forces replacement on the next run).

---

## AAP 2.6 — end-to-end Job Template setup

Pre-requisites (one-time, from [docs/02-aap-integration.md](../02-aap-integration.md)):

* ✅ CodeCommit Source Control credential created.
* ✅ Automation Hub credential created and bound to the Project.
* ✅ Project synced and shows `hashicorp.terraform 2.0.0` in its collections.
* ✅ Custom Credential Type `Terraform Cloud Token` (Step 5) created.
* ✅ A credential of type `Terraform Cloud Token` named e.g. `TFC – my-tfc-org` exists.
* ✅ A Local-only inventory `Local (TFC ops)` exists with a single host
  `localhost` (`ansible_connection: local`).

### 1. Create the Job Template

Controller → **Resources → Templates → Add → Job Template**.

| Field | Value |
| ----- | ----- |
| **Name** | `10 - E2E Modules Only` |
| Job Type | **Run** |
| Inventory | `Local (TFC ops)` |
| Project | `Terraform Collection Demo` (your synced Project) |
| Execution Environment | `Default execution environment` (no custom EE needed) |
| Playbook | `playbooks/10_e2e_modules_only.yml` |
| Credentials | `TFC – my-tfc-org` |
| Limit | (leave blank) |
| Verbosity | `0 (Normal)` (bump to 2 if you want every API call shown) |
| Options | ✅ Update Revision on Launch (so each run picks up the latest commit) |
| Extra variables | (leave blank — use the survey instead) |

### 2. Attach a Survey

Open the Job Template → **Survey** tab → toggle **Enabled** → **Add**:

| Variable | Type | Question | Default | Required |
| -------- | ---- | -------- | ------- | -------- |
| `tfc_organization` | Text | Terraform Cloud / Enterprise organization | `my-tfc-org` | ✅ |
| `tfc_project` | Text | Project that owns the workspace | `aap-demo` | ✅ |
| `new_workspace` | Text | New / target workspace name | `modules-only-demo` | ✅ |
| `environment_tag` | Multiple Choice (single) | Environment label | `nonprod` (with options nonprod/stage/prod) | ✅ |
| `region` | Multiple Choice (single) | Region label | `us-east-1` (with a few options) | ✅ |
| `app_name` | Text | App name prefix | `aap-demo-app` | ✅ |

Save the survey.

### 3. Launch and verify

Click **🚀 Launch**. AAP will:

1. Pull the latest commit (Update Revision on Launch).
2. Open the survey — fill it in → **Next** → **Launch**.
3. Spin up the EE, inject `TFE_TOKEN` from the credential as an env var.
4. Run `bootstrap_pytfe.yml` first — install pytfe into the EE Python.
5. Run the nine tasks above. The job stdout shows each module's debug
   output — final tasks print the workspace outputs.

Watch the run materialise in TFC at
`https://app.terraform.io/app/{{ tfc_organization }}/workspaces/{{ new_workspace }}/runs`.

### 4. Wire it into a Workflow Template (optional, recommended)

The playbook emits `tfc_run_id`, `tfc_workspace_id`, and
`tfc_configuration_version_id` via `set_stats`. So you can chain follow-on
Job Templates that consume those without surveys:

```
┌─────────────────────────┐   success  ┌────────────────────────────┐
│ 10 - E2E Modules Only   │───────────►│ 06 - Configure Inventory   │
└─────────────────────────┘            │      Targets               │
                                       └────────────────────────────┘
```

In the Workflow Template **Variables** tab, enable **"Variables from prior
nodes"** — `tfc_workspace_id` is then a top-level extra_var in the next
node.

### 5. Add a Notification (optional)

Controller → **Administration → Notifications → Add** → create a Slack /
Email template. Attach to the Job Template's **Notifications** tab on
**Started**, **Success**, **Failure**.

---

## Cleaning up

Use [`playbooks/05_destroy_workspace.yml`](../../playbooks/05_destroy_workspace.yml)
to tear down — it's also modules-only (`workspace_info`, `run`, `workspace`)
so it works on the stock EE too.

```bash
ansible-playbook playbooks/05_destroy_workspace.yml \
  -e tfc_organization=my-tfc-org \
  -e target_workspace=modules-only-demo
```

---

## Troubleshooting

| Symptom | Cause | Fix |
| ------- | ----- | --- |
| `ModuleNotFoundError: pytfe` on a `workspace_bootstrap` / `promote_run` / `view_plan` task in OTHER playbooks | Action plugin loaded in controller python; pytfe is on target python only | Use THIS playbook, or build a custom EE that bakes pytfe in (see [02-aap-integration.md](../02-aap-integration.md#execution-environment--pytfe--custom-ees-deep-dive)) |
| `Failed to find configuration version` on step 4 | `tf_config_dir` points at the wrong path on the EE | Pass `-e tf_config_dir=<path inside the EE>` — defaults to the repo's `files/null_tf_config/` which AAP mounts under the project checkout |
| Plan reaches `planned_and_finished` and apply step skips | Run was created plan-only somehow (e.g. user toggled `plan_only=true`) | Set `plan_only: false` (the default in this playbook) |
| `Job timed out` on step 5 | A large workspace plan exceeds the default `run_poll_timeout_seconds` | Bump `-e run_poll_timeout_seconds=1800` |
| Outputs in step 8 are empty | Apply didn't actually run, OR the Terraform code has no `output` blocks | Confirm step 7 shows `final status = applied`; the shipped `null_tf_config/main.tf` declares four outputs |
