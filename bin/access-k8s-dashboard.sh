#!/bin/bash
#
# Kubernetes Dashboard Access Script
# This script sets up port-forwarding and displays the access token
#

set -e

DASHBOARD_NAMESPACE="kubernetes-dashboard"
SERVICE_ACCOUNT="dashboard-admin"
LOCAL_PORT="8443"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Kubernetes Dashboard Access${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}Error: kubectl is not installed or not in PATH${NC}"
    exit 1
fi

# Check if we can connect to cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${YELLOW}Error: Cannot connect to Kubernetes cluster${NC}"
    echo "Make sure your kubeconfig is set up correctly."
    exit 1
fi

# Check if dashboard namespace exists
if ! kubectl get namespace "$DASHBOARD_NAMESPACE" &> /dev/null; then
    echo -e "${YELLOW}Error: Dashboard namespace '$DASHBOARD_NAMESPACE' does not exist${NC}"
    echo "Please run the deployment playbook first:"
    echo "  ansible-playbook deploy-dashboard.yml"
    exit 1
fi

# Get the access token
echo -e "${BLUE}Retrieving access token...${NC}"
TOKEN=$(kubectl -n "$DASHBOARD_NAMESPACE" create token "$SERVICE_ACCOUNT" --duration=8760h 2>/dev/null || \
        kubectl -n "$DASHBOARD_NAMESPACE" get secret -o jsonpath='{.items[?(@.metadata.annotations.kubernetes\.io/service-account\.name=="'"$SERVICE_ACCOUNT"'")].data.token}' | base64 -d)

if [ -z "$TOKEN" ]; then
    echo -e "${YELLOW}Warning: Could not retrieve token. You may need to create the service account first.${NC}"
    echo "Run: ansible-playbook deploy-dashboard.yml"
    TOKEN="<TOKEN_NOT_AVAILABLE>"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Access Information:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}Dashboard URL:${NC} https://localhost:$LOCAL_PORT"
echo ""
echo -e "${GREEN}Access Token:${NC}"
echo "$TOKEN"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Setting up port-forwarding...${NC}"
echo "Press Ctrl+C to stop the port-forward and exit."
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Start port-forwarding
kubectl port-forward -n "$DASHBOARD_NAMESPACE" svc/kubernetes-dashboard "$LOCAL_PORT:443"

