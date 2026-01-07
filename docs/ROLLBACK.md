# Rollback Guide

This guide explains how to rollback the Kubernetes deployment and restore your system to its pre-deployment state.

## Overview

The rollback process will:
1. Uninstall k3s from all nodes (master and workers)
2. Restore system configuration files from backups (where available)
3. Remove Kubernetes-specific system settings
4. Clean up k3s data directories

**⚠️ WARNING:** Rollback operations are destructive and may result in data loss. Always backup important data before proceeding.

## Quick Rollback

### Automated Rollback (Recommended)

Use the provided Ansible playbook for automated rollback:

```bash
ansible-playbook playbooks/rollback-kubernetes.yml
```

This playbook will:
- Uninstall k3s from master and worker nodes
- Restore configuration files from backups
- Clean up Kubernetes-related files and directories
- Prompt for reboot on ARM nodes if cgroups were restored

**Note:** The playbook includes a 10-second pause at the start. Press `Ctrl+C` to cancel if needed.

### Manual Rollback

If the automated playbook fails or you prefer manual control, follow the steps below.

## Manual Rollback Steps

### Step 1: Uninstall k3s

#### On Master Node

```bash
# SSH into master node
ssh sdconrox@<master-ip>

# Stop and uninstall k3s
sudo /usr/local/bin/k3s-killall.sh
sudo /usr/local/bin/k3s-uninstall.sh
```

#### On Worker Nodes

```bash
# SSH into each worker node
ssh sdconrox@<worker-ip>

# Uninstall k3s-agent
sudo /usr/local/bin/k3s-agent-uninstall.sh
```

**Alternative:** Use Ansible to uninstall from all nodes:

```bash
# Uninstall from master
ansible k8s-master -m shell -a "sudo /usr/local/bin/k3s-killall.sh && sudo /usr/local/bin/k3s-uninstall.sh" --become

# Uninstall from workers
ansible workers -m shell -a "sudo /usr/local/bin/k3s-agent-uninstall.sh" --become
```

### Step 2: Restore System Configuration

#### Restore Swap Configuration

If a backup exists:

```bash
# Check if backup exists
ls -la /etc/fstab.bak

# Restore from backup
sudo cp /etc/fstab.bak /etc/fstab
```

If no backup exists, manually restore:

```bash
# Edit /etc/fstab and uncomment swap lines
sudo nano /etc/fstab
# Remove the '#' from lines containing 'swap'
```

#### Restore Cgroups Configuration (ARM nodes only)

On Raspberry Pi nodes, restore `/boot/cmdline.txt`:

```bash
# Check if backup exists
ls -la /boot/cmdline.txt.bak

# Restore from backup
sudo cp /boot/cmdline.txt.bak /boot/cmdline.txt

# Reboot to apply changes
sudo reboot
```

**Note:** The backup is created automatically by Ansible when cgroups are configured.

#### Remove Kubernetes Sysctl Settings

```bash
# Edit sysctl.conf
sudo nano /etc/sysctl.conf

# Remove or comment out these lines:
# net.bridge.bridge-nf-call-iptables=1
# net.bridge.bridge-nf-call-ip6tables=1
# net.ipv4.ip_forward=1

# Apply changes
sudo sysctl -p
```

### Step 3: Clean Up Files and Directories

#### Remove k3s Data Directories

```bash
# Remove k3s data (run on all nodes)
sudo rm -rf /var/lib/rancher/k3s
sudo rm -rf /etc/rancher/k3s
sudo rm -rf /var/lib/rancher
```

#### Remove kubeconfig (Master node only)

```bash
# Remove .kube directory
rm -rf ~/.kube
```

#### Unload Kernel Modules (Optional)

```bash
# Unload modules (may fail if in use, which is fine)
sudo modprobe -r br_netfilter
sudo modprobe -r overlay
```

### Step 4: Remove Master VM (Optional)

If you want to completely remove the master node VM created by Terraform:

```bash
cd terraform
terraform destroy
```

**⚠️ WARNING:** This will permanently delete the VM and all its data.

## Partial Rollback

### Rollback Only Workers

To remove workers from the cluster without affecting the master:

```bash
# Uninstall k3s-agent from specific workers
ansible servitor-i,servitor-ii -m shell -a "sudo /usr/local/bin/k3s-agent-uninstall.sh" --become
```

### Rollback Only Master

To remove the master but keep workers (workers will be orphaned):

```bash
# SSH into master
ssh sdconrox@<master-ip>

# Uninstall k3s
sudo /usr/local/bin/k3s-killall.sh
sudo /usr/local/bin/k3s-uninstall.sh
```

