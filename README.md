# Kubernetes Monitoring Demo Environment

A comprehensive Kubernetes demo environment for monitoring with Prometheus, Grafana, and 11 pre-configured dashboards. Features full observability stack including Kubernetes metrics, service mesh (Istio), GitOps (ArgoCD), certificate management (cert-manager), and secrets management (External Secrets Operator). Prometheus remote writes all metrics to New Relic while Grafana queries Prometheus directly for visualization.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Data Sources Layer                                              │
├─────────────────────────────────────────────────────────────────┤
│  • Node Exporter (DaemonSet)      - Host/Node metrics           │
│  • kube-state-metrics             - Kubernetes state metrics    │
│  • Kubelet/cAdvisor               - Container/volume metrics    │
│  • Istio (istiod + sidecars)      - Service mesh metrics        │
│  • ArgoCD                         - GitOps metrics               │
│  • cert-manager                   - Certificate metrics         │
│  • External Secrets Operator      - Secrets sync metrics        │
└─────────────────────────────────────────────────────────────────┘
                    ↓ (scrapes)
┌─────────────────────────────────────────────────────────────────┐
│  Prometheus (with remote write)                                 │
│  • Scrapes all targets every 15s                                │
│  • Stores locally (24h retention)                               │
│  • Filters & sends to New Relic                                 │
└─────────────────────────────────────────────────────────────────┘
        ↓ (queries)              ↓ (remote write)
┌──────────────┐           ┌──────────────┐
│   Grafana    │           │  New Relic   │
│  11 Dashboards│          │   NRDB       │
└──────────────┘           └──────────────┘
```

## Prerequisites

### Required

- **Kubernetes cluster** (v1.20+) - local (k3d) or cloud (EKS, GKE, AKS, etc.)
- **kubectl** installed and configured
- **New Relic account** with Ingest License Key ([Get one free](https://newrelic.com/signup))

### Optional (for full dashboard data)

- **Helm 3.x** - Required for `helm-deploy.sh` to install additional components ([Install Helm](https://helm.sh/docs/intro/install/))
- **Sufficient cluster resources** - Recommended: 3+ nodes with 2 CPU, 4GB RAM each
- **curl/wget** - For port forwarding helper script (optional)

### Setting up GKE Cluster

```bash
# Create GKE cluster
gcloud container clusters create promql-nrql-demo \
  --zone us-central1-a \
  --num-nodes 3 \
  --machine-type n1-standard-2

# Get credentials
gcloud container clusters get-credentials promql-nrql-demo --zone us-central1-a
```

### 🚀 Recommended: Local Testing with k3d

**For local testing, we provide a complete k3d setup with optimized configurations:**

```bash
./k3d-setup.sh
```

This creates a local Kubernetes cluster optimized for all monitoring components.

**👉 See [K3D-QUICKSTART.md](K3D-QUICKSTART.md) for the complete k3d testing guide with troubleshooting.**

Then use `helm-deploy-k3d.sh` instead of `helm-deploy.sh` for k3d-optimized resource limits.

<details>
<summary>Manual k3d setup (click to expand)</summary>

```bash
k3d cluster create monitoring-demo --agents 2
kubectl config use-context k3d-monitoring-demo
```

</details>

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

#### For GKE/Cloud Deployments (LoadBalancer)

Services are exposed via LoadBalancer with external IPs:

```bash
# Get the external IPs (may take 2-3 minutes to provision)
kubectl get svc -n monitoring

