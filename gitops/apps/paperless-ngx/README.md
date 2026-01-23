# Paperless-ngx Deployment

This directory contains the Kubernetes manifests for deploying Paperless-ngx in a highly available configuration.

## Overview

Paperless-ngx is a document management system that transforms physical documents into a searchable online archive. This deployment includes:

- **Paperless-ngx Web Server**: 1 replica (can be scaled later if needed)
- **PostgreSQL Database**: Separate database deployment for data persistence
- **Redis**: Required for task queue and scheduled tasks
- **Storage**: 1.4TB total storage distributed across:
  - Media: 1000Gi (documents and thumbnails)
  - Data: 100Gi (search index, database backups, classification model)
  - Consume: 100Gi (incoming documents)
  - Export: 100Gi (exported documents)
  - PostgreSQL: 100Gi
  - Redis: 100Gi

## High Availability Considerations

**Current Configuration**: This deployment uses a single replica for simplicity and to avoid duplicate document processing. Paperless-ngx does not natively support horizontal scaling, so a single replica is the recommended approach.

**Scaling**: If you need to scale later for redundancy, you can:
1. Increase replicas to 2+ and disable the consumer on all but one replica (see [Disabling Consumer on Replicas](#disabling-consumer-on-replicas) below)
2. Or create separate deployments: one for web (multiple replicas, consumer disabled) and one for worker (single replica, consumer enabled)

**Reliability**: The single replica is configured with:
- PodDisruptionBudget to prevent accidental termination
- Resource limits to prevent OOM kills
- Health checks (liveness and readiness probes)
- Persistent storage for data durability

## Required 1Password Secrets

Before deploying, ensure the following secrets exist in your 1Password vault:

### `vaults/starbase/items/paperless-ngx`
All paperless-ngx secrets are consolidated into a single 1Password item:

**Database Configuration:**
- `db`: PostgreSQL database name (e.g., `paperless`)
- `db-user`: PostgreSQL username (e.g., `paperless`)
- `db-pass`: PostgreSQL password

**Application Secrets:**
- `secret-key`: A random secret key for Django (generate with: `openssl rand -base64 32`)
- `redis-pass`: Password for Redis authentication (required - the Redis URL is automatically constructed from this in the container startup command)

**Admin User (Optional):**
- `username`: Initial admin username (if not set, you'll need to create a superuser manually)
- `password`: Initial admin password (required if `username` is set)

### `vaults/starbase/items/mailgun`
- `smtp-email`: SMTP email address
- `smtp-password`: SMTP password

## Configuration

### Environment Variables

Key configuration options are set via environment variables in `deployment.yaml`:

- **Database**: Configured to use PostgreSQL (credentials from consolidated secret)
- **Redis**: Configured to use Redis with authentication (URL automatically constructed from `redis-pass` in the container startup command)
- **OCR**: English language, skip mode (only OCR when needed)
- **Timezone**: America/New_York (adjust as needed)
- **URL**: https://paperless.apocalypso.xyz (update to your domain)

### Storage

All persistent volumes use the `nfs-csi` storage class for shared access across replicas.

### Ingress

The ingress is configured for:
- Domain: `paperless.apocalypso.xyz` (update as needed)
- TLS: Automatic via cert-manager with Let's Encrypt
- Homepage integration: Enabled for service discovery

## Deployment

This application is managed via ArgoCD. After committing changes:

1. ArgoCD will automatically detect and sync the application
2. The namespace will be created automatically
3. All resources will be deployed in order

## Disabling Consumer on Replicas

**Current Configuration**: The deployment uses 1 replica, so the consumer is enabled by default and there's no conflict.

**If Scaling Later**: If you increase replicas to 2+ for redundancy, you should disable the consumer (document processing) on all but one replica to prevent duplicate processing. Here are the options:

### Option 1: Create Separate Deployments (Recommended for Production)

Create two separate deployments:
1. **paperless-ngx-web**: 2+ replicas with `PAPERLESS_CONSUMER_DISABLE=true` (handles web requests)
2. **paperless-ngx-worker**: 1 replica with consumer enabled (processes documents)

This requires splitting the current deployment into two separate deployment manifests.

### Option 2: Manual Pod Patching (Temporary)

For a quick temporary fix, you can manually disable the consumer on specific pods:

```bash
# Get the pod name
kubectl get pods -n paperless-ngx -l app=paperless-ngx

# Patch a specific pod to disable consumer (replace POD_NAME)
kubectl patch pod <POD_NAME> -n paperless-ngx -p '{"spec":{"containers":[{"name":"paperless-ngx","env":[{"name":"PAPERLESS_CONSUMER_DISABLE","value":"true"}]}]}}'
```

**Note**: This is temporary and will be lost on pod restart. For a permanent solution, use Option 1.

## Initial Setup

After deployment:

1. Access the web UI at your configured domain
2. If `username` and `password` are set in the 1Password secret, the admin user will be created automatically
3. Otherwise, you'll need to create a superuser manually:
   ```bash
   kubectl exec -it deployment/paperless-ngx -n paperless-ngx -- python manage.py createsuperuser
   ```

## Version

- **Paperless-ngx**: v2.20.5 (latest as of deployment)
- **PostgreSQL**: 16-alpine
- **Redis**: 7-alpine

## Resources

- [Paperless-ngx Documentation](https://docs.paperless-ngx.com/)
- [Paperless-ngx GitHub](https://github.com/paperless-ngx/paperless-ngx)
- [Configuration Reference](https://docs.paperless-ngx.com/configuration/)
