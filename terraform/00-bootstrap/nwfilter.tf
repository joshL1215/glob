# Terraform provider for libvirt has no nwfilter resource
# manually pushing nwfilter xml here

locals {
    nwfilter_name = "lab-isolated"

    # Derived from the name, so redefining updates in place rather than
    # colliding with the existing filter's generated UUID.
    nwfilter_uuid = uuidv5("dns", "glob.${local.nwfilter_name}")

    nwfilter_xml = templatefile("${path.module}/nwfilter/lab-isolated.xml.tftpl", {
        filter_name = local.nwfilter_name
        filter_uuid = local.nwfilter_uuid
        gateway_ip  = cidrhost(var.lab_cidr, 1)
        lab_network = cidrhost(var.lab_cidr, 0)
        lab_netmask = cidrnetmask(var.lab_cidr)
    })
}

resource "terraform_data" "lab_isolated" {
    triggers_replace = [local.nwfilter_xml]

    input = { name = local.nwfilter_name }

    provisioner "local-exec" {
        interpreter = ["/bin/bash", "-c"]
        environment = { XML = local.nwfilter_xml }
        command     = "printf '%s' \"$XML\" | virsh -c qemu:///system nwfilter-define /dev/stdin"
    }

    provisioner "local-exec" {
        when        = destroy
        interpreter = ["/bin/bash", "-c"]
        command     = "virsh -c qemu:///system nwfilter-undefine ${self.input.name} || true"
    }
}
