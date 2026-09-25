resource "libvirt_volume" "disk" {
    for_each = local.nodes_full

    name          = "${each.key}.qcow2"
    pool          = var.pool
    capacity      = each.value.disk_gib
    capacity_unit = "GiB"

    target = {
        format = { type = "qcow2" }
    }

    backing_store = {
        path   = local.bootstrap.base_volume_path
        format = { type = "qcow2" }
    }
}

resource "libvirt_cloudinit_disk" "init" {
    for_each = local.nodes_full

    name = "${each.key}-init.iso"

    meta_data = yamlencode({
        instance-id    = each.key
        local-hostname = each.key
    })

    user_data = templatefile("${path.module}/templates/user-data.yaml.tftpl", {
        hostname   = each.key
        fqdn       = "${each.key}.${local.bootstrap.lab_domain}"
        admin_user = var.admin_user
        ssh_key    = trimspace(file(pathexpand(var.ssh_public_key_path)))
    })

    network_config = templatefile("${path.module}/templates/network-config.yaml.tftpl", {
        ip         = each.value.ip
        prefix     = local.lab_prefix
        gateway    = local.bootstrap.gateway_ip
        lab_domain = local.bootstrap.lab_domain
    })
}

resource "libvirt_domain" "node" {
    for_each = local.nodes_full

    name        = each.key
    type        = "kvm"
    vcpu        = each.value.vcpu
    memory      = each.value.memory
    memory_unit = "MiB"
    autostart   = true
    running     = true

    cpu = { mode = "host-passthrough" }

    os = {
        type         = "hvm"
        boot_devices = [{ dev = "hd" }]
    }

    devices = {
        disks = [
            {
                device = "disk"
                driver = { name = "qemu", type = "qcow2" }
                target = { dev = "vda", bus = "virtio" }

                # By path, not pool/volume: virt-aa-helper only walks the
                # qcow2 backing chain for file-type disks, and the base image
                # must land in the generated AppArmor profile.
                source = {
                    file = { file = libvirt_volume.disk[each.key].path }
                }
            },
            {
                device    = "cdrom"
                driver    = { name = "qemu", type = "raw" }
                target    = { dev = "sda", bus = "sata" }
                read_only = true
                source = {
                    file = { file = libvirt_cloudinit_disk.init[each.key].path }
                }
            },
        ]

        interfaces = [
            {
                model  = { type = "virtio" }
                source = { network = { network = local.bootstrap.network_name } }

                filter_ref = {
                    filter     = local.bootstrap.nwfilter_name
                    parameters = [{ name = "IP", value = each.value.ip }]
                }
            },
        ]

        serials = [{
            target = { port = 0 }
            log = {
                file   = "/var/log/libvirt/qemu/${each.key}-serial.log"
                append = "on"
            }
        }]

        consoles = [{ target = { type = "serial", port = 0 } }]

        channels = [{
            source = { unix = {} }
            target = { virt_io = { name = "org.qemu.guest_agent.0" } }
        }]

        rngs = [{
            model   = "virtio"
            backend = { random = "/dev/urandom" }
        }]
    }
}
