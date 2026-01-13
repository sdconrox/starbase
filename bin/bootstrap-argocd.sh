#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="argocd"

kubectl create namespace "$NAMESPACE"

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# cat > gitops/clusters/starbase/argocd/install/values.yaml <<'YAML'
# # Install CRDs with the chart (recommended for Helm installs)
# crds:
#   install: true
# configs:
#   params:
#     server.insecure: true
#   # Reduce application controller polling to reduce etcd load
#   controller.application.resync: 300  # Default is 180 (3 min), increase to 300 (5 min)
#   controller.hardResyncPeriod: 24h    # Hard resync period (default is 0, meaning disabled)
#   controller.replicas: 1               # Ensure only 1 controller instance
# controller:
#   # Reduce concurrent operations to prevent overwhelming etcd
#   operationProcessors: 10              # Default is 10, reduce if needed
#   statusProcessors: 20                # Default is 20, reduce if needed
#   # Increase timeout for slow etcd responses
#   timeout:
#     applicationResyncPeriod: 300      # 5 minutes
# YAML

helm upgrade --install argocd argo/argo-cd \
  -n "$NAMESPACE" \
  -f gitops/clusters/starbase/argocd/install/values.yaml \
  --wait

# Release "argocd" does not exist. Installing it now.
# NAME: argocd
# LAST DEPLOYED: Tue Jan  6 22:12:38 2026
# NAMESPACE: argocd
# STATUS: deployed
# REVISION: 1
# DESCRIPTION: Install complete
# TEST SUITE: None
# NOTES:
# In order to access the server UI you have the following options:

# 1. kubectl port-forward service/argocd-server -n argocd 8080:443

#     and then open the browser on http://localhost:8080 and accept the certificate

# 2. enable ingress in the values file `server.ingress.enabled` and either
#       - Add the annotation for ssl passthrough: https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/#option-1-ssl-passthrough
#       - Set the `configs.params."server.insecure"` in the values file and terminate SSL at your ingress: https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/#option-2-multiple-ingress-objects-and-hosts


# After reaching the UI the first time you can login with username: admin and the random password generated during the installation. You can find the password by running:

# kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# (You should delete the initial secret afterwards as suggested by the Getting Started Guide: https://argo-cd.readthedocs.io/en/stable/getting_started/#4-login-using-the-cli)

# cat > gitops/clusters/starbase/argocd/install/bootstrap-applications.yaml <<'YAML'
# apiVersion: argoproj.io/v1alpha1
# kind: Application
# metadata:
#   name: starbase-applications
#   namespace: argocd
#   annotations:
#     argocd.argoproj.io/sync-wave: "-100"
# spec:
#   project: default
#   source:
#     repoURL: https://gitea.sdconrox.com/sdconrox/starbase.git
#     targetRevision: HEAD
#     path: gitops/clusters/starbase/applications
#   destination:
#     server: https://kubernetes.default.svc
#     namespace: argocd
#   syncPolicy:
#     automated:
#       prune: true
#       selfHeal: true
#     syncOptions:
#       - CreateNamespace=true
# YAML

kubectl apply -f gitops/clusters/starbase/argocd/install/bootstrap-applications.yaml
