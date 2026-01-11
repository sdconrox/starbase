# Starbase - Kubernetes on Raspberry Pi

An Ansible-based automation project for deploying a Kubernetes cluster on 10 Raspberry Pi 4 devices using k3s (lightweight Kubernetes).

## Overview

Starbase automates the deployment of a Kubernetes cluster with a Proxmox VM as the master node and 10 Raspberry Pi 4 devices as workers. The project uses:

- **Proxmox**: Create a cloud-init template in Proxmox that will be used to clone the master node VM
- **Terraform**: Automatically creates the master node VM in Proxmox by cloning from the template
- **Ansible**: Configures and deploys Kubernetes (k3s) across all nodes
  - Configures system settings (disable swap, enable cgroups on ARM, configure networking)
  - Deploys k3s (lightweight Kubernetes distribution)
  - Sets up 1 VM master + 10 Raspberry Pi worker nodes
  - Configures kubectl access
- **GitOps (ArgoCD)**: Manages all platform applications and workloads declaratively
  - Continuous deployment from Git repository
  - Automated synchronization and self-healing
  - Platform applications (monitoring, ingress, storage, etc.)
  - Application management via ArgoCD UI

## Project Structure

```
starbase/
├── playbooks/                    # Ansible playbooks
│   ├── deploy-kubernetes.yml     # Main playbook for cluster deployment
│   ├── setup-ansible-user.yml    # Create ansible user with permissions
│   ├── setup-ssh-keys.yml        # Deploy SSH keys to existing users
│   ├── fetch-kubeconfig.yml      # Fetch kubeconfig to ~/.kube/config
│   ├── upgrade-packages.yml       # Upgrade packages on all hosts
│   ├── audit-system.yml          # System audit and compliance check
│   ├── rollback-kubernetes.yml   # Rollback Kubernetes deployment
│   └── test-connection-summary.yml  # Connection test summary
├── roles/                        # Ansible roles
│   ├── common/                   # System configuration and prerequisites
│   │   ├── tasks/
│   │   └── vars/
│   └── kubernetes/               # Kubernetes/k3s installation
│       ├── tasks/
│       ├── vars/
│       └── templates/
├── gitops/                       # GitOps manifests (ArgoCD)
│   ├── apps/                     # Application definitions
│   │   └── kubernetes-dashboard/ # Kubernetes Dashboard manifests
│   ├── clusters/                 # Cluster-specific configurations
│   │   └── starbase/
│   │       ├── applications/    # ArgoCD Application definitions
│   │       │   ├── platform/     # Platform applications (monitoring, ingress, etc.)
│   │       │   └── apps/         # User applications
│   │       └── argocd/           # ArgoCD installation config
│   │           └── install/      # Bootstrap configuration
│   └── platform/                 # Platform component manifests
│       ├── metallb/              # MetalLB load balancer
│       ├── cert-manager/         # Certificate management
│       ├── ingress-nginx/        # Ingress controller
│       ├── cloudflared/          # Cloudflare tunnel
│       ├── velero/               # Backup solution
│       └── onepassword-secrets/  # 1Password Connect secrets
├── kubernetes-dashboard/         # Kubernetes Dashboard deployment (legacy)
│   ├── deploy-dashboard.yml      # Deploy Kubernetes Dashboard (idempotent)
│   ├── access-dashboard.sh       # Access script with port-forwarding
│   └── README.md                  # Dashboard deployment guide
├── docs/                         # Documentation
│   ├── kubernetes-dashboard/     # Dashboard documentation
│   ├── proxmox/                  # Proxmox setup guides
│   ├── terraform/                # Terraform documentation
│   └── ROLLBACK.md               # Rollback procedures
├── proxmox/                      # Proxmox setup documentation (legacy)
│   ├── README.md                 # Guide for creating cloud-init template
│   └── generate-ssh-key.sh      # SSH key generation utility
├── terraform/                    # Terraform configuration
│   ├── main.tf                   # Proxmox VM resource
│   ├── variables.tf              # Terraform variables
│   ├── outputs.tf                # Terraform outputs
│   ├── terraform.tfvars.example  # Example configuration
│   └── templates/                # Cloud-init templates
├── bin/                          # Utility scripts
│   ├── bootstrap-argocd.sh      # Bootstrap ArgoCD installation
│   ├── bootstrap-secrets.sh      # Bootstrap 1Password secrets
│   ├── check-platform-versions.py # Check platform app versions
│   ├── check-sync-waves.sh      # Check ArgoCD sync-wave annotations
│   ├── download-metallb-crds.sh # Download MetalLB CRDs
│   ├── access-k8s-dashboard.sh  # Access Kubernetes Dashboard
│   ├── install-credential-scanners.sh  # Install credential scanning tools
│   ├── scan-credentials.sh       # Scan for hardcoded secrets
│   ├── generate-ssh-key.sh       # SSH key generation
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
4. **GitOps/ArgoCD** (Fourth): Bootstrap ArgoCD and deploy platform applications

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
- Kubernetes version (default: 1.34)
- Network CIDR ranges
- k3s version (default: v1.34.3+k3s1 - latest stable)

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

After deployment, fetch the kubeconfig to your local machine:

```bash
ansible-playbook playbooks/fetch-kubeconfig.yml
```

This playbook will:
- Fetch the kubeconfig from the master node
- Save it to `~/.kube/config` (kubectl's default location)
- Update the server address from `127.0.0.1` to the master IP
- Display access instructions

After running this, you can use `kubectl` directly without setting `KUBECONFIG`:

```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

