# Architecture

This document explains the moving pieces of the repo and how they map to
`hashicorp.terraform` v2.0.0 features.

## High-level picture

```
                ┌───────────────────────────────────────────────┐
                │  AAP 2.6 Controller                           │
                │  ┌───────────────┐   ┌───────────────────┐   │
   git push ──► │  │  Project sync │──►│ Execution Env (EE)│   │
   (CodeCommit) │  │  (this repo)  │   │ + pytfe (runtime) │   │
                │  └───────┬───────┘   └─────────┬─────────┘   │
                │          │                     │             │
                │   ┌──────▼──────┐      ┌───────▼─────────┐  │
                │   │ Inventories │      │ Job / Workflow  │  │
                │   │ (sample,    │      │ Templates       │  │
                │   │  tfc_state, │      │ (run playbooks) │  │
                │   │  tfc_outputs)│     └───────┬─────────┘  │
                │   └─────────────┘              │            │
                └─────────────────────────────────┼────────────┘
                                                  │ HTTPS + TFE_TOKEN
                                                  ▼
                            ┌──────────────────────────────────┐
                            │  HCP Terraform / Terraform       │
                            │  Enterprise                      │
                            │   • orgs, projects, workspaces   │
                            │   • configuration versions, runs │
                            │   • state, outputs, policies     │
                            └──────────────────────────────────┘
```

## Two layers of playbook

### 1. `examples/` — one feature per file

Each example targets exactly **one module, lookup or inventory plugin** so
you can read the file top-to-bottom and understand what it does. None of
them are meant to be the end of a workflow — they exist to teach.

### 2. `playbooks/` — end-to-end workflows

Each workflow plays multiple modules together to deliver a customer
outcome (onboard a workspace, gate an apply, rotate secrets, …). These are
what you'd schedule in AAP. Each one starts with
`import_playbook: bootstrap_pytfe.yml` so the pytfe SDK is guaranteed
present before any module from the collection runs.

## How auth flows

* Every module accepts `tfe_token` and `tfe_address` (see the `common` doc
  fragment in v2.0.0). All playbooks here use
  `tfe_token: "{{ lookup('env', 'TFE_TOKEN') }}"` and
  `tfe_address: "{{ tfe_address }}"`.
* `TFE_TOKEN` is provided by AAP via a **Custom Credential Type** that
  injects the token as an environment variable into the EE.
* Locally, you `export TFE_TOKEN=…` in your shell.

## How dynamic inventory works

`hashicorp.terraform.tfc_inv` has two sources:

| Source       | What it reads                              | When to pick it |
| ------------ | ------------------------------------------ | --------------- |
| `statefile`  | Latest TF state version → `resources[]`    | You want every cloud resource that matches a provider/type list to become a host. |
| `outputs`    | Latest TF outputs (esp. `ansible_host`)    | You want explicit "Ansible should configure these" intent declared in your TF code. The output's shape (object, map(object), list(...)) directly controls hosts and host_vars. |

The two inventory files under [`inventories/`](../inventories/) show both
in action. The outputs source is what the sample Terraform config in
`files/sample_tf_config/main.tf` is designed for.

## Where each v2.0.0 plugin shows up

See the table in the [root README](../README.md#v200-surface-area-covered-by-this-repo).

## Where the collection itself comes from

The collection is installed via three different paths, depending on the
context. All three land at the same on-disk location, so the playbooks
don't care which one happened.

| Path | When | Triggered by |
| ---- | ---- | ------------ |
| **Automation Hub** (Red Hat Partner Collection) | The normal install. | `collections/requirements.yml` processed at AAP Project sync or local `ansible-galaxy collection install`. Requires an Automation Hub token — see [`02-aap-integration.md` Step 3](02-aap-integration.md#step-3--create-the-automation-hub-credential-partner-collection-auth). |
| **Git ref** (runtime override) | Pre-release validation. | `bootstrap_pytfe.yml`'s second play, gated by the `collection_git_ref` extra-var. See [`04-overriding-collection-from-git.md`](04-overriding-collection-from-git.md). |
| **Custom EE** | Production at scale. | Built with `ansible-builder` to bake the pinned collection + pytfe into the image. The two bootstrap plays become no-ops. |

## Idempotency model

* All `state: present` modules (workspace, variable, variable_sets,
  notification_configuration, run_trigger, ssh_keys, project, organizations)
  are idempotent — re-running yields no change.
* `configuration_version` is **not** idempotent — every run uploads a new
  CV. That is intentional; you `register: cv` and feed `cv.id` into the
  next `run` task. The `playbooks/03_plan_and_apply.yml` workflow shows
  this pattern.
* `run` with `state: present` always creates a new run. With
  `state: applied / discarded / canceled` it acts on an existing
  `run_id` and is idempotent once the run reaches that terminal state.
* `workspace_bootstrap` (action plugin) is the recommended way to converge
  many resources at once — fully idempotent, returns a `gates`-like
  change summary.

## Variable conventions

| Where             | What lives there                                    |
| ----------------- | --------------------------------------------------- |
| `group_vars/all/main.yml` | Non-secret defaults: org / workspace names, polling timeouts, `install_pytfe_at_runtime`, `collection_git_ref`. |
| `group_vars/all/vault.yml.example` | Template — copy to `vault.yml`, encrypt with `ansible-vault`, or (better in AAP) put secrets in a Credential. |
| AAP survey        | User-facing prompts (workspace name, region, env). |
| AAP credential    | `TFE_TOKEN` and any cloud creds. |
| Workflow `set_stats` | Pass `tfc_run_id` etc. between Workflow Template nodes. See [`03-plan-apply.md`](workflows/03-plan-apply.md). |