# Watch for IP assignment
kubectl get svc grafana -n monitoring -w
```

Once the EXTERNAL-IP is assigned, access:
- **Grafana**: http://\<GRAFANA_EXTERNAL_IP\>:3000 (admin / admin)
- **Prometheus**: http://\<PROMETHEUS_EXTERNAL_IP\>:9090

#### For Local/Development (Port Forwarding)

For local k3d clusters, use port forwarding:

```bash
./port-forward.sh
```

Access via:
- **Grafana**: http://localhost:3000 (admin / admin)
- **Prometheus**: http://localhost:9090

### 4. Deploy Additional Components (IMPORTANT!)

⚠️ **The base deployment only includes Prometheus, Grafana, and Node Exporter.**

To populate **ALL 11 dashboards with data**, you need to deploy additional components using Helm:

```bash
./helm-deploy.sh
```

This script will install:

- **kube-state-metrics** - Kubernetes resource state metrics
- **cert-manager** - Certificate management and metrics
- **External Secrets Operator** - Secrets synchronization and metrics
- **ArgoCD** - GitOps platform and deployment metrics
- **Istio** - Service mesh (control plane + data plane)
- **Sample Applications** - Demo apps to generate realistic metrics

**Prerequisites for helm-deploy.sh:**

- Helm 3.x installed ([installation guide](https://helm.sh/docs/intro/install/))
- kubectl configured with cluster access
- Sufficient cluster resources (recommended: 3+ nodes with 2 CPU, 4GB RAM each)

**Deployment time:** ~15-20 minutes

### 5. View Pre-installed Dashboards

1. Open Grafana (via external IP or localhost)
2. Log in with admin / admin
3. Go to **Dashboards** → **Browse**
4. Browse the automatically provisioned dashboards:
   - **Node Exporter Full** - Comprehensive node metrics ✅ (data available immediately)
   - **ArgoCD** - GitOps deployment monitoring (requires helm-deploy.sh)
   - **Istio Performance** - Service mesh performance (requires helm-deploy.sh)
   - **Istio Mesh** - Service mesh topology (requires helm-deploy.sh)
   - **Istio Control Plane** - Istio control plane metrics (requires helm-deploy.sh)
   - **Cert Manager** - Certificate management monitoring (requires helm-deploy.sh)
   - **External Secrets** - Secrets synchronization monitoring (requires helm-deploy.sh)
   - **Kubernetes Nodes** - Node-level Kubernetes metrics (requires helm-deploy.sh)
   - **K8s Storage Volumes** - Persistent volume monitoring (requires helm-deploy.sh)
   - **K8s Dashboard** - General Kubernetes cluster overview (requires helm-deploy.sh)
   - **Kube State Metrics v2** - Cluster state metrics (requires helm-deploy.sh)

## Deployed Components Overview

### Base Stack (deploy.sh)

| Component | Purpose | Metrics Port |
|-----------|---------|--------------|
| Prometheus | Metrics collection and remote write | 9090 |
| Grafana | Visualization and dashboards | 3000 |
| Node Exporter | Host/node-level metrics | 9100 |

### Additional Components (helm-deploy.sh)

| Component | Purpose | Metrics Port | Dashboard(s) |
|-----------|---------|--------------|--------------|
| kube-state-metrics | Kubernetes resource state | 8080 | K8s Nodes, Storage, Dashboard, KSM v2 |
| cert-manager | Certificate management | 9402 | Cert Manager |
| External Secrets | Secrets synchronization | 8080 | External Secrets |
| ArgoCD | GitOps deployments | 8082, 8083, 8084 | ArgoCD |
| Istio (istiod) | Service mesh control plane | 15014 | Istio Control Plane |
| Istio (sidecars) | Service mesh data plane | 15090 | Istio Performance, Istio Mesh |

## File Structure

```
grafana_takeout_demo_env/
├── README.md                      # This file
├── deploy.sh                      # Main deployment script (Prometheus, Grafana, Node Exporter)
├── helm-deploy.sh                 # Helm components deployment script (new!)
├── cleanup.sh                     # Cleanup all resources
├── port-forward.sh               # Port forwarding helper
├── manifests/
│   ├── namespace.yaml            # monitoring namespace
│   ├── prometheus/
│   │   ├── rbac.yaml             # ServiceAccount, RBAC
│   │   ├── configmap.yaml        # Prometheus configuration (with all scrape configs)
│   │   ├── deployment.yaml       # Prometheus deployment
│   │   └── service.yaml          # Prometheus service
│   ├── node-exporter/
│   │   ├── daemonset.yaml        # Node Exporter DaemonSet
│   │   └── service.yaml          # Node Exporter service
│   ├── grafana/
│   │   ├── configmap-datasource.yaml  # Prometheus datasource config
│   │   ├── configmap-dashboard.yaml   # Dashboard provisioning config
│   │   ├── deployment.yaml            # Grafana deployment (11 dashboards)
│   │   └── service.yaml               # Grafana service
│   └── sample-apps/               # Sample applications (new!)
│       ├── demo-namespace.yaml    # demo-apps namespace with Istio injection
│       ├── sample-app-with-istio.yaml    # Demo apps with Istio sidecars
│       ├── sample-certificate.yaml       # cert-manager certificate examples
│       ├── sample-externalsecret.yaml    # External Secrets examples
│       └── sample-argocd-app.yaml        # ArgoCD application examples
├── helm-values/                   # Helm chart values (new!)
│   ├── kube-state-metrics-values.yaml
│   ├── cert-manager-values.yaml
│   ├── external-secrets-values.yaml
│   ├── argocd-values.yaml
│   ├── istio-base-values.yaml
│   ├── istio-istiod-values.yaml
│   └── istio-gateway-values.yaml
├── docs/
│   └── promql-to-nrql-migration-guide.md  # Comprehensive PromQL to NRQL migration reference
└── secrets/
    ├── README.md                 # Secret creation instructions
    └── newrelic-secret.yaml.example  # Example secret template