## Post-Deployment: GitOps Setup

After the Kubernetes cluster is deployed, you can set up GitOps with ArgoCD to manage all platform applications declaratively.

### Step 6: Bootstrap ArgoCD

ArgoCD provides continuous deployment from your Git repository. Bootstrap ArgoCD:

```bash
bash bin/bootstrap-argocd.sh
```

This script will:
- Create the `argocd` namespace
- Install ArgoCD using Helm
- Create a bootstrap Application that manages all other applications
- Configure ArgoCD to sync from your Git repository

**Access ArgoCD UI:**

```bash
kubectl port-forward service/argocd-server -n argocd 8080:443
```

Then open `https://localhost:8080` in your browser (accept the self-signed certificate).

**Get initial admin password:**

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Login with username `admin` and the password above.

### Step 7: Bootstrap Secrets (1Password Connect)

If using 1Password Connect for secret management:

```bash
bash bin/bootstrap-secrets.sh
```

This creates the necessary secrets for 1Password Connect to authenticate with your 1Password account.

**Note:** You'll need to:
1. Have 1Password Connect credentials file (`1password-credentials.json`)
2. Have a 1Password Connect API token
3. Update the script with your actual token before running

### Platform Applications

Once ArgoCD is bootstrapped, it will automatically deploy the following platform applications (in order via sync-waves):

