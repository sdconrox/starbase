variable "proxmox_api_url" {
  description = "Proxmox API URL (e.g., https://proxmox.example.com:8006/api2/json)"
  type        = string
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name where VM will be created"
  type        = string
  default     = "pve"
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification (not recommended for production)"
  type        = bool
  default     = false
}

variable "proxmox_debug" {
  description = "Enable debug logging"
  type        = bool
  default     = false
}

variable "vm_hostname" {
  description = "Hostname for the VM"
  type        = string
  default     = "k8s-master"
}

variable "vm_id" {
  description = "VM ID in Proxmox (auto-increment if not specified)"
  type        = number
  default     = null
}

variable "vm_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "vm_sockets" {
  description = "Number of CPU sockets"
  type        = number
  default     = 1
}

variable "vm_memory" {
  description = "Memory in MB"
  type        = number
  default     = 4096
}

variable "vm_disk_size" {
  description = "Disk size in GB (number, not string)"
  type        = number
  default     = 32
}

variable "vm_storage_pool" {
  description = "Proxmox storage pool for VM disk"
  type        = string
  default     = "local-lvm"
}

variable "vm_template_name" {
  description = "Name of the cloud-init template to clone from"
  type        = string
  default     = "ubuntu-22.04-cloudinit"
}

variable "vm_network_bridge" {
  description = "Network bridge (e.g., vmbr0)"
  type        = string
  default     = "vmbr0"
}

variable "vm_user" {
  description = "Default user for cloud-init"
  type        = string
  default     = "ubuntu"
}

