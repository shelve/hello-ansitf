# files/null_tf_config/main.tf
#
# Terraform configuration used by playbooks/10_e2e_modules_only.yml.
#
# Why the `null` provider?
#   * Zero cloud cost / zero cloud credential setup — perfect for demos.
#   * `null_resource` accepts `triggers`, so changing a Terraform variable
#     from the Ansible play produces a real "1 to add, 1 to destroy" plan
#     diff. That makes the apply step actually do something visible in TFC.
#
# Why the `random` provider alongside?
#   * Gives us a real value that changes on each replacement, which we then
#     surface as a Terraform output. Outputs feed the
#     hashicorp.terraform.output module step in the playbook and could feed
#     the dynamic-inventory `outputs` source (see inventories/tfc_outputs/).

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# ---------- inputs ----------
variable "region" {
  description = "Logical region label — drives `triggers`, no real cloud effect."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Logical environment tag (nonprod / stage / prod)."
  type        = string
  default     = "nonprod"
}

variable "app_name" {
  description = "Pretend application name — used in derived outputs."
  type        = string
  default     = "aap-demo-app"
}

# ---------- resources ----------
# A null_resource whose `triggers` depend on the input vars. When the Ansible
# play changes `region` or `environment` between runs, this resource is
# *replaced* — producing a non-trivial plan diff that the apply step then
# enacts.
resource "null_resource" "deployment" {
  triggers = {
    region      = var.region
    environment = var.environment
    app_name    = var.app_name
  }
}

# A random pet whose name regenerates whenever `null_resource.deployment`
# gets replaced. Gives us a "different value each apply" we can show in
# outputs.
resource "random_pet" "release_name" {
  prefix = "${var.app_name}-${var.environment}"
  length = 2

  keepers = {
    deployment_id = null_resource.deployment.id
  }
}

# ---------- outputs ----------
# Outputs that the Ansible play surfaces via `hashicorp.terraform.output`.
output "deployment_id" {
  description = "Unique id of the null_resource; changes on replacement."
  value       = null_resource.deployment.id
}

output "release_name" {
  description = "Random release name regenerated whenever deployment is replaced."
  value       = random_pet.release_name.id
}

output "deployment_summary" {
  description = "Echo of the inputs — handy for asserting the play set what we expected."
  value = {
    region      = var.region
    environment = var.environment
    app_name    = var.app_name
  }
}

# `ansible_host`-shaped output so the SAME workspace can also drive the
# dynamic-inventory `outputs` source in inventories/tfc_outputs/. The
# inventory plugin treats map(object) as one host per map key.
output "ansible_host" {
  description = "Synthetic host list for the dynamic-inventory `outputs` demo."
  value = {
    "${random_pet.release_name.id}" = {
      public_ip = "203.0.113.10"
      env       = var.environment
      role      = "demo"
    }
  }
}
