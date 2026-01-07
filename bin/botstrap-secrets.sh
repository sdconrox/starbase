kubectl create namespace onepassword-connect

# Create the credentials secret
kubectl create secret generic op-credentials \
  --namespace onepassword-connect \
  --from-file=1password-credentials.json=/Users/sdconrox/Downloads/1password-credentials.json

# Create the token secret
kubectl create secret generic onepassword-token \
  --namespace onepassword-connect \
  --from-literal=token={token}
