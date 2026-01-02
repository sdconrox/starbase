#!/bin/bash
# Update Ansible inventory with Terraform output
# This script reads Terraform outputs and updates the inventory file

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
INVENTORY_FILE="$PROJECT_ROOT/inventory"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔧 Updating Ansible inventory from Terraform output..."

if [ ! -d "$TERRAFORM_DIR" ]; then
    echo -e "${YELLOW}⚠️  Terraform directory not found: $TERRAFORM_DIR${NC}"
    exit 1
fi

cd "$TERRAFORM_DIR"

# Check if Terraform has been initialized
if [ ! -d ".terraform" ]; then
    echo -e "${YELLOW}⚠️  Terraform not initialized. Run 'terraform init' first.${NC}"
    exit 1
fi

# Get Terraform outputs
VM_NAME=$(terraform output -raw vm_name 2>/dev/null || echo "")
VM_USER=$(terraform output -raw vm_user 2>/dev/null || echo "")

if [ -z "$VM_NAME" ]; then
    echo -e "${YELLOW}⚠️  No Terraform outputs found. Has the VM been created?${NC}"
    echo "   Run: terraform apply"
    exit 1
fi

echo -e "${GREEN}✓ Found VM: $VM_NAME${NC}"
echo -e "${YELLOW}⚠️  VM uses DHCP. You need to provide the IP address.${NC}"
echo ""
read -p "Enter VM IP address (or press Enter to skip): " VM_IP

if [ -z "$VM_IP" ]; then
    echo -e "${YELLOW}⚠️  Skipping inventory update. Update manually with IP from DHCP server.${NC}"
    echo ""
    echo "Template entry:"
    echo "  ${VM_NAME} ansible_host=<IP> ansible_user=${VM_USER}"
    exit 0
fi

INVENTORY_ENTRY="${VM_NAME} ansible_host=${VM_IP} ansible_user=${VM_USER}"

# Backup inventory
cp "$INVENTORY_FILE" "$INVENTORY_FILE.backup"

# Update inventory file
# Remove old master entry if it exists
sed -i.bak '/^k8s-master\|^pi-master/ d' "$INVENTORY_FILE"

# Add new master entry at the top of control_plane section
if grep -q "^\[control_plane\]" "$INVENTORY_FILE"; then
    # Insert after [control_plane] line
    sed -i.bak "/^\[control_plane\]/a\\
$INVENTORY_ENTRY
" "$INVENTORY_FILE"
else
    # Add control_plane section
    echo "" >> "$INVENTORY_FILE"
    echo "[control_plane]" >> "$INVENTORY_FILE"
    echo "$INVENTORY_ENTRY" >> "$INVENTORY_FILE"
fi

# Update master_node variable in playbook if needed
PLAYBOOK_FILE="$PROJECT_ROOT/playbooks/deploy-kubernetes.yml"
if [ -f "$PLAYBOOK_FILE" ]; then
    sed -i.bak "s/master_node:.*/master_node: $VM_NAME/" "$PLAYBOOK_FILE"
fi

echo -e "${GREEN}✅ Inventory updated!${NC}"
echo ""
echo "Updated entry:"
echo "  $INVENTORY_ENTRY"
echo ""
echo "Backup saved to: $INVENTORY_FILE.backup"
echo ""
echo "Test connection:"
echo "  ssh $VM_USER@$VM_IP"

