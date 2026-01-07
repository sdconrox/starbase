#!/bin/bash
# Generate SSH keypair for Ansible automation
# Usage: ./generate-ssh-key.sh

set -e

KEY_DIR="/Volumes/sdx-share-0/sdconrox/.sdx/.crypt/ssh"
KEY_NAME="starbase_ansible"
KEY_PATH="${KEY_DIR}/${KEY_NAME}"

echo "🔑 Generating SSH keypair for Ansible..."
echo ""

# Create directory if it doesn't exist
mkdir -p "$KEY_DIR"

# Check if key already exists
if [ -f "${KEY_PATH}" ]; then
    echo "⚠️  Key already exists: ${KEY_PATH}"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
    rm -f "${KEY_PATH}" "${KEY_PATH}.pub"
fi

# Generate Ed25519 key
echo "Generating Ed25519 keypair..."
ssh-keygen -t ed25519 -C "ansible@starbase" \
    -f "$KEY_PATH" \
    -a 100 \
    -N ""  # No passphrase (add one manually later if desired)

# Set permissions
chmod 700 "$KEY_DIR"
chmod 600 "${KEY_PATH}"
chmod 644 "${KEY_PATH}.pub"

echo ""
echo "✅ SSH keypair generated successfully!"
echo ""
echo "Private key: ${KEY_PATH}"
echo "Public key:  ${KEY_PATH}.pub"
echo ""
echo "Public key content:"
cat "${KEY_PATH}.pub"
echo ""
echo ""
echo "Next steps:"
echo "1. Add public key to Proxmox VM cloud-init configuration"
echo "2. Run: ansible-playbook playbooks/setup-ssh-keys.yml"
echo "3. Or manually copy key to Raspberry Pis:"
echo "   ssh-copy-id -i ${KEY_PATH}.pub pi@<raspberry-pi-ip>"
echo ""