```

## Configuration Details

### Prometheus Configuration

Prometheus is configured to:

**Scrape targets:**

- Node Exporter (all nodes)
- kube-state-metrics (Kubernetes state)
- Kubelet & cAdvisor (container/volume metrics)
- cert-manager (certificate metrics)
- External Secrets Operator (secrets sync metrics)
- ArgoCD components (GitOps metrics)
- Istio control plane (istiod)
- Istio data plane (Envoy sidecars)

**Remote write to New Relic:**

- **Endpoint**: `https://metric-api.newrelic.com/prometheus/v1/write`
- **Authentication**: Bearer token (New Relic license key)
- **Metrics filtered**: All component metrics (node, kube, kubelet, container, cert-manager, external-secrets, argocd, istio, envoy, pilot metrics)

### Node Exporter

- **DaemonSet**: Runs on every node in the cluster
- **Port**: 9090
- **Metrics**: Complete node-level metrics (CPU, memory, disk, network, etc.)
- **Discovery**: Automatically discovered by Prometheus via Kubernetes SD

### Grafana

- **Default credentials**: admin / admin (⚠️ **CHANGE IMMEDIATELY** for public deployments)
- **Service Type**: LoadBalancer (publicly accessible on GKE)
- **Datasource**: Prometheus at `http://prometheus-server.monitoring.svc.cluster.local:9090`
- **Dashboards**: 11 pre-configured dashboards automatically downloaded via init container
  - Node Exporter Full (1860)
  - ArgoCD (14584)
  - Istio Performance (11829)
  - Istio Mesh (7639)
  - Istio Control Plane (7645)
  - Cert Manager (11001)
  - External Secrets (14043)
  - Kubernetes Nodes (8171)
  - K8s Storage Volumes (11454)
  - K8s Dashboard (15661)
  - Kube State Metrics v2 (13332)
- **Port**: 3000

## Security Considerations

⚠️ **Important for Public Deployments:**

This demo uses default credentials and LoadBalancer services for easy access. For production use:

1. **Change Grafana Admin Password Immediately:**
   ```bash
   kubectl exec -n monitoring deployment/grafana -- grafana-cli admin reset-admin-password <new-password>
   ```

2. **Enable HTTPS/TLS:**
   - Use Ingress with TLS certificates (cert-manager)
   - Configure SSL termination at the load balancer level

3. **Restrict Access:**
   - Configure firewall rules to limit IP ranges
   - Use GKE network policies
   - Consider using private clusters with VPN/bastion host

4. **Alternative: Use ClusterIP + Ingress:**
   - Change service type from `LoadBalancer` to `ClusterIP`
   - Deploy an Ingress controller (nginx, traefik)
   - Configure Ingress resources with authentication

Example firewall rule for GKE:
```bash
# Allow access only from your IP
gcloud compute firewall-rules create grafana-access \
  --allow tcp:3000 \
  --source-ranges YOUR_IP/32 \
  --target-tags gke-cluster-node
```

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

### Check Helm Components Status

