# Cloud substrate for the flake's hosts (layer 0): hcloud server + static IP +
# firewall, and the Cloudflare DNS records that point at them. NixOS itself
# (layer 1) is installed with `just reinstall` and updated with `just deploy`.
#
# Run via `just infra <plan|apply|...>` - it wraps tofu with the credentials
# from infra/portal/secrets.env (sops). State is committed to git, encrypted
# below.
#
# This file is the plumbing (providers, encryption, variables, outputs);
# every actual resource lives in portal.tf.

terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.58"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }

  # OpenTofu-native state/plan encryption so terraform.tfstate can live in git.
  # Passphrase comes from TF_VAR_state_passphrase in infra/portal/secrets.env.
  encryption {
    key_provider "pbkdf2" "passphrase" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "default" {
      keys = key_provider.pbkdf2.passphrase
    }
    state {
      method   = method.aes_gcm.default
      enforced = true
    }
    plan {
      method   = method.aes_gcm.default
      enforced = true
    }
  }
}

provider "hcloud" {}     # HCLOUD_TOKEN
provider "cloudflare" {} # CLOUDFLARE_API_TOKEN

variable "state_passphrase" {
  description = "Passphrase for OpenTofu state encryption (TF_VAR_state_passphrase)."
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Zone ID of angel.pizza (TF_VAR_cloudflare_zone_id)."
  type        = string
}

output "portal_ipv4" {
  value       = hcloud_primary_ip.portal_ipv4.ip_address
  description = "Static IPv4 of portal - install with: just reinstall portal root@<this>"
}
