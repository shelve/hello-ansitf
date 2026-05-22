# Minimal Terraform configuration used by the demo playbooks that upload a
# configuration version. Deliberately uses the `random` provider so it has no
# real cloud cost / credential requirement — the point of the demo is to show
# the *Ansible workflow* of uploading + planning + applying, not to teach
# Terraform itself.

terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "region" {
  description = "Logical region label (no cloud effect — just demo)."
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "Logical instance type label (no cloud effect — just demo)."
  type        = string
  default     = "t3.micro"
}

resource "random_pet" "demo_host" {
  prefix = "${var.region}-${var.instance_type}"
  length = 2
}

resource "random_id" "demo_uid" {
  byte_length = 4
}

# Outputs deliberately shaped to drive the dynamic inventory `outputs` source.
# `ansible_host` is a map(object) — one entry per "host" — and that becomes
# one Ansible host per map key, with the object fields spread flat as
# host_vars. See inventories/tfc_outputs/tfc_inventory.yml.
output "ansible_host" {
  description = "Map of pretend hosts for the dynamic inventory demo."
  value = {
    "${random_pet.demo_host.id}" = {
      public_ip = "203.0.113.${random_id.demo_uid.dec % 250}"
      env       = "demo"
      role      = "web"
    }
  }
}

output "elb_dns_name" {
  description = "Pretend ELB DNS used by the tf_output lookup example."
  value       = "${random_pet.demo_host.id}.elb.example.com"
}