1. **ArgoCD** (sync-wave: -100) - GitOps continuous deployment
2. **1Password Connect** (sync-wave: -14) - External Secrets Operator
3. **NFS Provisioner** (sync-wave: -12) - Storage provisioner
4. **MetalLB** (sync-wave: -11) - Load balancer for bare metal
5. **Ingress NGINX** (sync-wave: -10) - Ingress controller
6. **External DNS** (sync-wave: -9) - DNS record management
7. **Cert Manager** (sync-wave: -8) - TLS certificate management
8. **Cert Manager Issuers** (sync-wave: -7) - Certificate issuers (Let's Encrypt)
9. **Kube Prometheus Stack** (sync-wave: -6) - Monitoring (Prometheus + Grafana)
10. **Loki** (sync-wave: -5) - Log aggregation
11. **Promtail** (sync-wave: -4) - Log collection
12. **Cloudflared** (sync-wave: -3) - Cloudflare tunnel
13. **Velero** (sync-wave: -2) - Backup solution
14. **Velero Schedule** (sync-wave: -1) - Backup schedules

All applications are managed via ArgoCD and will automatically sync when changes are pushed to the Git repository.

### GitOps Workflow

The project follows a GitOps workflow where:

1. **All manifests are stored in Git** (`gitops/` directory)
2. **ArgoCD monitors the repository** and automatically syncs changes
3. **Changes are made via Git commits** - edit manifests and push to trigger deployment
4. **ArgoCD detects drift** and can auto-correct or alert on differences
5. **Sync waves control deployment order** - platform apps deploy before user apps

**Making changes:**
- Edit manifests in `gitops/` directory
- Commit and push to Git repository
- ArgoCD automatically detects and syncs changes (if auto-sync enabled)
- Or manually sync via ArgoCD UI or CLI

**Application structure:**
- Platform applications: `gitops/clusters/starbase/applications/platform/`
- User applications: `gitops/clusters/starbase/applications/apps/`
- Platform manifests: `gitops/platform/`
- App manifests: `gitops/apps/`

### Utility Scripts

**Check platform application versions:**

```bash
python3 bin/check-platform-versions.py
```

This checks all platform applications against their latest available versions and reports which ones are outdated.

**Check sync-wave deployment order:**

```bash
bash bin/check-sync-waves.sh
```

This lists all sync-wave annotations in the platform folders, sorted from least to greatest, so you can verify the deployment order.

**Download MetalLB CRDs:**

```bash
bash bin/download-metallb-crds.sh [version]
```

Downloads and formats MetalLB CRDs for a specific version (default: v0.15.3) for easy replacement in `metallb.yaml`.

## Additional Playbooks

### Fetch Kubeconfig

Fetch the kubeconfig from the cluster and save it to `~/.kube/config`:

```bash
ansible-playbook playbooks/fetch-kubeconfig.yml
```

This makes `kubectl` work automatically without setting `KUBECONFIG`.

### Upgrade Packages

Upgrade all packages on all hosts:

```bash
ansible-playbook playbooks/upgrade-packages.yml
```

### Audit System

Run a comprehensive system audit to check compliance and readiness:

```bash
ansible-playbook playbooks/audit-system.yml
```

This checks:
- Package upgrade status
- User login history
- User existence (ensures only `ansible` and `sdconrox` exist)
- System resource capacity
- Kubernetes-specific settings (swap, sysctl, cgroups, kernel modules)
- Network interfaces
- SSH key and sudo configuration

### Deploy Kubernetes Dashboard

Deploy the official Kubernetes Dashboard:

```bash
cd kubernetes-dashboard
ansible-playbook deploy-dashboard.yml
./access-dashboard.sh
```

See `kubernetes-dashboard/README.md` for detailed instructions.

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

## Current Versions

- **k3s**: v1.34.3+k3s1 (latest stable as of 2024)
- **Kubernetes**: 1.34.3
- **ArgoCD**: Managed via Helm chart (check `kube-prometheus-stack-application.yaml` for version)
- **Platform Applications**: Check versions with `bin/check-platform-versions.py`
  - MetalLB: v0.15.3
  - Cert Manager: v1.19.2
  - External DNS: 1.20.0
  - Kube Prometheus Stack: 80.13.3
  - Ingress NGINX: 4.14.1
  - 1Password Connect: 2.1.1
  - Velero: 11.3.2

## Notes

- **k3s** is used by default as it's optimized for ARM and resource-constrained devices
- **Mixed Architecture**: The master (x86_64 VM) and workers (ARM Raspberry Pi) work together seamlessly with k3s
- **Storage**: NFS provisioner is used for persistent volumes (deployed via ArgoCD)
- **GitOps**: All platform applications are managed via ArgoCD from the Git repository
- **Sync Waves**: Platform applications use sync-wave annotations to control deployment order
- All nodes should be on the same network segment
- Ensure adequate power supply for all Raspberry Pi devices (official power adapters recommended)
- The master VM is managed via Terraform - use `terraform destroy` to remove it
- Kubeconfig is **not** automatically fetched during deployment - run `playbooks/fetch-kubeconfig.yml` separately
- All playbooks are idempotent and can be run multiple times safely
- ArgoCD applications use automated sync with prune and self-heal enabled
- Platform applications deploy in negative sync-waves (< 0) to ensure they deploy before user applications

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
- `playbooks/fetch-kubeconfig.yml`: Fetch kubeconfig to local machine
- `playbooks/upgrade-packages.yml`: Upgrade packages on all hosts
- `playbooks/audit-system.yml`: System audit and compliance check
- `playbooks/rollback-kubernetes.yml`: Rollback Kubernetes deployment
- `roles/common/`: System configuration role
- `roles/kubernetes/`: Kubernetes/k3s installation role
- `inventory`: Host inventory (updated by Terraform script)

**Purpose:** Configure all nodes and deploy Kubernetes (k3s) across the cluster.

### Kubernetes Dashboard

The Kubernetes Dashboard is deployed via GitOps (ArgoCD) in `gitops/apps/kubernetes-dashboard/`. Access it using:

```bash
bash bin/access-k8s-dashboard.sh
```

**Legacy deployment:** A standalone Ansible deployment is also available in `kubernetes-dashboard/` for manual deployment if needed.

### GitOps (ArgoCD)

All platform applications and workloads are managed via GitOps using ArgoCD:

- **Repository**: All manifests are stored in the `gitops/` directory
- **Continuous Deployment**: ArgoCD automatically syncs changes from Git
- **Self-Healing**: ArgoCD monitors and corrects drift from Git state
- **Application Management**: All applications are defined as ArgoCD Applications

**Key directories:**
- `gitops/clusters/starbase/applications/`: ArgoCD Application definitions
- `gitops/platform/`: Platform component manifests (MetalLB, cert-manager, etc.)
- `gitops/apps/`: Application manifests (Kubernetes Dashboard, etc.)

**Bootstrap:** Use `bin/bootstrap-argocd.sh` to install and configure ArgoCD.
