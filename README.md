# Starbase - Kubernetes on Raspberry Pi

An Ansible-based automation project for deploying a Kubernetes cluster on 10 Raspberry Pi 4 devices using k3s (lightweight Kubernetes).

## Overview

Starbase automates the deployment of a Kubernetes cluster with a Proxmox VM as the master node and 10 Raspberry Pi 4 devices as workers. The project uses:

- **Proxmox**: Create a cloud-init template in Proxmox that will be used to clone the master node VM
- **Terraform**: Automatically creates the master node VM in Proxmox by cloning from the template
- **Ansible**: Configures and deploys Kubernetes (k3s) across all nodes
  - Configures system settings (disable swap, enable cgroups on ARM, configure networking)
  - Deploys k3s (lightweight Kubernetes distribution)
  - Sets up 1 VM master + 9 Raspberry Pi worker nodes
  - Configures kubectl access

## Project Structure

```
starbase/
├── playbooks/                    # Ansible playbooks
│   ├── deploy-kubernetes.yml     # Main playbook for cluster deployment
│   ├── setup-ansible-user.yml    # Create ansible user with permissions
│   ├── setup-ssh-keys.yml        # Deploy SSH keys to existing users
│   └── rollback-kubernetes.yml   # Rollback Kubernetes deployment
├── roles/                        # Ansible roles
│   ├── common/                   # System configuration and prerequisites
│   │   ├── tasks/
│   │   └── vars/
│   └── kubernetes/               # Kubernetes/k3s installation
│       ├── tasks/
│       ├── vars/
│       └── templates/
├── proxmox/                      # Proxmox setup documentation
│   ├── README.md                 # Guide for creating cloud-init template
│   └── generate-ssh-key.sh      # SSH key generation utility
├── terraform/                    # Terraform configuration
│   ├── main.tf                   # Proxmox VM resource
│   ├── variables.tf              # Terraform variables
│   ├── outputs.tf                # Terraform outputs
│   ├── terraform.tfvars.example  # Example configuration
│   └── templates/                # Cloud-init templates
├── bin/                          # Utility scripts
│   ├── install-credential-scanners.sh  # Install credential scanning tools
│   ├── scan-credentials.sh       # Scan for hardcoded secrets
│   └── update-inventory-from-terraform.sh  # Sync Terraform output to inventory
├── inventory                     # Ansible inventory (VM master + Raspberry Pi workers)
├── ansible.cfg                   # Ansible configuration (default user: ansible)
└── README.md                     # This file
```

## Prerequisites

### Control Machine (where you run Ansible)
- Ansible 2.9+ installed
- Python 3
- Terraform 1.0+ installed
- SSH access to all Raspberry Pi devices
- SSH keys configured for passwordless access (recommended)
- Access to Proxmox web UI or CLI

### Infrastructure
- Proxmox hypervisor with API access
- 10x Raspberry Pi 4 (4GB or 8GB recommended)
- Raspberry Pi OS (64-bit recommended) or Ubuntu 22.04+ for ARM
- Network connectivity between all devices
- Static IP addresses configured (or update inventory with DHCP addresses)

## Setup Order

**Important:** Follow these steps in order:

1. **Proxmox** (First): Create a cloud-init template in Proxmox
2. **Terraform** (Second): Use Terraform to create the master node VM from the template
3. **Ansible** (Third): Deploy Kubernetes to all nodes using Ansible

## Configuration

### Step 1: Create Proxmox Cloud-init Template

Before using Terraform, you must create a cloud-init template in Proxmox. This template will be used by Terraform to clone the master node VM.

**What this does:**
- Downloads a Ubuntu cloud image
- Creates a VM with cloud-init support
- Configures SSH keys and initial settings
- Converts the VM to a template for reuse

**Instructions:**
See `proxmox/README.md` for detailed step-by-step instructions on creating the cloud-init template.

**Key points:**
- Template name must match exactly in Terraform configuration
- Ensure cloud-init is properly configured with your SSH keys
- Template should use UEFI (OVMF) boot for cloud images

