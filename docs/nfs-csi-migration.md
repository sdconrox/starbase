# NFS CSI Driver Migration Guide

This guide explains how to migrate from `nfs-subdir-external-provisioner` to the NFS CSI Driver, which supports automatic volume expansion.

## Overview

The NFS CSI Driver provides:
- ✅ Automatic volume expansion support
- ✅ Active maintenance and updates
- ✅ Standard CSI interface
- ✅ Works with existing NFS server (no changes needed)

## Prerequisites

- ArgoCD installed and configured
- Existing NFS server at `10.60.0.6:/mnt/sdx-pool-0/sdx-starbase`
- All applications backed up (recommended)

## Step 1: Deploy NFS CSI Driver

The NFS CSI Driver is already configured in:
- Application: `gitops/clusters/starbase/applications/platform/nfs-csi-driver-application.yaml`
- Manifests: `gitops/platform/nfs-csi/`

**Verify deployment:**
```bash
# Check if the driver pods are running
kubectl get pods -n kube-system | grep nfs-csi

# Verify StorageClass is created
kubectl get storageclass nfs-csi
```

## Step 2: Verify New StorageClass

The new StorageClass `nfs-csi` should be available:
```bash
kubectl get storageclass nfs-csi -o yaml
```

It should show:
- `allowVolumeExpansion: true`
- `provisioner: nfs.csi.k8s.io`

## Step 3: Migrate Applications

### Option A: Migrate Existing PVCs (Recommended for Production)

This method preserves existing data by cloning PVCs.

#### For each application:

1. **Scale down the application** (to ensure data consistency):
   ```bash
   kubectl scale deployment <app-name> -n <namespace> --replicas=0
   ```

2. **Create a new PVC using the new storage class**:
   ```bash
   # Export the old PVC spec
   kubectl get pvc <old-pvc-name> -n <namespace> -o yaml > old-pvc.yaml

   # Edit the file to create a new PVC:
   # - Change metadata.name to <old-pvc-name>-new
   # - Change spec.storageClassName to nfs-csi
   # - Remove metadata.uid, metadata.resourceVersion, metadata.creationTimestamp
   # - Remove status section

   kubectl apply -f old-pvc.yaml
   ```

3. **Copy data from old PVC to new PVC**:
   ```bash
   # Create a temporary pod with both volumes mounted
   kubectl run pvc-migrator --image=busybox --rm -it --restart=Never \
     --overrides='
   {
     "spec": {
       "containers": [{
         "name": "migrator",
         "image": "busybox",
         "command": ["sh", "-c", "cp -av /old/* /new/"],
         "volumeMounts": [
           {"name": "old", "mountPath": "/old"},
           {"name": "new", "mountPath": "/new"}
         ]
       }],
       "volumes": [
         {"name": "old", "persistentVolumeClaim": {"claimName": "<old-pvc-name>"}},
         {"name": "new", "persistentVolumeClaim": {"claimName": "<old-pvc-name>-new"}}
       ]
     }
   }' -n <namespace>
   ```

4. **Update the deployment to use the new PVC**:
   ```bash
   # Edit the deployment manifest
   kubectl edit deployment <app-name> -n <namespace>
   # Change the volume claim name to the new PVC name
   ```

5. **Scale up the application**:
   ```bash
   kubectl scale deployment <app-name> -n <namespace> --replicas=1
   ```

6. **Verify the application is working**, then delete the old PVC:
   ```bash
   kubectl delete pvc <old-pvc-name> -n <namespace>
   ```

### Option B: Update New PVCs Only (For New Deployments)

For new applications or when you can recreate data:

1. **Update the PVC manifest** in `gitops/apps/<app>/`:
   ```yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: <app>-data
     namespace: <namespace>
   spec:
     accessModes:
       - ReadWriteOnce
     storageClassName: nfs-csi  # Changed from nfs
     resources:
       requests:
         storage: 20Gi
   ```

2. **Commit and push** - ArgoCD will sync the changes

3. **Delete the old PVC and let it recreate**:
   ```bash
   kubectl delete pvc <old-pvc-name> -n <namespace>
   # ArgoCD will recreate it with the new storage class
   ```

## Step 4: Update All Application Manifests

