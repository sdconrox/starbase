terraform {
  required_version = ">= 1.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.1-rc1"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = var.proxmox_tls_insecure
  pm_debug            = var.proxmox_debug
}

# Create Proxmox VM for Kubernetes master
# APPROACH: Explicitly define EVERYTHING to match template exactly
# This prevents Terraform from seeing "drift" and trying to "fix" things
resource "proxmox_vm_qemu" "k8s_master" {
  name        = var.vm_hostname
  desc        = "Kubernetes master node for Raspberry Pi cluster"
  target_node = var.proxmox_node
  vmid        = var.vm_id

  # Clone from template
  clone = var.vm_template_name
  full_clone = true

  # VM Specifications
  cores   = var.vm_cores
  sockets = var.vm_sockets
  memory  = var.vm_memory
  cpu     = "host"

  # Hardware
  bios    = "ovmf"   # OVMF (UEFI) - required for cloud images
  machine = "q35"    # Machine type
  os_type = "l26"    # Linux 6.x - 2.6 Kernel
  scsihw  = "virtio-scsi-single"  # SCSI Controller: VirtIO SCSI single

  # Disks - explicitly define to prevent deletion
  # Template has scsi0 disk - we need to tell Terraform about it
  # Cloud-init drive (ide2) is managed separately via proxmox_cloud_init_disk resource
  disks {
    scsi {
      scsi0 {
        disk {
          storage = var.vm_storage_pool
          size    = var.vm_disk_size
          format  = "raw"
        }
      }
    }
  }

  # Cloud-init settings - reference the cloud-init disk created by the resource
  # cloudinit_cdrom_storage tells Proxmox where to find the cloud-init disk
  # The proxmox_cloud_init_disk resource creates the disk file at this location
  ciuser                  = var.vm_user
  ipconfig0               = "ip=dhcp,ip6=dhcp"
  cloudinit_cdrom_storage = var.vm_storage_pool

  # Network (match template exactly)
  network {
    bridge = var.vm_network_bridge
    model  = "virtio"
  }

  # Boot settings (match template exactly)
  boot   = "order=scsi0"  # Boot from SCSI disk first
  onboot = true            # Start at boot (override template's "No")

  # Options (match template exactly)
  tablet  = true                    # Use tablet for pointer: Yes
  hotplug = "disk,network,usb"      # Hotplug: Disk, Network, USB
  kvm     = true                    # KVM hardware virtualization: Yes
  agent   = 1                       # QEMU Guest Agent: Enabled
  numa    = false                   # NUMA: No

  # Tags (persist template tags)
  tags = "k8s;linux;critical;master"

  # Workaround for provider bug
  define_connection_info = false

  # Lifecycle: After initial creation, ignore disk changes since clone creates them
  lifecycle {
    ignore_changes = [
      disks,     # Disk paths/IDs are created by clone, ignore changes
      qemu_os,   # Deprecated attribute (we use os_type instead)
    ]
  }
}
