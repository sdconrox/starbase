output "vm_id" {
  description = "Proxmox VM ID"
  value       = proxmox_vm_qemu.k8s_master.vmid
}

output "vm_name" {
  description = "VM hostname"
  value       = proxmox_vm_qemu.k8s_master.name
}

output "vm_user" {
  description = "VM SSH user"
  value       = var.vm_user
}

output "ansible_inventory_entry_template" {
  description = "Ansible inventory entry template (replace <IP> with actual IP from DHCP)"
  value       = "${var.vm_hostname_master} ansible_host=<IP> ansible_user=${var.vm_user}"
}

output "ssh_command_template" {
  description = "SSH command template (replace <IP> with actual IP from DHCP)"
  value       = "ssh ${var.vm_user}@<IP>"
}