### Step 2: Create Master Node VM with Terraform

After the Proxmox template is ready, use Terraform to create the master node VM:

**What this does:**
- Connects to Proxmox API
- Clones the cloud-init template to create a new VM
- Configures VM resources (CPU, memory, disk)
- Sets up networking and cloud-init parameters
- Outputs the VM IP address for Ansible inventory

**Instructions:**

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Proxmox and VM details
# IMPORTANT: Set vm_template_name to match your Proxmox template exactly
terraform init
terraform plan
terraform apply
```

After creation, update the Ansible inventory automatically:

```bash
bash bin/update-inventory-from-terraform.sh
```

Or manually copy the Terraform output to the inventory file.

See `terraform/README.md` for detailed Terraform setup instructions.

### Step 3: Update Inventory for Raspberry Pi Workers

Edit `inventory` file with your Raspberry Pi IP addresses and credentials:

```ini
[raspberry_pi_cluster]
# Master node is populated by Terraform (k8s-master)

# Worker nodes (Raspberry Pi 4)
pi-worker-01 ansible_host=192.168.1.11 ansible_user=pi
pi-worker-02 ansible_host=192.168.1.12 ansible_user=pi
# ... update all IPs
```

### Step 4: Configure SSH Access and Create Ansible User

**Initial Setup:** Nodes start with the `sdconrox` user. The Ansible configuration (`ansible.cfg`) is set to use the `ansible` user by default, but this user doesn't exist on the nodes initially.

**Step 4a: Verify Initial SSH Access**

Ensure you can SSH into all devices using the `sdconrox` user:

```bash
# Test master node (VM)
ssh sdconrox@<vm-ip>  # IP from Terraform output

# Test worker nodes (Raspberry Pi)
ssh sdconrox@<worker-ip>  # Test a worker node
```

**Step 4b: Create Ansible User on All Nodes**

Run the `setup-ansible-user.yml` playbook **as the `sdconrox` user** to create the `ansible` user with proper permissions on all nodes:

```bash
# Run as sdconrox user (specify user explicitly)
ansible-playbook -u sdconrox playbooks/setup-ansible-user.yml
```

This playbook will:
- Create the `ansible` user on all nodes
- Add the user to the `sudo` group
- Configure passwordless sudo access
- Deploy the SSH public key from `starbase_ansible.pub` to the user's `authorized_keys`
- Set up proper permissions for SSH access

**Note:** After this step, all subsequent Ansible playbooks will automatically use the `ansible` user (as configured in `ansible.cfg`). You don't need to specify `-u ansible` for future runs.

**Step 4c: Verify Ansible User Setup**

Test that you can SSH as the `ansible` user:

```bash
# Test master node
ssh ansible@<vm-ip>

