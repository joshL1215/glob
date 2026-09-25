terraform {
    required_version = ">= 1.4" 

    required_providers {
        libvirt = {
            source  = "dmacvicar/libvirt"
            version = "~> 0.9.9"
        }
    }
}

provider "libvirt" {
    uri = "qemu:///system"
}

variable "lab_cidr" {
    description = "Address space for the lab virtual network, may need change if overarching network overlaps with this"
    default     = "10.77.0.0/24"
}

variable "lab_domain" {
    description = "Internal DNS suffix."
    default     = "lab.internal"
}

variable "dns_forwarders" {
    description = "Public Cloudflare and Quad9 DNS."
    type        = list(string)
    default     = ["1.1.1.1", "9.9.9.9"]
}

resource "libvirt_network" "lab" {
    name      = "lab"
    autostart = true 

    forward = {
        mode = "nat"
    }

    ips = [
        {
            address = cidrhost(var.lab_cidr, 1)
            netmask = cidrnetmask(var.lab_cidr)
        }
    ]

    # Use public DNS resolvers
    dns = {
        enable     = "yes"
        forwarders = [for addr in var.dns_forwarders : { addr = addr }]
    }

    domain = {
        name       = var.lab_domain
        local_only = "yes"
    }
}

resource "libvirt_volume" "base" {
    name = "ubuntu-24.04-base.qcow2"
    pool = "default"

    target = {
        format = {
            type = "qcow2"
        }
    }

    create = {
        content = {
            url = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
        }
    }
}

output "network_name"     { value = libvirt_network.lab.name }
output "base_volume_path" { value = libvirt_volume.base.path }
output "lab_cidr"         { value = var.lab_cidr }
output "gateway_ip"       { value = cidrhost(var.lab_cidr, 1) }
output "lab_domain"       { value = var.lab_domain }

output "nwfilter_name" {
    description = "Attach to every guest NIC via devices.interfaces[].filter_ref."
    value       = local.nwfilter_name
    depends_on  = [terraform_data.lab_isolated]
}
