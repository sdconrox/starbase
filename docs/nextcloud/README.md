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

The NFS share uses **Mapall User/Group = k8s-nfs**, so all client operations map to `k8s-nfs` on the server regardless of the UID inside the container. This means:

- Nextcloud runs as **root** (the image default) - NFS sees writes as `k8s-nfs`
- PostgreSQL runs as **UID 1000** - NFS sees writes as `k8s-nfs`
- Both work because they're the same user on the server side

**Note:** `chown` and `chmod` will fail with "Operation not permitted" on this NFS - that's expected with Mapall. Nextcloud runs as root (no securityContext override) so it can write to the container filesystem (e.g. PHP config) and rsync into the NFS volume.

## Cron job and startup order

The CronJob mounts the same PVC as the main app. The PVC only contains the app (including `cron.php`) after the main Nextcloud pods start and the entrypoint completes its rsync. On first deploy, the cron may fail until the main app is up. Once the main app has run successfully, the cron will find `cron.php` and work.
