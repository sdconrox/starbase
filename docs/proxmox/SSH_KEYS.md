# SSH Key Setup for Ansible

This guide covers generating a modern SSH keypair for Ansible automation and deploying it to both the Proxmox VM (master node) and Raspberry Pi workers.

## Step 1: Generate Modern SSH Keypair

### Generate Ed25519 Key (Recommended)

Ed25519 is the modern standard - faster, more secure, and smaller than RSA:

```bash
# Create the directory if it doesn't exist
mkdir -p /Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh

# Generate Ed25519 keypair
ssh-keygen -t ed25519 -C "ansible@starbase" \
  -f /Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible \
  -a 100  # 100 rounds of key derivation (more secure)

# Set appropriate permissions
chmod 700 /Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh
chmod 600 /Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible
chmod 644 /Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible.pub
```

**Files created:**
- `starbase_ansible` - Private key (keep secret!)
- `starbase_ansible.pub` - Public key (can be shared)

### Alternative: RSA 4096-bit (if Ed25519 not supported)

Some older systems may not support Ed25519. Use RSA 4096-bit instead:

```bash
ssh-keygen -t rsa -b 4096 -C "ansible@starbase" \
  -f /Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible \
  -o -a 100
```

## Step 2: Add Key to SSH Agent (Optional but Recommended)

```bash
# Start ssh-agent if not running
eval "$(ssh-agent -s)"

# Add the key to ssh-agent
ssh-add /Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible

# Verify it's loaded
ssh-add -l
```

## Step 3: Configure SSH for Ansible

Create or update SSH config to use this key automatically:

```bash
# Create/edit SSH config
cat >> ~/.ssh/config <<EOF

# Starbase Ansible Key
Host k8s-master
    HostName <vm-ip-address>
    User ubuntu
    IdentityFile /Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible
    IdentitiesOnly yes

Host pi-*
    User pi
    IdentityFile /Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible
    IdentitiesOnly yes
EOF

chmod 600 ~/.ssh/config
```

## Step 4: Add Public Key to Proxmox VM (Cloud-init)

### During Template Creation:

1. Get your public key:
   ```bash
   cat /Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible.pub
   ```

2. In Proxmox VM configuration:
   - VM → Hardware → CloudInit Drive
   - Paste the public key into **SSH Public Keys** field
   - Save

### For Terraform:

Update `terraform/terraform.tfvars`:

```hcl
vm_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... ansible@starbase"
```

Or read from file:

```hcl
vm_ssh_public_key = file("/Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible.pub")
```

## Step 5: Add Public Key to Raspberry Pis

### Option A: Manual (One-time Setup)

For each Raspberry Pi:

```bash
# Copy public key to Raspberry Pi
ssh-copy-id -i /Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible.pub pi@<raspberry-pi-ip>

# Or manually:
cat /Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible.pub | \
  ssh pi@<raspberry-pi-ip> "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

### Option B: Automated with Ansible (Recommended)

Create an Ansible playbook to deploy the key:

```yaml
# playbooks/setup-ssh-keys.yml
---
- name: Deploy SSH keys to all nodes
  hosts: raspberry_pi_cluster
  become: yes
  tasks:
    - name: Ensure .ssh directory exists
      file:
        path: "{{ ansible_env.HOME }}/.ssh"
        state: directory
        mode: '0700'
        owner: "{{ ansible_user }}"
        group: "{{ ansible_user }}"

    - name: Add Ansible public key
      authorized_key:
        user: "{{ ansible_user }}"
        state: present
        key: "{{ lookup('file', '/Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible.pub') }}"
```

Run it:

```bash
ansible-playbook playbooks/setup-ssh-keys.yml
```

## Step 6: Configure Ansible to Use the Key

Update `ansible.cfg`:

```ini
[defaults]
ansible_user = pi
interpreter_python = /usr/bin/env python3
inventory = ./inventory
playbook_dir = ./playbooks/
roles_path = ./roles
log_path = ./var/log/ansible.log
host_key_checking = False
retry_files_enabled = False
private_key_file = /Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible
```

Or set environment variable:

```bash
export ANSIBLE_PRIVATE_KEY_FILE=/Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible
```

## Step 7: Test SSH Access

### Test VM (Master Node):

```bash
ssh -i /Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible ubuntu@<vm-ip>
```

### Test Raspberry Pi:

```bash
ssh -i /Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible pi@<raspberry-pi-ip>
```

### Test with Ansible:

```bash
ansible all -i inventory -m ping
```

## Step 8: Update Inventory for Different Users

Your inventory should reflect different users for VM vs Raspberry Pis:

```ini
[raspberry_pi_cluster]
# Master node (VM)
k8s-master ansible_host=192.168.1.100 ansible_user=ubuntu ansible_ssh_private_key_file=/Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible

# Worker nodes (Raspberry Pi)
pi-worker-01 ansible_host=192.168.1.11 ansible_user=pi ansible_ssh_private_key_file=/Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible
pi-worker-02 ansible_host=192.168.1.12 ansible_user=pi ansible_ssh_private_key_file=/Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible
# ... etc
```

Or use groups:

```ini
[control_plane]
k8s-master ansible_host=192.168.1.100 ansible_user=ubuntu

[workers]
pi-worker-01 ansible_host=192.168.1.11 ansible_user=pi
pi-worker-02 ansible_host=192.168.1.12 ansible_user=pi
# ... etc

[control_plane:vars]
ansible_ssh_private_key_file=/Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible

[workers:vars]
ansible_ssh_private_key_file=/Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible
```

## Security Best Practices

1. **Never commit private keys to git**
   - Already in `.gitignore`: `*/.crypt/**`
   - Private key should never leave your secure storage

2. **Use strong passphrase** (optional but recommended):
   ```bash
   # If you want to add a passphrase later:
   ssh-keygen -p -f /Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible
   ```

3. **Restrict key usage** (optional):
   Add restrictions to `~/.ssh/authorized_keys` on target systems:
   ```
   command="/bin/bash",no-port-forwarding,no-X11-forwarding,no-agent-forwarding ssh-ed25519 AAAAC3...
   ```

4. **Rotate keys periodically**
   - Generate new keys every 6-12 months
   - Remove old keys from all systems

5. **Backup private key securely**
   - Store encrypted backup in secure location
   - Never share private key

## Troubleshooting

### Permission Denied

```bash
# Fix key permissions
chmod 600 /Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible
chmod 644 /Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible.pub
```

### Key Not Accepted

- Verify public key is in `~/.ssh/authorized_keys` on target
- Check permissions: `~/.ssh` should be 700, `authorized_keys` should be 600
- Verify key format (should be one line)

### Ansible Can't Find Key

- Check `ansible.cfg` has `private_key_file` set
- Or set `ANSIBLE_PRIVATE_KEY_FILE` environment variable
- Or specify in inventory file

## Quick Reference

**Key Location:**
- Private: `/Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible`
- Public: `/Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible.pub`

**Key Type:** Ed25519 (modern, recommended)

**Users:**
- VM Master: `ubuntu`
- Raspberry Pi Workers: `pi`

**Test Commands:**
```bash
# View public key
cat /Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible.pub

# Test VM
ssh -i /Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible ubuntu@<vm-ip>

# Test Raspberry Pi
ssh -i /Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh/starbase_ansible pi@<pi-ip>

# Test with Ansible
ansible all -i inventory -m ping
```

