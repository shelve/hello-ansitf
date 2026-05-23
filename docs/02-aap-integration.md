# AAP 2.6 Integration — step-by-step

This is the most important doc in the repo. It walks an AAP-new operator
through everything that has to exist on the Controller before you can run a
single playbook from this repo.

> Conventions: "the Controller" = the AAP web UI at `https://<aap-host>/`.
> Menu paths use the AAP 2.6 navigation (**Resources** → … / **Administration** → …).

---

## Concepts you'll meet (1-minute primer)

| AAP thing | What it is | This repo's equivalent |
| --------- | ---------- | ---------------------- |
| **Project** | A git checkout AAP pulls and re-pulls on demand. | This repo, cloned into AAP. |
| **Execution Environment (EE)** | A container image with Python + ansible-core + collections. | We use the stock `Default execution environment` + `bootstrap_pytfe.yml`. |
| **Credential** | A typed secret bundle that gets injected into the EE at job time (as env vars or extra_vars). | The custom `Terraform Cloud Token` credential type holds `TFE_TOKEN`. |
| **Inventory** | A list of hosts. Can be static (a YAML file) or sourced from a plugin. | Either `inventories/sample/` or one of the four `inventories/tfc_*` dynamic configs (single vs wildcard × outputs vs statefile). |
| **Inventory Source** | A child of an Inventory that runs an inventory plugin on a schedule (or on demand). | The `tfc_inv` plugin reading from a project file. |
| **Job Template** | "Run *this* playbook against *that* inventory with *those* credentials, optionally asking the user *these* questions (the survey)." | One per workflow playbook. |
| **Workflow Template** | A DAG of Job Templates with approval nodes. | The plan → approval → apply workflow. |
| **Schedule** | A cron-style recurring trigger. | Used by `09_drift_audit.yml`. |

---

## Step 1 — push this repo to AWS CodeCommit

```bash
# In this repo
git add .
git commit -m "Initial AAP demo for hashicorp.terraform v2.0.0"

# Create the CodeCommit repo (one-time)
aws codecommit create-repository --repository-name aap-terraform-demo --region <region>

# Add the remote (HTTPS shown — SSH works too if you've set up keys)
git remote add origin \
  https://git-codecommit.<region>.amazonaws.com/v1/repos/aap-terraform-demo

git push -u origin main
```

You'll need a **CodeCommit HTTPS git credential** (IAM user → Security
Credentials → HTTPS Git credentials) or the `git-remote-codecommit` helper
configured locally.

## Step 2 — create the AAP Source Control credential

Controller → **Resources** → **Credentials** → **Add**.

