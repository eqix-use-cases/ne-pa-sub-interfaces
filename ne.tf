// for hostname
resource "random_pet" "this" {
  length = 3
}

// account names
data "equinix_network_account" "da" {
  metro_code = var.dc1_code
  name       = var.account_name
}

data "equinix_network_account" "dc" {
  metro_code = var.dc2_code
  name       = var.account_name
}

// ssh keys
resource "tls_private_key" "key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "equinix_network_ssh_key" "this" {
  name       = random_pet.this.id
  public_key = tls_private_key.key.public_key_openssh
}

resource "local_sensitive_file" "private_key_pem" {
  content         = tls_private_key.key.private_key_pem
  filename        = "${random_pet.this.id}.pem"
  file_permission = "0600"
}

// acl for the NE
resource "equinix_network_acl_template" "this" {
  name        = "${random_pet.this.id}_allow_all_acl"
  description = "Allow all traffic"
  inbound_rule {
    subnet      = "0.0.0.0/0"
    protocol    = "IP"
    src_port    = "any"
    dst_port    = "any"
    description = "Allow all traffic"
  }
}

resource "equinix_network_device" "da" {
  name            = lower("${random_pet.this.id}-${data.equinix_network_account.da.metro_code}")
  acl_template_id = equinix_network_acl_template.this.uuid
  self_managed    = true
  byol            = true
  metro_code      = data.equinix_network_account.da.metro_code
  type_code       = var.route_os
  package_code    = var.package_code
  notifications   = var.notification_email
  hostname        = random_pet.this.id
  term_length     = var.term_length
  account_number  = data.equinix_network_account.da.number
  version         = var.route_os_version
  core_count      = var.core_count
  ssh_key {
    username = equinix_network_ssh_key.this.name
    key_name = equinix_network_ssh_key.this.name
  }
  timeouts {
    create = "60m"
    delete = "2h"
  }
}

resource "equinix_network_device" "dc" {
  name            = lower("${random_pet.this.id}-${data.equinix_network_account.dc.metro_code}")
  acl_template_id = equinix_network_acl_template.this.uuid
  self_managed    = true
  byol            = true
  metro_code      = data.equinix_network_account.dc.metro_code
  type_code       = var.route_os
  package_code    = var.package_code
  notifications   = var.notification_email
  hostname        = random_pet.this.id
  term_length     = var.term_length
  account_number  = data.equinix_network_account.dc.number
  version         = var.route_os_version
  core_count      = var.core_count
  ssh_key {
    username = equinix_network_ssh_key.this.name
    key_name = equinix_network_ssh_key.this.name
  }
  timeouts {
    create = "60m"
    delete = "2h"
  }
}

resource "equinix_network_device_link" "this" {
  name = random_pet.this.id
  device {
    id           = equinix_network_device.da.uuid
    asn          = equinix_network_device.da.asn > 0 ? equinix_network_device.da.asn : 65000
    interface_id = 10
  }
  device {
    id           = equinix_network_device.dc.uuid
    asn          = equinix_network_device.dc.asn > 0 ? equinix_network_device.dc.asn : 65001
    interface_id = 9
  }

  link {
    account_number  = equinix_network_device.da.account_number
    src_metro_code  = equinix_network_device.da.metro_code
    dst_metro_code  = equinix_network_device.dc.metro_code
    throughput      = "50"
    throughput_unit = "Mbps"
  }
}