# Test worker node
ssh ansible@<worker-ip>
```

### Step 5: Customize Variables (Optional)

Edit `playbooks/deploy-kubernetes.yml` or role variables to customize:
- Kubernetes version
- Network CIDR ranges
- k3s version

Or edit Terraform variables in `terraform/terraform.tfvars`:
- VM resources (CPU, memory, disk)
- Network configuration
- Cloud-init settings

## Usage

### Deploy Kubernetes Cluster

After the `ansible` user has been created on all nodes (Step 4b), you can deploy the Kubernetes cluster:

```bash
ansible-playbook playbooks/deploy-kubernetes.yml
```

**Note:** The playbook will automatically use the `ansible` user (as configured in `ansible.cfg`). No need to specify `-u ansible`.

**Note:** If you're on an SMB/CIFS filesystem (network mount), run scripts with `bash` explicitly:
```bash
bash bin/scan-credentials.sh
bash bin/install-credential-scanners.sh
```

### Verify Deployment

After deployment, SSH into the master node as the `ansible` user and verify:

```bash
ssh ansible@<master-ip>
k3s kubectl get nodes
k3s kubectl get pods --all-namespaces
```

### Access Cluster Remotely

Copy the kubeconfig from the master node:

```bash
scp ansible@<master-ip>:~/.kube/config ~/.kube/starbase-config
export KUBECONFIG=~/.kube/starbase-config
kubectl get nodes
```

## Credential Scanning

The project includes tools to scan for hardcoded credentials and secrets:

**Install scanning tools:**
```bash
bash bin/install-credential-scanners.sh
```

**Run credential scan:**
```bash
bash bin/scan-credentials.sh
```

## Architecture

- **1 Master Node (Proxmox VM)**:
  - x86_64 architecture
  - Runs k3s server, manages cluster state
  - Created automatically via Terraform
  - Typically 2-4 CPU cores, 4-8GB RAM

- **9 Worker Nodes (Raspberry Pi 4)**:
  - ARM architecture (armv7l or aarch64)
  - Run k3s agents, execute workloads
  - Resource-constrained but sufficient for many workloads

- **Network**: All nodes communicate over local network
- **Storage**: Uses local storage (can be extended with external storage)
- **Mixed Architecture**: k3s supports mixed x86_64 master with ARM workers

## Customization

### Using Full Kubernetes Instead of k3s

Edit `playbooks/deploy-kubernetes.yml`:

```yaml
vars:
  use_k3s: false
```

Note: Full Kubernetes is resource-intensive on Raspberry Pi. k3s is recommended.

### Network Configuration

Modify network CIDRs in `playbooks/deploy-kubernetes.yml`:

```yaml
vars:
  cluster_cidr: "10.42.0.0/16"
  service_cidr: "10.43.0.0/16"
```

## Troubleshooting

### Nodes Not Joining

1. Check network connectivity between nodes
2. Verify firewall rules allow ports 6443, 10250
3. Check k3s logs: `journalctl -u k3s -f` (master) or `journalctl -u k3s-agent -f` (workers)

### Swap Issues

If swap is still enabled, manually disable:
```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

### cgroups Not Enabled

On Raspberry Pi OS, ensure `/boot/cmdline.txt` contains:
```
cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1
```

Then reboot the device.

## Notes

- **k3s** is used by default as it's optimized for ARM and resource-constrained devices
- **Mixed Architecture**: The master (x86_64 VM) and workers (ARM Raspberry Pi) work together seamlessly with k3s
- The cluster uses local storage by default
- All nodes should be on the same network segment
- Ensure adequate power supply for all Raspberry Pi devices (official power adapters recommended)
- The master VM is managed via Terraform - use `terraform destroy` to remove it
- For production use, consider adding external storage and backup solutions

## Setup Components

### Proxmox Setup

The Proxmox setup creates a reusable cloud-init template that Terraform will clone. Key files:

- `proxmox/README.md`: Detailed guide for creating the cloud-init template
- `proxmox/generate-ssh-key.sh`: Utility script for SSH key generation

**Purpose:** Create a base Ubuntu image with cloud-init configured, ready to be cloned into VMs.

### Terraform Integration

The master node VM is created and managed via Terraform. Key files:

- `terraform/main.tf`: VM resource definition
- `terraform/variables.tf`: Configurable variables
- `terraform/terraform.tfvars.example`: Example configuration (copy to `terraform.tfvars`)
- `terraform/README.md`: Detailed Terraform setup guide
- `bin/update-inventory-from-terraform.sh`: Script to sync Terraform output to Ansible inventory

**Purpose:** Automatically provision the master node VM in Proxmox by cloning from the template created in Step 1.

### Ansible Deployment

Ansible handles the Kubernetes cluster deployment. Key files:

- `playbooks/deploy-kubernetes.yml`: Main deployment playbook
- `roles/common/`: System configuration role
- `roles/kubernetes/`: Kubernetes/k3s installation role
- `inventory`: Host inventory (updated by Terraform script)

**Purpose:** Configure all nodes and deploy Kubernetes (k3s) across the cluster.