**Note:** Workers will need to be manually cleaned up after master removal.

## Verification

After rollback, verify the system state:

### Check k3s is Removed

```bash
# Check if k3s binary exists
which k3s
# Should return nothing

# Check if k3s process is running
ps aux | grep k3s
# Should return nothing
```

### Check System Configuration

```bash
# Check swap status
swapon --show
# Should show swap if it was restored

# Check sysctl settings
sysctl net.bridge.bridge-nf-call-iptables
# Should return 0 or the original value

# Check cgroups (ARM nodes)
cat /boot/cmdline.txt
# Should not contain cgroup_enable if restored
```

### Check Network Ports

```bash
# Check if Kubernetes ports are closed
sudo netstat -tlnp | grep -E '6443|10250'
# Should return nothing
```

## Troubleshooting

### k3s Uninstall Script Not Found

If the uninstall script is missing, manually remove k3s:

```bash
# Stop k3s service
sudo systemctl stop k3s
sudo systemctl stop k3s-agent

# Remove systemd services
sudo systemctl disable k3s
sudo systemctl disable k3s-agent
sudo rm -f /etc/systemd/system/k3s.service
sudo rm -f /etc/systemd/system/k3s-agent.service

# Remove binaries
sudo rm -f /usr/local/bin/k3s
sudo rm -f /usr/local/bin/k3s-agent
sudo rm -f /usr/local/bin/k3s-killall.sh
sudo rm -f /usr/local/bin/k3s-uninstall.sh
sudo rm -f /usr/local/bin/k3s-agent-uninstall.sh

# Remove data directories
sudo rm -rf /var/lib/rancher/k3s
sudo rm -rf /etc/rancher/k3s
```

### Backup Files Not Found

If backup files don't exist, you'll need to manually restore:

1. **Swap:** Edit `/etc/fstab` and uncomment swap lines
2. **Cgroups:** Edit `/boot/cmdline.txt` and remove cgroup parameters
3. **Sysctl:** Edit `/etc/sysctl.conf` and remove Kubernetes settings

### Ports Still in Use

If ports 6443 or 10250 are still in use after uninstall:

```bash
# Find process using port
sudo lsof -i :6443
sudo lsof -i :10250

# Kill the process
sudo kill -9 <PID>
```

### Cannot Remove Data Directories

If data directories are locked:

```bash
# Check for mounted filesystems
mount | grep rancher

# Unmount if needed
sudo umount /var/lib/rancher/k3s

# Force remove
sudo rm -rf /var/lib/rancher/k3s
```

## Re-deployment After Rollback

After a successful rollback, you can re-deploy the cluster:

```bash
# Run the deployment playbook again
ansible-playbook playbooks/deploy-kubernetes.yml
```

The playbook is idempotent, so it's safe to run multiple times.

## Backup Recommendations

Before deployment, consider creating backups:

```bash
# Backup fstab
sudo cp /etc/fstab /etc/fstab.backup-$(date +%Y%m%d)

# Backup cmdline.txt (ARM nodes)
sudo cp /boot/cmdline.txt /boot/cmdline.txt.backup-$(date +%Y%m%d)

# Backup sysctl.conf
sudo cp /etc/sysctl.conf /etc/sysctl.conf.backup-$(date +%Y%m%d)
```

## Important Notes

1. **Data Loss:** Uninstalling k3s will delete all cluster data, including:
   - Pods and deployments
   - ConfigMaps and Secrets
   - Persistent volumes (unless using external storage)
   - Cluster configuration

2. **Network Changes:** Some network settings may persist after rollback. Verify firewall rules and network configuration.

3. **ARM Nodes:** If cgroups were restored on ARM nodes, a reboot is required for changes to take effect.

4. **Master VM:** The master VM created by Terraform is not automatically removed. Use `terraform destroy` to remove it.

5. **Idempotency:** The rollback playbook is not fully idempotent. Running it multiple times may cause errors, but it's generally safe.

## Getting Help

If you encounter issues during rollback:

1. Check the Ansible playbook output for specific error messages
2. Review system logs: `journalctl -xe`
3. Check k3s logs (if still present): `journalctl -u k3s -u k3s-agent`
4. Verify network connectivity between nodes
5. Ensure you have proper permissions (sudo access)

## Related Documentation

- [Main README](README.md) - Deployment instructions
- [Terraform README](terraform/README.md) - VM management
- [k3s Documentation](https://docs.k3s.io/) - Official k3s documentation

