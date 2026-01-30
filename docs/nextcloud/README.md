# Nextcloud (HA)

HA Nextcloud is deployed by the ArgoCD Application at
`gitops/clusters/starbase/applications/apps/nextcloud-application.yaml`,
which points at the [official Nextcloud Helm chart](https://github.com/nextcloud/helm) and inlines all values there (same pattern as kube-prometheus-stack).

## 1Password item

Create a single 1Password item at **`vaults/starbase/items/nextcloud`** with these field labels (they become K8s secret keys):

| Label (field name)       | Description                           |
|--------------------------|---------------------------------------|
| `username`               | Nextcloud admin username              |
| `password`               | Nextcloud admin password              |
| `db-password`            | PostgreSQL user password              |
| `postgres-password`      | PostgreSQL superuser (admin) password |
| `db-replication-password`| PostgreSQL replication password       |
| `redis-password`         | Redis password                        |

The Application's Helm values include `extraManifests` so the operator creates:

- **nextcloud-secrets** (from `vaults/starbase/items/nextcloud`) – admin, DB, Redis
- **smtp-mailgun** (from `vaults/starbase/items/mailgun`) – SMTP for Mailgun (same item as Mealie/Paperless; keys `smtp-email`, `smtp-password`)

SMTP is configured via env vars (`SMTP_HOST`, `SMTP_PORT`, `SMTP_NAME`, `SMTP_PASSWORD`, `MAIL_FROM_ADDRESS`, `MAIL_DOMAIN`) per [Nextcloud docker SMTP](https://github.com/nextcloud/docker?tab=readme-ov-file#e-mail-smtp-configuration).

## NFS with Mapall

The NFS share uses **Mapall User/Group = k8s-nfs**, which causes `rsync --chown` to fail. To work around this, we use a **split volume strategy**:

1. **App code** (`/var/www/html`): Mounted as `emptyDir` (local to each pod)
   - The Nextcloud entrypoint's rsync writes here with no NFS permission issues
   - Each pod initializes independently on startup (fast, local storage)

2. **Persistent data** (from NFS PVC with subPaths):
   - `/var/www/html/data` → user files
   - `/var/www/html/config` → config.php
   - `/var/www/html/custom_apps` → installed apps
   - `/var/www/html/themes` → custom themes

This means the app code is NOT shared across pods (each runs from its own copy), but all persistent data IS shared via NFS. This is the recommended pattern for Nextcloud HA.

PostgreSQL and Redis use NFS directly with UID 1000, which maps to `k8s-nfs` on the server.

## Cron job

The CronJob mounts the same volumes as the main app. Since app code is in an emptyDir, the cronjob also runs its own rsync on startup. This adds a few seconds of initialization overhead but ensures `cron.php` is always available.
