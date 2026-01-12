#!/bin/bash
# Emergency script to kill Calibre containers when API server is down
# Run this directly on the master node: sudo bash emergency-kill-calibre.sh

set -e

echo "=== Emergency Calibre Container Removal ==="
echo "This script will stop and remove all Calibre containers directly via containerd"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo)"
    exit 1
fi

# Find Calibre containers
echo "Searching for Calibre containers..."
CALIBRE_CONTAINERS=$(crictl ps -a | grep -i calibre | awk '{print $1}' || true)

if [ -z "$CALIBRE_CONTAINERS" ]; then
    echo "No Calibre containers found."
    exit 0
fi

echo "Found Calibre containers:"
crictl ps -a | grep -i calibre

echo ""
read -p "Kill these containers? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Stop containers
echo "Stopping Calibre containers..."
for container in $CALIBRE_CONTAINERS; do
    echo "  Stopping container $container..."
    crictl stop $container 2>/dev/null || true
done

# Remove containers
echo "Removing Calibre containers..."
for container in $CALIBRE_CONTAINERS; do
    echo "  Removing container $container..."
    crictl rm $container 2>/dev/null || true
done

# Also kill any remaining Calibre processes
echo "Killing any remaining Calibre processes..."
pkill -9 -f calibre 2>/dev/null || true

echo ""
echo "=== Done ==="
echo "Check memory:"
free -h

echo ""
echo "Check if k3s can start:"
systemctl status k3s --no-pager -l | head -20