```bash
# List all Helm releases
helm list -n monitoring
helm list -n istio-system

# Check specific component status
kubectl get all -n monitoring -l app.kubernetes.io/name=kube-state-metrics
kubectl get all -n monitoring -l app.kubernetes.io/name=cert-manager
kubectl get all -n monitoring -l app.kubernetes.io/name=external-secrets
kubectl get all -n monitoring -l app.kubernetes.io/name=argocd-server
kubectl get all -n istio-system

# Check Istio sidecar injection
kubectl get namespace demo-apps -o jsonpath='{.metadata.labels.istio-injection}'
# Should output: enabled

# Verify Istio sidecars in pods
kubectl get pods -n demo-apps -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
# Should show pods with both app container and istio-proxy container
```

### Check Prometheus Targets

```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-server 9090:9090

# Open in browser: http://localhost:9090/targets
# All targets should be "UP"
```

### ArgoCD Access

```bash
# Get initial admin password
kubectl -n monitoring get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port-forward to ArgoCD
kubectl port-forward svc/argocd-server -n monitoring 8080:443

# Access: https://localhost:8080
# Username: admin
# Password: (from command above)
```

### Certificate Issues (cert-manager)

```bash
# Check certificate status
kubectl get certificates -A
kubectl describe certificate demo-certificate-monitoring -n monitoring

# Check cert-manager logs
kubectl logs -n monitoring deployment/cert-manager -f

# Force certificate renewal
kubectl delete secret demo-tls-secret -n monitoring
```

### External Secrets Issues

```bash
# Check ExternalSecret status
kubectl get externalsecrets -A
kubectl describe externalsecret demo-external-secret -n monitoring

# Check ESO logs
kubectl logs -n monitoring deployment/external-secrets -f

# Verify secret was created
kubectl get secret demo-secret-from-external -n monitoring
```

## Cleanup

### Remove All Resources

To remove base stack (Prometheus, Grafana, Node Exporter):

```bash
./cleanup.sh
```

This will delete the entire monitoring namespace and all resources within it.

### Remove Helm Components

To remove Helm-deployed components:

```bash
# Remove all Helm releases
helm uninstall kube-state-metrics -n monitoring
helm uninstall cert-manager -n monitoring
helm uninstall external-secrets -n monitoring
helm uninstall argocd -n monitoring
helm uninstall istio-ingressgateway -n istio-system
helm uninstall istiod -n istio-system
helm uninstall istio-base -n istio-system

# Delete namespaces
kubectl delete namespace istio-system
kubectl delete namespace demo-apps

# Delete sample applications
kubectl delete -f manifests/sample-apps/
```

Or create a cleanup script for Helm components:

```bash
# cleanup-helm.sh
for release in kube-state-metrics cert-manager external-secrets argocd; do
  helm uninstall $release -n monitoring 2>/dev/null || true
done

for release in istio-ingressgateway istiod istio-base; do
  helm uninstall $release -n istio-system 2>/dev/null || true
done

kubectl delete namespace istio-system demo-apps --ignore-not-found=true
```

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

11 dashboards are automatically downloaded via an init container. To add more dashboards:

1. Modify the `DASHBOARDS` list in the init container in `manifests/grafana/deployment.yaml`
2. Add entries in the format: `DASHBOARD_ID:filename.json`
3. Apply the changes with `kubectl apply -f manifests/grafana/deployment.yaml`
4. Restart the Grafana pod: `kubectl delete pod -n monitoring -l app=grafana`

Example additional dashboards:

- **11074**: Node Exporter for Prometheus (alternative view)
- **13659**: Blackbox Exporter
- **7249**: Kubernetes Cluster Monitoring

Alternatively, you can manually import dashboards via the Grafana UI after deployment.

### Customizing Helm Values

All Helm components can be customized by editing the values files in `helm-values/`:

- `kube-state-metrics-values.yaml` - Adjust collectors, resources
- `cert-manager-values.yaml` - Configure issuers, resources
- `external-secrets-values.yaml` - Configure providers, refresh intervals
- `argocd-values.yaml` - Configure replicas, authentication
- `istio-*-values.yaml` - Configure telemetry, gateways, resources

After modifying values, re-run:

```bash
./helm-deploy.sh
```

Or update individual components:

```bash
helm upgrade cert-manager jetstack/cert-manager \
  --namespace monitoring \
  --values helm-values/cert-manager-values.yaml
```

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
