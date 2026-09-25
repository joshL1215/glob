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

data "terraform_remote_state" "bootstrap" {
    backend = "local"
    config = {
        path = "${path.module}/../00-bootstrap/terraform.tfstate"
    }
}

locals {
    bootstrap = data.terraform_remote_state.bootstrap.outputs

    nodes = {
        "lab-cp-1" = { octet = 11, vcpu = 2, memory = 2048, disk_gib = 30 }
        "lab-w1"   = { octet = 21, vcpu = 2, memory = 3072, disk_gib = 40 }
        "lab-w2"   = { octet = 22, vcpu = 2, memory = 3072, disk_gib = 40 }
    }

    nodes_full = {
        for name, n in local.nodes : name => merge(n, {
            ip = cidrhost(local.bootstrap.lab_cidr, n.octet)
        })
    }

    lab_prefix = split("/", local.bootstrap.lab_cidr)[1]

    # No DHCP on the lab network, so dnsmasq never learns guest names.
    # Every node carries every peer instead.
    etc_hosts = [
        for name, n in local.nodes_full :
        "${n.ip} ${name}.${local.bootstrap.lab_domain} ${name}"
    ]
}
