# Starbase - Kubernetes on Raspberry Pi

An Ansible-based automation project for deploying a Kubernetes cluster on 10 Raspberry Pi 4 devices using k3s (lightweight Kubernetes).

## Overview

Starbase automates the deployment of a Kubernetes cluster across 10 Raspberry Pi 4 devices. The project uses Ansible playbooks to:
- Configure system settings (disable swap, enable cgroups, configure networking)
- Deploy k3s (lightweight Kubernetes distribution optimized for ARM)
- Set up a 1 master + 9 worker node cluster
- Configure kubectl access

## Project Structure

```
starbase/
├── playbooks/                    # Ansible playbooks
│   └── deploy-kubernetes.yml     # Main playbook for cluster deployment
├── roles/                        # Ansible roles
│   ├── common/                   # System configuration and prerequisites
│   │   ├── tasks/
│   │   └── vars/
│   └── kubernetes/               # Kubernetes/k3s installation
│       ├── tasks/
│       ├── vars/
│       └── templates/
├── bin/                          # Utility scripts
│   ├── install-credential-scanners.sh  # Install credential scanning tools
│   └── scan-credentials.sh       # Scan for hardcoded secrets
├── inventory                     # Ansible inventory (Raspberry Pi hosts)
├── ansible.cfg                   # Ansible configuration
└── README.md                     # This file
```

## Prerequisites

### Control Machine (where you run Ansible)
- Ansible 2.9+ installed
- Python 3
- SSH access to all Raspberry Pi devices
- SSH keys configured for passwordless access (recommended)

### Raspberry Pi Devices
- 10x Raspberry Pi 4 (4GB or 8GB recommended)
- Raspberry Pi OS (64-bit recommended) or Ubuntu 22.04+ for ARM
- Network connectivity between all devices
- Static IP addresses configured (or update inventory with DHCP addresses)

## Configuration

### 1. Update Inventory

Edit `inventory` file with your Raspberry Pi IP addresses and credentials:

```ini
[raspberry_pi_cluster]
pi-master ansible_host=192.168.1.10 ansible_user=pi
pi-worker-01 ansible_host=192.168.1.11 ansible_user=pi
# ... update all IPs
```

### 2. Configure SSH Access

Ensure you can SSH into all Raspberry Pi devices:

```bash
ssh pi@192.168.1.10  # Test master node
```

For passwordless access, copy your SSH key:

```bash
ssh-copy-id pi@192.168.1.10
```

### 3. Customize Variables (Optional)

Edit `playbooks/deploy-kubernetes.yml` or role variables to customize:
- Kubernetes version
- Network CIDR ranges
- k3s version

## Usage

### Deploy Kubernetes Cluster

```bash
ansible-playbook playbooks/deploy-kubernetes.yml
```

**Note:** If you're on an SMB/CIFS filesystem (network mount), run scripts with `bash` explicitly:
```bash
bash bin/scan-credentials.sh
bash bin/install-credential-scanners.sh
```

### Verify Deployment

After deployment, SSH into the master node and verify:

```bash
ssh pi@<master-ip>
k3s kubectl get nodes
k3s kubectl get pods --all-namespaces
```

### Access Cluster Remotely

Copy the kubeconfig from the master node:

```bash
scp pi@<master-ip>:~/.kube/config ~/.kube/starbase-config
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

- **1 Master Node**: Runs k3s server, manages cluster state
- **9 Worker Nodes**: Run k3s agents, execute workloads
- **Network**: All nodes communicate over local network
- **Storage**: Uses local storage (can be extended with external storage)

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

- k3s is used by default as it's optimized for ARM and resource-constrained devices
- The cluster uses local storage by default
- All nodes should be on the same network segment
- Ensure adequate power supply for all Raspberry Pi devices (official power adapters recommended)
- For production use, consider adding external storage and backup solutions
