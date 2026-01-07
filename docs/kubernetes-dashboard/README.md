# Kubernetes Dashboard Deployment

This directory contains Ansible playbooks and scripts to deploy and access the Kubernetes Dashboard on your k3s cluster.

## Prerequisites

- `kubectl` installed and configured (kubeconfig set up)
- `ansible` installed (for the deployment playbook)
- Access to your Kubernetes cluster

## Quick Start

### Deploy the Dashboard

```bash
ansible-playbook deploy-dashboard.yml
```

This playbook is **idempotent** - you can run it multiple times safely. It will:
- Deploy the Kubernetes Dashboard (v2.7.0)
- Create a service account with cluster-admin permissions
- Display the access token and connection instructions

### Access the Dashboard

**Option 1: Use the access script (recommended)**
```bash
chmod +x access-dashboard.sh
./access-dashboard.sh
```

This script will:
- Retrieve the access token
- Set up port-forwarding to `https://localhost:8443`
- Display all access information

**Option 2: Manual port-forward**
```bash
# Get the token
kubectl -n kubernetes-dashboard create token dashboard-admin --duration=8760h

# Set up port-forward in another terminal
kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard 8443:443
```

Then open: https://localhost:8443

**Option 3: LoadBalancer (if configured)**
```bash
# Get the external IP
kubectl get svc kubernetes-dashboard -n kubernetes-dashboard

# Access via the external IP
# https://<EXTERNAL-IP>
```

## Authentication

When you access the dashboard, select **"Token"** as the authentication method and paste the token displayed by the deployment playbook or access script.

The token is valid for **1 year (8760 hours)**.

## Files

- `deploy-dashboard.yml` - Ansible playbook to deploy the dashboard (idempotent)
- `access-dashboard.sh` - Shell script to access the dashboard with port-forwarding
- `README.md` - This file

## Updating the Dashboard

To update to a newer version, edit the `dashboard_version` variable in `deploy-dashboard.yml` and run the playbook again. It will update the deployment idempotently.

## Troubleshooting

### Dashboard not accessible
- Check if the dashboard pods are running: `kubectl get pods -n kubernetes-dashboard`
- Check dashboard logs: `kubectl logs -n kubernetes-dashboard deployment/kubernetes-dashboard`
- Verify port-forward is working: `kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard 8443:443`

### Token not working
- Generate a new token: `kubectl -n kubernetes-dashboard create token dashboard-admin --duration=8760h`
- Verify service account exists: `kubectl get sa dashboard-admin -n kubernetes-dashboard`
- Check cluster role binding: `kubectl get clusterrolebinding dashboard-admin`

### Port already in use
- Change the port in `access-dashboard.sh` (edit `LOCAL_PORT` variable)
- Or kill the existing port-forward: `pkill -f "port-forward.*kubernetes-dashboard"`

## Security Notes

- The dashboard has cluster-admin permissions - use with caution
- Tokens are long-lived (1 year) - rotate them periodically if needed
- Consider restricting access via network policies in production
- Never commit tokens or kubeconfig files to version control

## Uninstalling

To remove the dashboard:

```bash
kubectl delete namespace kubernetes-dashboard
kubectl delete clusterrolebinding dashboard-admin
```

