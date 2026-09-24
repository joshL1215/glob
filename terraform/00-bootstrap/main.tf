terraform {
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
    default = "10.77.0.0/24"
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

    dns = {
        enable = "yes"
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
