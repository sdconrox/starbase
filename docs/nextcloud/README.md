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

The Application’s Helm values include `extraManifests` so the operator creates:

- **nextcloud-secrets** (from `vaults/starbase/items/nextcloud`) – admin, DB, Redis
- **smtp-mailgun** (from `vaults/starbase/items/mailgun`) – SMTP for Mailgun (same item as Mealie/Paperless; keys `smtp-email`, `smtp-password`)

SMTP is configured via env vars (`SMTP_HOST`, `SMTP_PORT`, `SMTP_NAME`, `SMTP_PASSWORD`, `MAIL_FROM_ADDRESS`, `MAIL_DOMAIN`) per [Nextcloud docker SMTP](https://github.com/nextcloud/docker?tab=readme-ov-file#e-mail-smtp-configuration).

## NFS and PostgreSQL

PostgreSQL (Bitnami subchart) is configured to run as **UID 1000** and **GID 1000**, with **fsGroup 1000**, so it matches your other Postgres workloads (paperless-ngx, mealie, joplin) and the NFS Mapall user `k8s-nfs` (typically UID 1000). No NFS server changes are required.

## Why the main app runs as UID 1000 (no root)

The official Nextcloud image entrypoint writes `/usr/local/etc/php/conf.d/redis-session.ini` (and does rsync to populate `/var/www/html`). That directory is root-owned in the image, so the container must either run as root or have that config created beforehand. We use an **init container** that runs as root, creates the Redis session config in a shared `emptyDir`, and chowns it to 1000:1000. The main container then runs as **UID 1000** (matching NFS Mapall) and can write to that dir; the entrypoint completes and populates the PVC with the app (including `cron.php`).

## Cron job and startup order

The **cron does not run first**. The CronJob mounts the same PVC as the main app. The PVC gets `/var/www/html` (including `cron.php`) only after the main Nextcloud pods start and the entrypoint completes (rsync from image to volume). So the first time you deploy, the cron job may fail with “Could not open input file: /var/www/html/cron.php” until the main pods are up and healthy. Once the main app has run at least once, the cron will find `cron.php` and succeed.
