terraform {
    required_providers {
        libvirt = {
            source  = "dmacvicar/libvirt"
            version = "0.8.3"
        }
    }
}

provider "libvirt" {
    uri = "qemu:///system"
}

# Read the facts layer 1 published
data "terraform_remote_state" "bootstrap" {
    backend = "local"
    config = {
        path = "${path.module}/../00-bootstrap/terraform.tfstate"
    }
}

locals {
    bootstrap = data.terraform_remote_state.bootstrap.outputs

    # The only part you'll normally edit. memory is in MB.
    nodes = {
        k3s-server-1 = { ip = cidrhost(local.bootstrap.lab_cidr, 51), vcpu = 2, memory = 3072 }
        k3s-agent-1  = { ip = cidrhost(local.bootstrap.lab_cidr, 52), vcpu = 2, memory = 3072 }
        k3s-agent-2  = { ip = cidrhost(local.bootstrap.lab_cidr, 53), vcpu = 2, memory = 3072 }
    }
}

# One thin-clone disk per VM
resource "libvirt_volume" "disk" {
    for_each = local.nodes

    name             = "${each.key}.qcow2"
    pool             = "default"
    base_volume_name = local.bootstrap.base_volume_name
    base_volume_pool = "default"
    size             = 40 * 1024 * 1024 * 1024
}

# One first-boot config CD per VM
resource "libvirt_cloudinit_disk" "init" {
    for_each = local.nodes

    name = "${each.key}-init.iso"
    pool = "default"

    user_data = templatefile("${path.module}/cloud-init.yaml", {
        hostname = each.key
        ssh_key  = trimspace(file("~/.ssh/id_ed25519.pub"))
    })

    network_config = templatefile("${path.module}/network.yaml", {
        ip      = each.value.ip
        gateway = local.bootstrap.gateway_ip
    })
}

# The VMs
resource "libvirt_domain" "node" {
    for_each = local.nodes

    name      = each.key
    vcpu      = each.value.vcpu
    memory    = each.value.memory
    autostart = true
    cloudinit = libvirt_cloudinit_disk.init[each.key].id

    cpu { mode = "host-passthrough" }

    disk { volume_id = libvirt_volume.disk[each.key].id }

    network_interface {
        network_name = local.bootstrap.network_name
        addresses    = [each.value.ip]
    }

    console {
        type        = "pty"
        target_type = "serial"
        target_port = "0"
    }
}

output "nodes" {
    value = { for k, v in local.nodes : k => v.ip }
}
