# Nextcloud (HA)

HA Nextcloud is deployed by the ArgoCD Application at  
`gitops/clusters/starbase/applications/apps/nextcloud-application.yaml`,  
which points at the [official Nextcloud Helm chart](https://github.com/nextcloud/helm) and inlines all values there (same pattern as kube-prometheus-stack).

## 1Password item

Create a single 1Password item at **`vaults/starbase/items/nextcloud`** with these field labels (they become K8s secret keys):

| Label (field name)       | Description                    |
|--------------------------|--------------------------------|
| `username`               | Nextcloud admin username       |
| `password`               | Nextcloud admin password       |
| `db-password`            | PostgreSQL user password       |
| `postgres-password`     | PostgreSQL superuser (admin) password |
| `db-replication-password`| PostgreSQL replication password|
| `redis-password`         | Redis password                 |

The Application’s Helm values include `extraManifests` so the operator creates:

- **nextcloud-secrets** (from `vaults/starbase/items/nextcloud`) – admin, DB, Redis
- **smtp-mailgun** (from `vaults/starbase/items/mailgun`) – SMTP for Mailgun (same item as Mealie/Paperless; keys `smtp-email`, `smtp-password`)

SMTP is configured via env vars (`SMTP_HOST`, `SMTP_PORT`, `SMTP_NAME`, `SMTP_PASSWORD`, `MAIL_FROM_ADDRESS`, `MAIL_DOMAIN`) per [Nextcloud docker SMTP](https://github.com/nextcloud/docker?tab=readme-ov-file#e-mail-smtp-configuration).

## NFS and PostgreSQL

PostgreSQL (Bitnami subchart) is configured to run as **UID 1000** and **GID 1000**, with **fsGroup 1000**, so it matches your other Postgres workloads (paperless-ngx, mealie, joplin) and the NFS Mapall user `k8s-nfs` (typically UID 1000). No NFS server changes are required.
