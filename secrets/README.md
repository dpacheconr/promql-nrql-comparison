# Secrets Management

This directory contains secret configuration for the demo environment.

## New Relic License Key

### Creating the Secret

Before running `deploy.sh`, you must create the New Relic license key secret:

```bash
kubectl create namespace monitoring
kubectl create secret generic newrelic-license-key \
  -n monitoring \
  --from-literal=license-key=YOUR_NEW_RELIC_LICENSE_KEY
```

Replace `YOUR_NEW_RELIC_LICENSE_KEY` with your actual New Relic Ingest License Key.

### Finding Your License Key

1. Log in to New Relic: https://one.newrelic.com
2. Click on your profile icon in the top right
3. Go to **Settings** → **API Keys**
4. Look for **Ingest - License** section
5. Copy the license key

### Verification

To verify the secret was created correctly:

```bash
kubectl get secret -n monitoring newrelic-license-key
kubectl describe secret -n monitoring newrelic-license-key
```

### Secret Usage

The secret is mounted into the Prometheus pod at:
- Mount path: `/etc/secrets/newrelic/`
- File name: `license-key`

Prometheus accesses it via the `bearer_token_file` configuration in `manifests/prometheus/configmap.yaml`.

## Example Secret File

See `newrelic-secret.yaml.example` for a template of what the secret would look like as a Kubernetes manifest (though using `kubectl create secret` is preferred).

## Important Notes

- **DO NOT** commit actual license keys to version control
- **DO NOT** check in `.yaml` files containing real credentials
- Use `kubectl create secret` for creating secrets directly in the cluster
- For production environments, use proper secret management (Sealed Secrets, HashiCorp Vault, etc.)

## Troubleshooting

### Secret not found error

If you see an error like `secret "newrelic-license-key" not found`, the secret hasn't been created yet. Run the creation command above.

### Remote write failures

If Prometheus remote write is failing:

1. Verify the license key is correct
2. Check Prometheus logs: `kubectl logs -n monitoring deployment/prometheus-server`
3. Verify network connectivity to New Relic endpoint:
   ```bash
   kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
     curl -H "Authorization: Bearer YOUR_LICENSE_KEY" \
     https://metric-api.newrelic.com/prometheus/v1/write
   ```

### Updating the Secret

If you need to update the license key:

```bash
kubectl delete secret newrelic-license-key -n monitoring
kubectl create secret generic newrelic-license-key \
  -n monitoring \
  --from-literal=license-key=NEW_LICENSE_KEY
kubectl rollout restart deployment/prometheus-server -n monitoring
```
