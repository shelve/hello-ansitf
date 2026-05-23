# AAP × hashicorp.terraform — Demo & Test Repo

End-to-end Ansible playbook repository that exercises every feature of the
[`hashicorp.terraform`](https://github.com/hashicorp/terraform-ansible-collection)
**v2.0.0** collection from **Ansible Automation Platform (AAP) 2.6**.

The repo is structured so you can:

1. **Browse focused single-module examples** under [`examples/`](examples/) to
   learn what each module does in isolation.
2. **Run end-to-end workflow playbooks** under [`playbooks/`](playbooks/) that
   string those modules together into realistic customer scenarios.
3. **Wire each playbook into AAP** as a Job Template (or chain several into
   a Workflow Template) following [`docs/02-aap-integration.md`](docs/02-aap-integration.md).

> **Why does pytfe get installed at runtime?** This repo deliberately does NOT
> ship a custom Execution Environment, so customers can try the collection on
> a stock AAP install. Every playbook starts with `playbooks/bootstrap_pytfe.yml`
> which `pip install`s pytfe into the EE. For production, build a custom EE
> with `ansible-builder` and disable this with `-e install_pytfe_at_runtime=false`.
> Full story in [`docs/02-aap-integration.md`](docs/02-aap-integration.md#execution-environment).

---

## Repo layout

```
.
├── ansible.cfg                       # collection path, inventory plugin enable list
├── collections/requirements.yml      # pins hashicorp.terraform == 2.0.0
├── requirements.txt                  # pytfe (for a custom EE build)
├── group_vars/all/                   # org / project / workspace defaults
├── inventories/
│   ├── sample/                       # static localhost (default)
│   ├── tfc_outputs_single/           # outputs source, single workspace
│   ├── tfc_outputs_wildcard/         # outputs source, every workspace (workspace_filters)
│   ├── tfc_statefile_single/         # statefile source, single workspace
│   └── tfc_statefile_wildcard/       # statefile source, every workspace
├── playbooks/
│   ├── bootstrap_pytfe.yml           # imported by every workflow play
│   ├── 01_org_foundation.yml         # WORKFLOW: org + project + var-sets
│   ├── 02_workspace_onboarding.yml   # WORKFLOW: new workspace bootstrap
│   ├── 03_plan_and_apply.yml         # WORKFLOW: upload → plan → apply
│   ├── 04_policy_gated_apply.yml     # WORKFLOW: gate apply on policy outcome
│   ├── 05_destroy_workspace.yml      # WORKFLOW: tear down (destroy + delete)
│   ├── 06_configure_inventory_targets.yml  # WORKFLOW: run CM against TF hosts
│   ├── 07_promotion_pipeline.yml     # WORKFLOW: dev → stage → prod promotion
│   ├── 08_rotate_secrets.yml         # WORKFLOW: rotate workspace secrets
│   └── 09_drift_audit.yml            # WORKFLOW: scheduled drift / failure audit
├── examples/                         # one playbook per module/lookup
├── files/sample_tf_config/           # tiny TF config used by config_version demos
└── docs/
    ├── 01-architecture.md
    ├── 02-aap-integration.md         # ★ read this first for AAP setup
    ├── 03-quickstart-local.md
    ├── workflows/                    # one doc per end-to-end workflow
    └── examples/                     # one-liner index of every example
```

---

## Quickstart (local — verify on your laptop before pushing to AAP)

> ⚠️ **`hashicorp.terraform` is a Red Hat Partner Collection** — it lives on
> Red Hat Automation Hub, **not** on the public Ansible Galaxy. Before the
> `ansible-galaxy collection install` below works, you need to:
> 1. Get an offline token from **console.redhat.com → Automation Hub →
>    "Connect to Hub" → "Load token"**.
> 2. Paste that token into the `token = <put your token here>` line of
>    [`ansible.cfg`](ansible.cfg) (or override with
>    `ANSIBLE_GALAXY_SERVER_PUBLISHED_TOKEN`).
>
> For AAP itself, the token is configured via an **Automation Hub
> Credential** attached to the Project — see
> [`docs/02-aap-integration.md` Step 3](docs/02-aap-integration.md#step-3--create-the-automation-hub-credential-partner-collection-auth).

```bash
# 0. From the repo root
cd /path/to/this/repo

# 1. Install Python deps
python -m venv .venv && source .venv/bin/activate
pip install ansible-core>=2.16 pytfe>=0.1.5

# 2. Configure the Automation Hub token (one-time)
#    Option A: edit ansible.cfg in place
#    Option B: export it
export ANSIBLE_GALAXY_SERVER_PUBLISHED_TOKEN="…offline token from console.redhat.com…"

# 3. Install the collection (reads ansible.cfg's [galaxy_server.published])
ansible-galaxy collection install -r collections/requirements.yml

# 4. Export your TFC/TFE creds (the modules read TFE_TOKEN from env)
export TFE_TOKEN="…your user or team token…"
export TFE_ADDRESS="https://app.terraform.io"   # or your TFE URL

# 5. Run an example
ansible-playbook examples/03_workspace.yml \
  -e tfc_organization=my-tfc-org \
  -e tfc_workspace=aap-demo-app
```

Full walkthrough: [`docs/03-quickstart-local.md`](docs/03-quickstart-local.md).

### Testing a pre-release branch (e.g. upcoming 2.1.0)

Without changing the pinned version that AAP uses, you can override the
collection install at runtime with a Git branch / tag / commit SHA:

```bash
ansible-playbook examples/03_workspace.yml \
  -e collection_git_ref=release-2.1 \
  -e tfc_organization=my-tfc-org \
  -e tfc_workspace=aap-demo-app
```

The same `-e` works inside an AAP Job Template. Details:
[`docs/04-overriding-collection-from-git.md`](docs/04-overriding-collection-from-git.md).

---

## Running on AAP 2.6 (the real target)

Read these in order:

1. [`docs/01-architecture.md`](docs/01-architecture.md) — what plays do what,
   and how the pieces fit.
2. [`docs/02-aap-integration.md`](docs/02-aap-integration.md) — **the step-by-step
   guide** to:
   - Pushing this repo to AWS CodeCommit
   - Creating the AAP Project (Source Control)
   - Creating a custom Credential Type for `TFE_TOKEN`
   - Creating the Inventory + Inventory Source for dynamic inventory
   - Creating Job Templates for each workflow playbook
   - Chaining Job Templates into a Workflow Template
3. Pick a workflow under [`docs/workflows/`](docs/workflows/) — each doc shows
   you the playbook variables, suggested AAP survey fields, and which
   credentials / inventories to attach.

---

## v2.0.0 surface area covered by this repo

| Plugin                                       | Demonstrated in                                   |
| -------------------------------------------- | ------------------------------------------------- |
| `organizations`                              | `examples/01_organization.yml`, `playbooks/01_*` |
| `project`, `project_info`                    | `examples/02_project.yml`, `playbooks/01_*`, `02_*` |
| `workspace`, `workspace_info`                | `examples/03_workspace.yml`, `playbooks/02_*`, `05_*` |
| `workspace_bootstrap` (action)               | `examples/04_workspace_bootstrap.yml`, `playbooks/02_*` |
| `variable`                                   | `examples/05_variable.yml`, `playbooks/02_*`, `08_*` |
| `variable_sets`                              | `examples/06_variable_sets.yml`, `playbooks/01_*` |
| `configuration_version`, `..._info`          | `examples/07_configuration_version.yml`, `playbooks/03_*` |
| `run`, `run_info`                            | `examples/08_run.yml`, `playbooks/03_*`, `05_*`, `07_*` |
| `view_plan` (action)                         | `examples/09_view_plan.yml`, `playbooks/03_*`     |
| `promote_run` (action)                       | `examples/10_promote_run.yml`, `playbooks/04_*`, `07_*` |
| `output`                                     | `examples/11_output.yml`                          |
| `notification_configuration`                 | `examples/12_notification_configuration.yml`, `playbooks/02_*` |
| `run_trigger`                                | `examples/13_run_trigger.yml`, `playbooks/07_*`   |
| `ssh_keys`                                   | `examples/14_ssh_keys.yml`                        |
| `tfc_inv` inventory plugin (statefile)       | `inventories/tfc_statefile_single/`, `playbooks/06_*`        |
| `tfc_inv` inventory plugin (outputs)         | `inventories/tfc_outputs_single/`, `playbooks/06_*`      |
| `tf_output` lookup                           | `examples/11_output.yml`                          |
| `tf_policy_checks` lookup                    | `examples/15_lookup_policy_checks.yml`            |
| `tf_run_events` lookup                       | `examples/15_lookup_policy_checks.yml`, `playbooks/09_*` |
| `tf_variable_set_vars` lookup                | `examples/16_lookup_variable_set_vars.yml`        |

---

## Upgrading to 2.1.0 when it ships

1. Bump the version in [`collections/requirements.yml`](collections/requirements.yml).
2. In AAP: **Resources → Projects → (your project) → Sync** to re-download
   the collection from Automation Hub.
3. Re-run the relevant Job Templates.

No other change is needed — every play imports the collection by namespaced
FQCN, so picking up new modules is purely additive.

**Want to test 2.1.0 BEFORE bumping the pin?** Set
`collection_git_ref=release-2.1` as an extra-var on a single Job Template
to install that branch into the EE at runtime, leaving every other
Job Template on 2.0.0. See
[`docs/04-overriding-collection-from-git.md`](docs/04-overriding-collection-from-git.md).
