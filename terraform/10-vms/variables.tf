variable "ssh_public_key_path" {
    description = "Read at apply time so key contents never enter the repo."
    default     = "~/.ssh/id_ed25519.pub"
}

variable "admin_user" {
    description = "Login account created on every node."
    default     = "josh"
}

variable "pool" {
    description = "libvirt storage pool holding guest disks."
    default     = "default"
}
