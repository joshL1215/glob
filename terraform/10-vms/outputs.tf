output "nodes" {
    value = { for name, n in local.nodes_full : name => n.ip }
}

output "ssh" {
    value = {
        for name, n in local.nodes_full :
        name => "ssh ${var.admin_user}@${n.ip}"
    }
}