Update all PVCs in your application manifests to use `nfs-csi`:

**Files to update:**
- `gitops/apps/actual-budget/deployment.yaml`
- `gitops/apps/homebox/deployment.yaml`
- `gitops/apps/joplin/postgresql.yaml`
- `gitops/apps/mealie/deployment.yaml`
- `gitops/apps/mealie/postgres.yaml`
- `gitops/apps/planka/deployment.yaml`
- `gitops/apps/planka/postgres.yaml`
- `gitops/apps/vikunja/deployment.yaml`

**Change:**
```yaml
storageClassName: nfs  # Old
```
to:
```yaml
storageClassName: nfs-csi  # New
```

## Step 5: Test Volume Expansion

After migration, test volume expansion:

1. **Edit a PVC to increase size**:
   ```bash
   kubectl edit pvc <pvc-name> -n <namespace>
   # Change spec.resources.requests.storage to a larger value
   ```

2. **Verify expansion**:
   ```bash
   # Watch the PVC status
   kubectl get pvc <pvc-name> -n <namespace> -w

   # Should show FileSystemResizePending, then complete
   ```

3. **Verify inside the pod**:
   ```bash
   kubectl exec -it <pod-name> -n <namespace> -- df -h
   # Should show the new size
   ```

## Step 6: Cleanup (Optional)

Once all applications are migrated and verified:

1. **Keep the old provisioner** for a grace period (in case of rollback)
2. **After 30 days**, you can remove:
   - `gitops/clusters/starbase/applications/platform/nfs-provisioner-application.yaml`
   - The old StorageClass (if not in use)

## Troubleshooting

### PVC stuck in "Pending"
- Check if the NFS CSI Driver pods are running: `kubectl get pods -n kube-system | grep nfs-csi`
- Verify NFS server is accessible from cluster nodes
- Check StorageClass exists: `kubectl get storageclass nfs-csi`

### Expansion not working
- Verify StorageClass has `allowVolumeExpansion: true`
- Check PVC is using `nfs-csi` storage class
- Ensure NFS CSI Driver is at version 4.0.0+ (supports expansion)

### Data migration issues
- Always backup before migration
- Test migration on non-critical PVCs first
- Use `rsync` instead of `cp` for large datasets: `rsync -av /old/ /new/`

## Rollback

If you need to rollback:

1. **Update PVCs back to `nfs` storage class**
2. **Scale down applications**
3. **Copy data back** (if you kept old PVCs)
4. **Scale up applications**
5. **Remove NFS CSI Driver application** from ArgoCD

## Applications to Migrate

List of applications with PVCs that need migration:

1. **actual-budget** - `actual-budget-data`
2. **homebox** - `homebox-data`
3. **joplin** - `joplin-postgres-data`
4. **mealie** - `mealie-data`, `mealie-postgres-data`
5. **planka** - `planka-data`, `planka-db-data`
6. **vikunja** - `vikunja-data`

## Quick Migration Script

For automated migration of a single PVC:

```bash
#!/bin/bash
# Usage: ./migrate-pvc.sh <namespace> <pvc-name>

NAMESPACE=$1
PVC_NAME=$2
NEW_PVC_NAME="${PVC_NAME}-new"

# Scale down deployment (adjust selector as needed)
kubectl scale deployment -n $NAMESPACE --replicas=0 --all

# Export and modify PVC
kubectl get pvc $PVC_NAME -n $NAMESPACE -o yaml | \
  sed "s/name: $PVC_NAME/name: $NEW_PVC_NAME/" | \
  sed "s/storageClassName: nfs/storageClassName: nfs-csi/" | \
  grep -v "uid:\|resourceVersion:\|creationTimestamp:\|status:" | \
  kubectl apply -f -

# Wait for new PVC to be bound
kubectl wait --for=condition=Bound pvc/$NEW_PVC_NAME -n $NAMESPACE --timeout=5m

# Copy data (requires manual pod creation - see Option A step 3)

# Update deployment
kubectl patch deployment -n $NAMESPACE -p '{"spec":{"template":{"spec":{"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"'$NEW_PVC_NAME'"}}]}}}}'

# Scale up
kubectl scale deployment -n $NAMESPACE --replicas=1 --all
```

**Note:** Always test on non-production data first!
