kubectl create namespace onepassword-connect

# Create the credentials secret with pre-encoded credentials
kubectl create secret generic op-credentials \
  --namespace onepassword-connect \
  --from-literal=1password-credentials.json="$(base64 < ~/Downloads/1password-credentials.json)"

# Create the token secret
kubectl create secret generic onepassword-token \
  --namespace onepassword-connect \
  --from-literal=token={token}