| Field | Value |
| ----- | ----- |
| Name | `CodeCommit – aap-terraform-demo` |
| Credential Type | **Source Control** |
| Username | your IAM HTTPS git username |
| Password | your IAM HTTPS git password (use **Vault** if you're brave) |

## Step 3 — create the Automation Hub credential (Partner Collection auth)

> ⚠️ **Important — `hashicorp.terraform` is a Red Hat Partner Collection.**
> It is NOT on the public Ansible Galaxy. AAP must be told to install it
> from **Red Hat Automation Hub** at `console.redhat.com`, which requires
> an authenticated offline token. Skipping this step makes Project sync
> fail with `Failed to download collection hashicorp.terraform`.

### 3a. Get the token

1. Open **console.redhat.com → Automation Hub → "Connect to Hub"**.
2. Click **"Load token"**. This produces an **offline token**
   (long-lived, single-use to mint short-lived access tokens).
3. Copy it.

### 3b. Create the Credential

Controller → **Resources** → **Credentials** → **Add**.

| Field | Value |
| ----- | ----- |
| Name | `Red Hat Automation Hub` |
| Credential Type | **Ansible Galaxy/Automation Hub API Token** |
| Galaxy Server URL | `https://console.redhat.com/api/automation-hub/` (or `.../content/published/` for the canonical Certified path) |
| Auth Server URL | `https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token` |
| API Token | (paste the offline token from Step 3a) |

### 3c. Optional — also wire the public Galaxy as a fallback

`ansible.utils` and `community.general` (used by some plays in this repo)
live on the public Galaxy. If your AAP install already has the bundled
**Ansible Galaxy** credential it's fine; otherwise add a second Credential:

| Field | Value |
| ----- | ----- |
| Name | `Ansible Galaxy (public)` |
| Credential Type | **Ansible Galaxy/Automation Hub API Token** |
| Galaxy Server URL | `https://galaxy.ansible.com/api/` |
| API Token | (anonymous reads are allowed — token optional) |

## Step 4 — create the Project

Controller → **Resources** → **Projects** → **Add**.

| Field | Value |
| ----- | ----- |
| Name | `Terraform Collection Demo` |
| Source Control Type | **Git** |
| Source Control URL | `https://git-codecommit.<region>.amazonaws.com/v1/repos/aap-terraform-demo` |
| Source Control Branch | `main` |
| Source Control Credential | `CodeCommit – aap-terraform-demo` |
| Content Signature Validation Credential | (leave blank unless you've signed the collection) |
| Options | ✅ **Clean** ✅ **Delete** ✅ **Update Revision on Launch** |

After saving, open the Project, go to the **Access** tab → **Add** the
**Automation Hub** credential created in Step 3b (and the public Galaxy
one from Step 3c if you made it). AAP uses these when processing
`collections/requirements.yml` during sync.

> 🔑 **Why two credential bindings?** AAP picks the right Galaxy server per
> collection by walking the credential list and matching against each
> server's URL. Without the Automation Hub credential, the
> `hashicorp.terraform` entry in `requirements.yml` fails because the
> public Galaxy can't find it.

Hit **Save** then **Sync** (cycle-arrow icon). A successful sync will:

* clone your CodeCommit repo into the Project's working dir,
* read `collections/requirements.yml`,
* install `hashicorp.terraform == 2.0.0` from **Automation Hub** (via the
  credential), and `ansible.utils` / `community.general` from public Galaxy,
* leave them in the EE's collections path for every Job Template that
  references this Project.

## Step 4b — upgrading the pinned version (e.g. when 2.1.0 ships)

1. Bump the version in `collections/requirements.yml` in this repo.
2. Push to CodeCommit.
3. Controller → **Resources** → **Projects** → (your project) → **Sync**.

That's it — every Job Template using the Project picks up the new
collection automatically on its next launch.

If you want to validate 2.1.0 in **one** Job Template BEFORE pinning it
globally, see [docs/04-overriding-collection-from-git.md](04-overriding-collection-from-git.md)
— it lets a single job install the collection from a git branch at
runtime without changing what other jobs see.

## Step 5 — create a custom Credential Type for `TFE_TOKEN`

We need AAP to inject the token into the EE as an env var. Built-in
credentials don't have a "Terraform Cloud" type yet, so we make one.

Controller → **Administration** → **Credential Types** → **Add**.

| Field | Value |
| ----- | ----- |
| Name | `Terraform Cloud Token` |
| Input configuration | (paste below) |
| Injector configuration | (paste below) |

**Input configuration** (YAML):

```yaml
fields:
  - id: tfe_token
    type: string
    label: TFC/TFE API Token
    secret: true
  - id: tfe_address
    type: string
    label: TFC/TFE API URL
    default: https://app.terraform.io
required:
  - tfe_token
```

**Injector configuration** (YAML):

```yaml
env:
  TFE_TOKEN: '{{ tfe_token }}'
  TFE_ADDRESS: '{{ tfe_address }}'
extra_vars:
  tfe_address: '{{ tfe_address }}'
```

Now go to **Resources** → **Credentials** → **Add** and create a
credential of type **Terraform Cloud Token**, fill in your token + URL.
Call it e.g. `TFC – my-tfc-org`.

## Step 6 — create the Inventories

You can have all three. Pick whichever each Job Template needs.

### 6a. Static "localhost" inventory (for plays that only talk to the TFC API)

Controller → **Resources** → **Inventories** → **Add inventory**.

| Field | Value |
| ----- | ----- |
| Name | `Local (TFC ops)` |
| Variables | `{}` (leave empty) |

Then **Hosts → Add**, name = `localhost`, variables:

```yaml
ansible_connection: local
```

### 6b. Dynamic inventory from Terraform STATE

Controller → **Resources** → **Inventories** → **Add inventory**. Name it
`TFC state — aap-demo-app`.

Then **Sources → Add**:

| Field | Value |
| ----- | ----- |
| Name | `tfc_inv – statefile` |
| Source | **Sourced from a Project** |
| Project | `Terraform Collection Demo` |
| Inventory File | `inventories/tfc_statefile_single/tfc_inventory.yml` |
| Credential | `TFC – my-tfc-org` |
| Update Options | ✅ Overwrite ✅ Update on launch |

Hit **Sync** (the cycle-arrow). After it succeeds, **Hosts** lists every
resource Terraform is currently managing.

### 6c. Dynamic inventory from Terraform OUTPUTS

Same recipe, change inventory file to
`inventories/tfc_outputs_single/tfc_inventory.yml`.

## Step 7 — create Job Templates (one per playbook)

For each playbook under `playbooks/` and `examples/`, create a Job Template:

Controller → **Resources** → **Templates** → **Add** → **Job Template**.

| Field | Example value |
| ----- | ------------- |
| Name | `01 - Org Foundation` |
| Job Type | **Run** |
| Inventory | `Local (TFC ops)` (use the dynamic one ONLY for `06_configure_inventory_targets.yml`) |
| Project | `Terraform Collection Demo` |
| Execution Environment | `Default execution environment` (or your custom EE) |
| Playbook | `playbooks/01_org_foundation.yml` |
| Credentials | `TFC – my-tfc-org` |
| Variables | (extra_vars — see survey below) |
| Options | ✅ Privilege Escalation OFF, ✅ Enable Concurrent Jobs (off by default) |

### Suggested per-playbook surveys

| Playbook | Survey fields to prompt for |
| -------- | --------------------------- |
| `01_org_foundation.yml` | `tfc_organization`, `tfc_project`, `admin_email` |
| `02_workspace_onboarding.yml` | `new_workspace` (required), `environment_tag`, `region`, `slack_webhook_url` (password) |
| `03_plan_and_apply.yml` | `tfc_organization`, `tfc_workspace`, `auto_apply` (true/false), `print_diff` (true/false) |
| `04_policy_gated_apply.yml` | `run_id` (only if running stand-alone — Workflow nodes inherit it via `set_stats`) |
| `05_destroy_workspace.yml` | `target_workspace` (required), `force_delete` (true/false) |
| `07_promotion_pipeline.yml` | `target_stage`, `source_stage` |
| `08_rotate_secrets.yml` | nothing manual — the upstream secret-source job fills `aws_access_key_id` / `aws_secret_access_key` via `extra_vars` |
| `09_drift_audit.yml` | none — attach a Schedule instead |

> Sensitive fields (Slack webhooks, secret access keys) should be
> **Password** type in the survey, *not* Text. Even better: a second
> Credential.

## Step 8 — chain Job Templates into a Workflow

The plan/apply/destroy flows are best run as **Workflow Templates** so a
human approval node sits between plan and apply.

Controller → **Resources** → **Templates** → **Add** → **Workflow Template**.

Recommended workflow for plan/apply with approval:

```
┌────────────────────┐    success    ┌─────────────────┐    approved    ┌──────────────────────┐
│ 03 - Plan & Apply  │──────────────►│ Approval node   │───────────────►│ 04 - Policy-gated    │
│ (plan_only=true)   │               │ "Apply run X?"  │                │ apply                │
└────────────────────┘               └─────────────────┘                └──────────────────────┘
```

Recommended workflow for promotion:

```
   ┌──────────┐   success   ┌──────────┐  approval  ┌──────────┐  approval  ┌──────────┐
   │ dev plan │────────────►│ dev apply│───────────►│ stg promo│───────────►│ prd promo│
   └──────────┘             └──────────┘            └──────────┘            └──────────┘
                                                    (07 + 04)               (07 + 04)
```

When using `set_stats` in the plan job (`03_plan_and_apply.yml` already
does this), enable **"Variables from prior nodes"** in each downstream
node. The `tfc_run_id` var is then available as a top-level extra_var.

## Step 9 — schedule the recurring jobs

For `09_drift_audit.yml`:

1. Open the Job Template.
2. **Schedules** tab → **Add**.
3. Name: `Daily 06:00 UTC`. Repeat = daily.
4. Save.

For secret rotation (`08_rotate_secrets.yml`), do the same with a weekly
or monthly cadence.

## Step 10 — notifications (optional but recommended)

Controller → **Administration** → **Notifications** → **Add**.

Create a Slack notification template, then attach it to the Workflow
Template / Job Template "Notifications" tab — **Failure**, **Started**,
**Success** can each target a different channel.

You can ALSO drive notifications from the TFC side via
`playbooks/02_workspace_onboarding.yml` — that wires `slack-platform`
into the workspace itself so TFC sends events directly to Slack.

---

## Execution Environment — pytfe & custom EEs (deep dive)

### Why we install pytfe at runtime in the demo

Every module in `hashicorp.terraform` imports `pytfe` at module load time.
The stock AAP "Default execution environment" doesn't bundle pytfe — so
without intervention every play would fail on the very first task with
`ModuleNotFoundError: pytfe`.

This repo solves that by including `playbooks/bootstrap_pytfe.yml` at the
top of every workflow. It calls `ansible.builtin.pip` against the EE's
Python interpreter and installs pytfe site-wide for that job run. Repeats
are cheap (pip detects the package is already present).

### What you SHOULD do for production

Build a custom EE that already contains pytfe. Then set
`-e install_pytfe_at_runtime=false` (or set it permanently in a
Job Template's extra_vars) and the bootstrap step turns into a single
`meta: end_play`.

Minimal `execution-environment.yml` for `ansible-builder`:

```yaml
version: 3
images:
  base_image:
    name: registry.redhat.io/ansible-automation-platform-26/ee-supported-rhel9:latest

dependencies:
  galaxy: collections/requirements.yml      # this repo's file
  python: requirements.txt                  # ships pytfe
  system: []
```

Then:

```bash
ansible-builder build -t aap-terraform-ee:2.0.0 .
podman push aap-terraform-ee:2.0.0 <your-registry>/aap-terraform-ee:2.0.0
```

In AAP: **Administration** → **Execution Environments** → **Add**, point
at the pushed image, attach to your Job Templates.

### Where logs go

* **AAP UI** — every job's stdout is shown in the **Jobs** tab.
* **Controller pod logs** — `kubectl logs -n aap deploy/automation-controller`
  if you're on OCP / k8s.

---

## Smoke test order on a fresh AAP

1. **Sync** the Project. Verify the sync log shows `hashicorp.terraform`
   downloading from `console.redhat.com/api/automation-hub` (not from
   public Galaxy). If it fails, you skipped Step 3.
2. Launch the `examples/03_workspace.yml` Job Template — quickest end-to-end
   check that the credential + EE + pytfe bootstrap all work.
3. Launch `playbooks/01_org_foundation.yml` to lay down the org / project /
   var sets.
4. Launch `playbooks/02_workspace_onboarding.yml` to create a real workspace.
5. Launch the **plan + approval + apply** Workflow Template.
6. (Optional) Sync the `TFC state` Inventory and launch
   `playbooks/06_configure_inventory_targets.yml`.

## Troubleshooting

| Symptom | Likely cause | Fix |
| ------- | ------------ | --- |
| `ModuleNotFoundError: pytfe` on every task | bootstrap_pytfe was skipped / a custom EE doesn't include pytfe | set `install_pytfe_at_runtime=true` OR rebuild the EE with `requirements.txt` |
| `TFE_TOKEN env var not set` | Credential type's injector isn't pointing at the right field | re-check the Custom Credential Type YAML in Step 5 |
| Project sync: `Failed to download collection hashicorp.terraform` | Automation Hub credential missing or wrong URL/auth_url | revisit Step 3 — confirm token, both URLs, and that the credential is bound to the Project (Step 4) |
| Project sync: `Token validation failed` | Offline token expired or revoked | regenerate via console.redhat.com → "Connect to Hub" → "Load token", then update the Credential |
| Inventory Source shows 0 hosts but no error | provider/type isn't in the built-in list | add a `provider_mapping` entry in the inventory YAML |
| `Cannot connect to terraform.io` (TFE on-prem) | self-signed cert | add `tfe_ca_bundle` / `tfe_verify_tls: false` |
| Plan job runs forever | `poll_timeout` too low for a big plan | bump `run_poll_timeout_seconds` extra_var |
