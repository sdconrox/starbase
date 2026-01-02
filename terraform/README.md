# Terraform Proxmox VM Configuration

This directory contains Terraform configuration to automatically create a Kubernetes master node VM in Proxmox.

## Prerequisites

1. **Terraform** installed (>= 1.0)
2. **Proxmox** cluster with API access
3. **Cloud-init template** in Proxmox (e.g., Ubuntu 22.04 cloud-init image)
4. **Proxmox API token** with appropriate permissions

## Setup

### 1. Create Proxmox API Token

In Proxmox web UI:
1. Go to Datacenter → Permissions → API Tokens
2. Create a new token for a user (or create a dedicated user)
3. Grant necessary permissions (VM creation, template access, etc.)
4. Copy the token ID and secret

### 2. Prepare Cloud-init Template

If you don't have a cloud-init template:
1. Download Ubuntu 22.04 cloud image
2. Upload to Proxmox storage
3. Create VM from the image
4. Convert to template

### 3. Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 4. Get SSH Public Key

```bash
# If you don't have an SSH key, generate one:
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# Copy your public key:
cat ~/.ssh/id_rsa.pub
# Add this to terraform.tfvars as vm_ssh_public_key
```

## Usage

### Initialize Terraform

```bash
terraform init
```

### Plan Deployment

```bash
terraform plan
```

### Create VM

```bash
terraform apply
```

### View Outputs

After creation, Terraform will output:
- VM ID
- IP address
- Ansible inventory entry
- SSH command

### Update Ansible Inventory

The Terraform output includes an Ansible inventory entry. You can:

1. **Manual**: Copy the `ansible_inventory_entry` output to your inventory file
2. **Automated**: Use the provided script (see below)

### Destroy VM

```bash
terraform destroy
```

## Integration with Ansible

After creating the VM, update the Ansible inventory:

```bash
# Get the inventory entry from Terraform output
terraform output -raw ansible_inventory_entry

# Or use the update-inventory script
../bin/update-inventory-from-terraform.sh
```

## Variables

See `variables.tf` for all available variables. Key variables:

- `proxmox_api_url`: Your Proxmox API endpoint
- `proxmox_api_token_id`: API token ID
- `proxmox_api_token_secret`: API token secret
- `vm_ip_address`: Static IP for the VM
- `vm_ssh_public_key`: Your SSH public key
- `vm_template_name`: Name of your cloud-init template

## Troubleshooting

### VM Creation Fails

- Verify API token has correct permissions
- Check template name matches exactly
- Ensure storage pool has enough space
- Verify network bridge exists

### Cloud-init Not Working

- Verify template is a cloud-init template
- Check network configuration
- Review Proxmox logs: `journalctl -u pve-cluster`

### SSH Access Issues

- Wait a few minutes after VM creation for cloud-init to complete
- Verify SSH key is correct
- Check VM console in Proxmox UI
- Verify network connectivity

