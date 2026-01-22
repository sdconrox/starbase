#!/usr/bin/env bash
# List all PVCs using the old 'nfs' storage class that need migration

set -euo pipefail

echo "PVCs using 'nfs' storage class (need migration to 'nfs-csi'):"
echo "================================================================="
echo ""

kubectl get pvc --all-namespaces -o json | \
  jq -r '.items[] |
    select(.spec.storageClassName == "nfs" or (.spec.storageClassName == null and .metadata.annotations."volume.beta.kubernetes.io/storage-class" == "nfs")) |
    "\(.metadata.namespace)\t\(.metadata.name)\t\(.spec.resources.requests.storage)\t\(.status.phase)"' | \
  column -t -s $'\t' | \
  awk 'BEGIN {print "NAMESPACE\tPVC_NAME\tSIZE\tSTATUS"; print "---------\t--------\t----\t------"} {print}'

echo ""
echo "Total PVCs to migrate:"
kubectl get pvc --all-namespaces -o json | \
  jq -r '.items[] |
    select(.spec.storageClassName == "nfs" or (.spec.storageClassName == null and .metadata.annotations."volume.beta.kubernetes.io/storage-class" == "nfs")) |
    .metadata.name' | wc -l
