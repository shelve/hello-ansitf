# Overriding `hashicorp.terraform` from a Git ref (runtime override)

The "normal" install path puts whatever version `collections/requirements.yml`
pins on the AAP Project's collections path at Project-sync time, pulled from
Red Hat Automation Hub. That's the right answer for shared, reproducible
runs.

But sometimes you want **one Job Template** to run against an unreleased
branch — e.g. validating the upcoming **2.1.0** while everyone else stays on
2.0.0. This repo supports that with a second play inside
[`playbooks/bootstrap_pytfe.yml`](../playbooks/bootstrap_pytfe.yml) that
mirrors how pytfe is installed: a runtime `ansible-galaxy collection install
git+...` driven by a variable.

## How it works

The bootstrap playbook has two plays:

| Play | Action | Toggle |
| ---- | ------ | ------ |
| 1 | `pip install pytfe` into the EE | `install_pytfe_at_runtime` (default `true`) |
| 2 | `ansible-galaxy collection install git+<url>,<ref> --force` into `./collections` | `collection_git_ref` (default `""` — play skips) |

Because it installs into the SAME path (`./collections`) that AAP populated
from Automation Hub, the `--force` makes the git build **shadow** the
Automation Hub install for the rest of this job. The Project's on-disk
collection isn't touched permanently — next Job Template launch reads
whatever AAP synced.

> **AAP Project sync is shared.** That's why we don't pin the git URL in
> `collections/requirements.yml` — doing so would flip the version for
> every Job Template using the Project. The runtime override is opt-in per
> job.

## Turning it on

### Locally

```bash
ansible-playbook playbooks/03_plan_and_apply.yml \
  -e collection_git_ref=release-2.1 \
  -e tfc_organization=my-tfc-org \
  -e tfc_workspace=aap-demo-app
```

### In AAP — one-off

Add `collection_git_ref: release-2.1` to a Job Template's **Variables**
field, launch it once, then remove the var (or add it as a survey field
flagged "Required = no" so each launch can opt in).

### In AAP — recommended for "preview" Job Templates

Clone the production Job Template and call it e.g.
`03 - Plan & Apply (preview 2.1)`. Hard-code the extra_var:

```yaml
collection_git_ref: release-2.1
```

Now you have two Job Templates — production stays on 2.0.0 (Automation Hub),
preview uses the git branch. Switching the preview to a different branch is
a one-field edit.

## Overrides you'll want

| Variable | Purpose | Default |
| -------- | ------- | ------- |
| `collection_git_ref` | Branch / tag / commit SHA to install. Empty = skip. | `""` |
| `collection_git_url` | Source repo URL. Use a fork or `git+ssh://` form here. | upstream HTTPS |

For SSH:

```yaml
collection_git_url: "git+ssh://git@github.com/hashicorp/terraform-ansible-collection.git"
collection_git_ref: "my-branch"
```

The EE needs SSH agent access OR an SSH key mounted via an AAP **Machine
Credential**. Easiest path is HTTPS unless you're cloning a private fork.

## Verifying which version actually ran

The bootstrap play's last task runs:

```
ansible-galaxy collection list hashicorp.terraform --collections-path ./collections
```

…and prints the result. Job stdout will show something like:

```
Collection                    Version
----------------------------- -------
hashicorp.terraform           2.1.0-dev
```

If you don't see this block at the top of the job log, the override didn't
fire — check that `collection_git_ref` was actually set (it's empty by
default).

## Limitations & gotchas

* **Galaxy doesn't pull dependencies via git+ install.** If the branch's
  `meta/runtime.yml` declares a new requirement, install it explicitly with
  another `ansible-galaxy collection install` task.
* **`--force` removes the previously installed copy in the same path.**
  Subsequent plays in the SAME job get the git build. Subsequent JOBS get
  whatever AAP project-sync placed back, unless they also set
  `collection_git_ref`.
* **Project sync runs `collections/requirements.yml`.** If you set
  `collection_git_ref` for an ENTIRE Project (e.g. by editing the file),
  AAP will keep re-installing from git on every sync — at that point you
  may as well move to a custom EE that bakes in the desired build.
* **Air-gapped environments**: ansible-galaxy needs outbound git access
  from the EE. If the EE has no network egress, mirror the branch into an
  internal Git server and point `collection_git_url` there.
