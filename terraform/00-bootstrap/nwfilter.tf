# The libvirt provider has no `libvirt_nwfilter` resource, so the filter is
# defined by shelling out to virsh. This is an escape hatch, not a pattern to
# imitate — but it keeps the rules in git and tied to the layer's lifecycle
# rather than living as undocumented host state.

locals {
    nwfilter_name = "lab-isolated"

    nwfilter_xml = templatefile("${path.module}/nwfilter/lab-isolated.xml.tftpl", {
        filter_name = local.nwfilter_name
        gateway_ip  = cidrhost(var.lab_cidr, 1)
        lab_network = cidrhost(var.lab_cidr, 0)
        lab_netmask = cidrnetmask(var.lab_cidr)
    })
}

resource "terraform_data" "lab_isolated" {
    # Editing the XML re-runs the define. libvirt's nwfilter-define is an
    # upsert, so redefining in place is safe and applies to running domains.
    triggers_replace = [local.nwfilter_xml]

    # Destroy provisioners may only reference `self`, never locals or vars,
    # so the name has to be carried in the resource's own state.
    input = { name = local.nwfilter_name }

    provisioner "local-exec" {
        interpreter = ["/bin/bash", "-c"]
        # Passing XML through the environment rather than interpolating it
        # into the command string avoids every shell-quoting problem.
        environment = { XML = local.nwfilter_xml }
        command     = "printf '%s' \"$XML\" | virsh -c qemu:///system nwfilter-define /dev/stdin"
    }

    provisioner "local-exec" {
        when        = destroy
        interpreter = ["/bin/bash", "-c"]
        # libvirt refuses to undefine a filter a running domain references,
        # so layer 10 must be destroyed first. Tolerated rather than fatal.
        command     = "virsh -c qemu:///system nwfilter-undefine ${self.input.name} || true"
    }
}
