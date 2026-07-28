# portal - Pangolin tunnel server
#
# The primary IPv4 is a separate resource with auto_delete=false and delete
# protection: destroying/replacing the server keeps the IP, so DNS never
# changes. Respin with: just infra apply -replace=hcloud_server.portal

resource "hcloud_primary_ip" "portal_ipv4" {
  name              = "portal-ipv4"
  type              = "ipv4"
  location          = "hil"
  auto_delete       = false
  delete_protection = true
}

# "master" was uploaded to hcloud before tofu existed; reference, don't own.
data "hcloud_ssh_key" "master" {
  name = "master"
}

# Outer belt only; the real firewall is NixOS's. This mainly covers the window
# between "Ubuntu image boots" and "our config is installed".
resource "hcloud_firewall" "portal" {
  name = "portal"

  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["0.0.0.0/0"]
  }
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = ["0.0.0.0/0"]
    description = "ssh"
  }
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0"]
    description = "http (acme + redirect)"
  }
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0"]
    description = "https (traefik)"
  }
  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "51820"
    source_ips  = ["0.0.0.0/0"]
    description = "wireguard (gerbil <- newt)"
  }
}

resource "hcloud_server" "portal" {
  name         = "portal"
  image        = "ubuntu-24.04" # replaced by nixos-anywhere; only the initial boot target
  server_type  = "cpx11"
  location     = "hil"
  ssh_keys     = [data.hcloud_ssh_key.master.id]
  firewall_ids = [hcloud_firewall.portal.id]

  public_net {
    ipv4_enabled = true
    ipv4         = hcloud_primary_ip.portal_ipv4.id
    ipv6_enabled = false
  }

  # Hetzner only injects these keys when creating the initial boot image.
  lifecycle {
    ignore_changes = [ssh_keys]
  }
}

resource "hcloud_rdns" "portal_ipv4" {
  primary_ip_id = hcloud_primary_ip.portal_ipv4.id
  ip_address    = hcloud_primary_ip.portal_ipv4.ip_address
  dns_ptr       = "pangolin.angel.pizza"
}

# ── DNS ─────────────────────────────────────────────────────────────────────
# angel.pizza - the whole zone serves the Pangolin setup. All records grey
# cloud (proxied=false): gerbil's WireGuard can't traverse Cloudflare's proxy
# and Traefik terminates TLS with its own Let's Encrypt wildcard cert.

locals {
  managed_by = "managed by opentofu (nix repo, infra/)"
}

resource "cloudflare_dns_record" "pangolin" {
  zone_id = var.cloudflare_zone_id
  name    = "pangolin.angel.pizza"
  type    = "A"
  content = hcloud_primary_ip.portal_ipv4.ip_address
  ttl     = 1 # auto
  proxied = false
  comment = local.managed_by
}

# Every service resource (llama.angel.pizza, ...) resolves through this.
resource "cloudflare_dns_record" "wildcard" {
  zone_id = var.cloudflare_zone_id
  name    = "*.angel.pizza"
  type    = "CNAME"
  content = "pangolin.angel.pizza"
  ttl     = 1
  proxied = false
  comment = local.managed_by
}

# Bare domain -> same box (main page served as a Pangolin resource).
resource "cloudflare_dns_record" "apex" {
  zone_id = var.cloudflare_zone_id
  name    = "angel.pizza"
  type    = "A"
  content = hcloud_primary_ip.portal_ipv4.ip_address
  ttl     = 1
  proxied = false
  comment = local.managed_by
}
