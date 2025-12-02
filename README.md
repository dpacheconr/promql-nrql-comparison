# Kubernetes Demo Environment

A complete Kubernetes demo environment for monitoring with Prometheus, Node Exporter, and Grafana. Prometheus remote writes metrics to New Relic while Grafana queries Prometheus directly.

## Architecture

```
Node Exporter (DaemonSet)
    ↓ (scrapes)
Prometheus (with remote write)
    ↓ (queries)        ↓ (remote write)
 Grafana          New Relic
```

## Prerequisites

- Kubernetes cluster (v1.20+) - local (k3d) or cloud (EKS, GKE, AKS, etc.)
- `kubectl` installed and configured
- New Relic account with API access key
- `curl` or `wget` for port forwarding helper (optional)

### Optional: Local Testing with k3d

```bash
k3d cluster create demo --agents 3
kubectl config use-context k3d-demo
```

## Quick Start

### 1. Create New Relic Secret

First, create the New Relic license key secret:

```bash
kubectl create namespace monitoring
kubectl create secret generic newrelic-license-key \
  -n monitoring \
  --from-literal=license-key=YOUR_NEW_RELIC_LICENSE_KEY
```

Replace `YOUR_NEW_RELIC_LICENSE_KEY` with your actual New Relic Ingest License Key.

**Where to find your license key:**
- Log in to New Relic: https://one.newrelic.com
- Go to **Settings** → **API Keys**
- Under "Ingest - License" section, copy your license key

### 2. Deploy the Stack

```bash
./deploy.sh
```

This script will:
- Create the monitoring namespace
- Deploy Prometheus with remote write to New Relic
- Deploy Node Exporter on all nodes
- Deploy Grafana with Prometheus datasource
- Wait for all components to be ready
- Display access instructions

### 3. Access Services

In a separate terminal, run:

```bash
./port-forward.sh
```

This will set up port forwarding:
- **Grafana**: http://localhost:3000 (admin / admin)
- **Prometheus**: http://localhost:9090

### 4. View Pre-installed Dashboards

1. Open Grafana at http://localhost:3000
2. Log in with admin / admin
3. Go to **Dashboards** → **Browse**
4. Browse the automatically provisioned dashboards:
   - **Node Exporter Full** - Comprehensive node metrics
   - **ArgoCD** - GitOps deployment monitoring
   - **Istio Performance** - Service mesh performance
   - **Istio Mesh** - Service mesh topology
   - **Istio Control Plane** - Istio control plane metrics
   - **Cert Manager** - Certificate management monitoring
   - **Kubernetes Nodes** - Node-level Kubernetes metrics
   - **K8s Storage Volumes** - Persistent volume monitoring
   - **K8s Dashboard** - General Kubernetes cluster overview
   - **Kube State Metrics v2** - Cluster state metrics

## File Structure

```
demo-environment/
├── README.md                      # This file
├── deploy.sh                      # Main deployment script
├── cleanup.sh                     # Cleanup all resources
├── port-forward.sh               # Port forwarding helper
├── manifests/
│   ├── namespace.yaml            # monitoring namespace
│   ├── prometheus/
│   │   ├── rbac.yaml             # ServiceAccount, RBAC
│   │   ├── configmap.yaml        # Prometheus configuration
│   │   ├── deployment.yaml       # Prometheus deployment
│   │   └── service.yaml          # Prometheus service
│   ├── node-exporter/
│   │   ├── daemonset.yaml        # Node Exporter DaemonSet
│   │   └── service.yaml          # Node Exporter service
│   └── grafana/
│       ├── configmap-datasource.yaml  # Prometheus datasource config
│       ├── configmap-dashboard.yaml   # Dashboard provisioning config
│       ├── deployment.yaml            # Grafana deployment (with init container for dashboard)
│       └── service.yaml               # Grafana service
├── docs/
│   └── promql-to-nrql-migration-guide.md  # Comprehensive PromQL to NRQL migration reference
└── secrets/
    ├── README.md                 # Secret creation instructions
    └── newrelic-secret.yaml.example  # Example secret template
```

## Configuration Details

### Prometheus Remote Write

Prometheus is configured to remote write metrics to New Relic using:
- **Endpoint**: `https://metric-api.newrelic.com/prometheus/v1/write`
- **Authentication**: Bearer token (New Relic license key)
- **Metrics filtered**: `node_.*` (Node Exporter metrics) and system metrics

