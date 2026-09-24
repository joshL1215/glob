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

variable "lab_cidr" {
  default = "10.77.0.0/24"
}

resource "libvirt_network" "lab" {
  name      = "lab"
  mode      = "nat"
  addresses = [var.lab_cidr]
  autostart = true
  dhcp { enabled = false }
  dns  { enabled = true }
}

resource "libvirt_volume" "base" {
  name   = "ubuntu-24.04-base.qcow2"
  pool   = "default"
  source = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  format = "qcow2"
}

output "network_name" { value = libvirt_network.lab.name }
output "base_volume_name" { value = libvirt_volume.base.name }
output "gateway_ip" { value = cidrhost(var.lab_cidr, 1) }
output "lab_cidr" { value = var.lab_cidr }
