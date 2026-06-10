# Custom Execution Environment with pytfe

This runbook describes the validated build flow for this repository:

- `hashicorp.terraform` collection from Private Automation Hub (`rh-certified`)
- `pytfe` from PyPI
- `ansible-builder` v3 with Docker runtime

The resulting image removes the need for runtime `pytfe` installation in normal
job runs.

## Prerequisites

| Tool | Version | Install |
| ---- | ------- | ------- |
| `ansible-builder` | >= 3.0 | `pip install 'ansible-builder>=3.0'` |
| `docker` | recent | Docker Desktop / Rancher Desktop |
| AWS CLI | v2 recommended | `brew install awscli` / OS package |
| Red Hat registry account | n/a | `registry.redhat.io` |
| Automation Hub token | n/a | AAP Automation Hub token |
| AWS account with ECR access | n/a | IAM permissions to push/pull ECR images |

## Step 1 - Authenticate registries

```bash
# Base image registry
docker login registry.redhat.io

# Optional: target registry where you will push the finished EE
docker login 669003565925.dkr.ecr.us-east-1.amazonaws.com
```

## Step 2 - Export Automation Hub token

```bash
export ANSIBLE_GALAXY_SERVER_RH_CERTIFIED_TOKEN='<your-automation-hub-token>'
```

## Step 3 - Build the EE

Run from repo root where `execution-environment.yml` exists:

```bash
ansible-builder build \
  --tag aap-terraform-ee:2.0.3 \
  --container-runtime docker \
  --verbosity 2 \
  --build-arg ANSIBLE_GALAXY_SERVER_RH_CERTIFIED_TOKEN="$ANSIBLE_GALAXY_SERVER_RH_CERTIFIED_TOKEN" \
  --no-cache
```

Notes:

- Do not append trailing `.` to this command in this environment.
- `context/` is generated build output and should not be committed.

## Step 4 - Verify image content

```bash
# Validate python3 and pytfe in the image
docker run --rm aap-terraform-ee:2.0.3 sh -lc 'python3 -V; python3 -c "import pytfe; print(pytfe.__version__)"'

# Validate collections
docker run --rm aap-terraform-ee:2.0.3 \
  ansible-galaxy collection list | egrep 'hashicorp\.terraform|ansible\.utils|community\.general'
```

Expected:

- `python3` resolves to Python 3.12
- `pytfe` import succeeds
- required collections are listed

## Step 5 - Push to your registry

For AWS ECR, authenticate first and tag the image with the ECR repository URI.

```bash
aws ecr get-login-password --region <aws-region> \
  | docker login --username AWS --password-stdin 669003565925.dkr.ecr.us-east-1.amazonaws.com
```

```bash
IMAGE=669003565925.dkr.ecr.us-east-1.amazonaws.com/hashicorp/aap-ee:2.0.3

docker tag aap-terraform-ee:2.0.3 "$IMAGE"
docker push "$IMAGE"
```

Create the ECR repository first if it does not already exist:

```bash
aws ecr create-repository \
  --repository-name hashicorp/aap-ee \
  --region us-east-1
```

## Step 6 - Register EE in AAP

Controller -> Administration -> Execution Environments -> Add

| Field | Value |
| ----- | ----- |
| Name | `aap-terraform-ee` |
| Image | `669003565925.dkr.ecr.us-east-1.amazonaws.com/hashicorp/aap-ee:2.0.3` |
| Pull | `Always` (recommended for tag updates) |
| Credential | AWS ECR registry credential, or a generic container registry credential that can authenticate to ECR |

## Step 7 - Update Job Templates

For each template that should use this EE:

| Field | Value |
| ----- | ----- |
| Execution Environment | `aap-terraform-ee` |
| Extra vars | `install_pytfe_at_runtime: false` |

## Troubleshooting

| Symptom | Likely cause | Fix |
| ------- | ------------ | --- |
| Build fails downloading `hashicorp.terraform` | Missing/invalid Hub token | Re-export `ANSIBLE_GALAXY_SERVER_RH_CERTIFIED_TOKEN` and rebuild |
| Build fails with pytfe Python-version errors | Builder using Python 3.9 | Keep `PYCMD=/usr/bin/python3.12` in builder/final steps of `execution-environment.yml` |
| `python3 -c "import pytfe"` fails in built image | Old image tag or stale local image | Rebuild with new tag and re-run verification commands |
