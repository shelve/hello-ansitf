# Quickstart — run a playbook locally before AAP

Use this to validate any change to a playbook on your laptop before pushing
to CodeCommit and re-syncing AAP.

## Prereqs

* Python 3.10+
* ansible-core ≥ 2.16
* A TFC or TFE API token
* **An offline token for Red Hat Automation Hub** — `hashicorp.terraform` is
  a Partner Collection and is NOT on the public Ansible Galaxy. Get the
  token from **console.redhat.com → Automation Hub → "Connect to Hub" →
  "Load token"**.

## Setup

```bash
cd /path/to/this/repo

# 1) virtualenv
python3 -m venv .venv
source .venv/bin/activate

# 2) Ansible + pytfe (same versions AAP would use)
pip install 'ansible-core>=2.16' 'pytfe>=0.1.5'

# 3) Tell ansible-galaxy how to reach Automation Hub
#    The repo's ansible.cfg already has the [galaxy_server.published] block —
#    you just need to supply the token. Pick ONE:
#
#    Option A (recommended for local dev): env var
export ANSIBLE_GALAXY_SERVER_PUBLISHED_TOKEN='…offline token…'
#
#    Option B: edit ansible.cfg in place and replace `<put your token here>`.
#    Do NOT commit that change.
#
#    Option C: move the [galaxy_server.published] block to ~/.ansible.cfg
#    (user-level) so it isn't shared via this repo.

# 4) Install the collection (reads ansible.cfg → Automation Hub via your token)
ansible-galaxy collection install -r collections/requirements.yml

# 5) TFC/TFE credentials for the playbooks themselves
export TFE_TOKEN='…'                          # required
export TFE_ADDRESS='https://app.terraform.io' # default
```

### Verifying the install came from Automation Hub

```bash
ansible-galaxy collection list hashicorp.terraform
# Look for:
#   hashicorp.terraform         2.0.0    /…/aap-demo-01/collections/ansible_collections
```

If `ansible-galaxy collection install` fails with a 401/403, the token is
missing or expired — repeat step 3.

## Run

```bash
# Smoke test the workspace lifecycle module:
ansible-playbook examples/03_workspace.yml \
  -e tfc_organization=my-tfc-org \
  -e tfc_workspace=aap-demo-app

# End-to-end onboarding:
ansible-playbook playbooks/02_workspace_onboarding.yml \
  -e tfc_organization=my-tfc-org \
  -e new_workspace=aap-demo-app \
  -e region=us-east-1 \
  -e environment_tag=nonprod

# Skip the pytfe install if you've already done it once:
ansible-playbook playbooks/02_workspace_onboarding.yml \
  -e install_pytfe_at_runtime=false ...
```

## Dynamic inventory sanity check

```bash
ansible-inventory \
  -i inventories/tfc_outputs_single/tfc_inventory.yml \
  --graph

ansible-inventory \
  -i inventories/tfc_statefile_single/tfc_inventory.yml \
  --list
```

## Trying a pre-release branch (e.g. 2.1.0)

```bash
ansible-playbook examples/03_workspace.yml \
  -e collection_git_ref=release-2.1 \
  -e tfc_organization=my-tfc-org \
  -e tfc_workspace=demo
```

The bootstrap playbook's second play runs `ansible-galaxy collection install
git+<url>,<ref> --force` into `./collections`, shadowing the Automation
Hub install for the rest of this job. Details:
[`04-overriding-collection-from-git.md`](04-overriding-collection-from-git.md).

## Common local-only gotchas

* `ansible.cfg` sets `collections_path = ./collections`. If you globally
  install collections (`~/.ansible/collections`), they'll be ignored
  inside this repo. That's intentional — it matches AAP's behaviour.
* The dynamic inventory plugin reads `TFE_TOKEN` from the environment. If
  you're scoping per-shell, export it BEFORE invoking `ansible-inventory`.
* When a playbook fails on `ModuleNotFoundError: pytfe`, it's because the
  bootstrap was skipped AND your local Python doesn't have it. Run:
  `python -m pip install 'pytfe>=0.1.5'`.
* `Failed to find collection hashicorp.terraform:2.0.0` from
  `ansible-galaxy install` means you forgot the Automation Hub token —
  see step 3 above.