### Node Exporter

- **DaemonSet**: Runs on every node in the cluster
- **Port**: 9090
- **Metrics**: Complete node-level metrics (CPU, memory, disk, network, etc.)
- **Discovery**: Automatically discovered by Prometheus via Kubernetes SD

### Grafana

- **Default credentials**: admin / admin (change after first login)
- **Datasource**: Prometheus at `http://prometheus-server.monitoring.svc.cluster.local:9090`
- **Dashboards**: 10 pre-configured dashboards automatically downloaded via init container
  - Node Exporter Full (1860)
  - ArgoCD (14584)
  - Istio Performance (11829)
  - Istio Mesh (7639)
  - Istio Control Plane (7645)
  - Cert Manager (11001)
  - Kubernetes Nodes (8171)
  - K8s Storage Volumes (11454)
  - K8s Dashboard (15661)
  - Kube State Metrics v2 (13332)
- **Port**: 3000

## Troubleshooting

### Check Deployment Status

```bash
# Check all pods
kubectl get pods -n monitoring

# Check pod logs
kubectl logs -n monitoring deployment/prometheus-server
kubectl logs -n monitoring deployment/grafana
kubectl logs -n monitoring daemonset/node-exporter

# Describe issues
kubectl describe pod -n monitoring <pod-name>
```

### Verify Remote Write is Working

```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-server 9090:9090

# Check remote write status at:
# http://localhost:9090/api/v1/query?query=up
# and check Status → Remote Write
```

### Verify Metrics Collection

```bash
# Port-forward to Node Exporter
kubectl port-forward -n monitoring svc/node-exporter 9100:9100

# Check metrics at:
# http://localhost:9100/metrics
```

### Reset Grafana Admin Password

```bash
kubectl exec -n monitoring deployment/grafana -- grafana-cli admin reset-admin-password <newpassword>
```

## Cleanup

To remove all resources:

```bash
./cleanup.sh
```

This will delete the entire monitoring namespace and all resources within it.

## Advanced Configuration

### Changing Scrape Interval

Edit `manifests/prometheus/configmap.yaml`:

```yaml
global:
  scrape_interval: 30s  # Change from default 15s
```

Then redeploy Prometheus:

```bash
kubectl apply -f manifests/prometheus/configmap.yaml
kubectl delete pods -n monitoring -l app=prometheus-server
```

### Adding Custom Metrics Filtering

Edit the `remote_write` section in `manifests/prometheus/configmap.yaml` to filter metrics:

```yaml
write_relabel_configs:
  - source_labels: [__name__]
    regex: 'node_.*|up'
    action: keep  # Only send these metrics
```

### Adding Additional Grafana Dashboards

10 dashboards are automatically downloaded via an init container. To add more dashboards:

1. Modify the `DASHBOARDS` list in the init container in `manifests/grafana/deployment.yaml`
2. Add entries in the format: `DASHBOARD_ID:filename.json`
3. Apply the changes with `kubectl apply -f manifests/grafana/deployment.yaml`
4. Restart the Grafana pod: `kubectl delete pod -n monitoring -l app=grafana`

Example additional dashboards:
- **11074**: Node Exporter for Prometheus (alternative view)
- **13659**: Blackbox Exporter
- **7249**: Kubernetes Cluster Monitoring

Alternatively, you can manually import dashboards via the Grafana UI after deployment.

## Multi-Cluster Setup

To deploy this to multiple clusters, simply repeat the deployment process on each cluster. Each cluster will send metrics independently to New Relic. You can identify metrics by cluster using the `cluster` label automatically added by Prometheus.

## Performance Considerations

- **Prometheus retention**: Default 24h (configurable in deployment)
- **Remote write queue**: Configured for up to 10,000 metrics in queue
- **Node Exporter**: Minimal overhead per node
- **Grafana**: Lightweight query caching

## Support & Issues

For issues or questions:

1. Check logs: `kubectl logs -n monitoring <component>`
2. Verify connectivity: `kubectl exec -n monitoring <pod> -- curl -v <endpoint>`
3. Review manifests: Check `manifests/*/` for configuration details
4. Review documentation: Check `docs/` for detailed guides

## License

This demo environment is provided as-is for educational and testing purposes.
