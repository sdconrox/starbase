#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="argocd"

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update >/dev/null

cat > gitops/clusters/starbase/argocd/install/values.yaml <<'YAML'
# Keep this minimal; we can tune later

# Install CRDs with the chart (recommended for Helm installs)
crds:
  install: true
YAML

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

cat > gitops/clusters/starbase/argocd/install/bootstrap-applications.yaml <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: starbase-applications
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-100"
spec:
  project: default
  source:
    repoURL: https://gitea.sdconrox.com/sdconrox/starbase.git
    targetRevision: HEAD
    path: gitops/clusters/starbase/applications
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
YAML

kubectl apply -f gitops/clusters/starbase/argocd/install/bootstrap-applications.yaml
