# Kubernetes Monitoring Demo Environment

A complete Kubernetes monitoring stack with Prometheus, Grafana, and 11 pre-configured dashboards. Includes full observability stack with service mesh, GitOps, certificate management, and secrets management. All metrics are sent to New Relic for long-term storage and analysis.

## Features

✅ **Prometheus** - Metrics collection with New Relic remote write
✅ **Grafana** - 11 pre-configured dashboards for instant visibility
✅ **Complete Observability** - Node metrics, Kubernetes state, service mesh, GitOps
✅ **Production-Ready** - Helm-based deployment with customizable values
✅ **Local Testing** - Optimized k3d configuration for laptop development
✅ **Cloud-Ready** - Tested on GKE, EKS, and AKS

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Data Sources Layer                                              │
├─────────────────────────────────────────────────────────────────┤
│  • Node Exporter              • cert-manager                     │
│  • kube-state-metrics         • External Secrets Operator       │
│  • Kubelet/cAdvisor           • ArgoCD                          │
│  • Istio (istiod + sidecars)                                    │
└─────────────────────────────────────────────────────────────────┘
                    ↓ (scrapes every 15s)
┌─────────────────────────────────────────────────────────────────┐
│  Prometheus                                                      │
│  • Local storage (24h retention)                                │
│  • Remote write to New Relic                                    │
└─────────────────────────────────────────────────────────────────┘
        ↓ (queries)              ↓ (remote write)
┌──────────────┐           ┌──────────────┐
│   Grafana    │           │  New Relic   │
│  11 Dashboards│          │   (NRDB)     │
└──────────────┘           └──────────────┘
```

## Quick Start

### Prerequisites

- Kubernetes cluster (v1.20+)
- kubectl configured
- New Relic license key ([Get free account](https://newrelic.com/signup))

### Deploy in 3 Steps

```bash
# 1. Create New Relic secret
kubectl create namespace monitoring
kubectl create secret generic newrelic-license-key \
  -n monitoring \
  --from-literal=license-key=YOUR_LICENSE_KEY

# 2. Deploy base stack (Prometheus, Grafana, Node Exporter)
./scripts/deploy.sh

# 3. Deploy additional components (optional but recommended)
./scripts/helm-deploy.sh  # Cloud clusters
# OR
./helm-deploy-k3d.sh  # Local k3d clusters
```

**Access Grafana:**
- Cloud: Get external IP with `kubectl get svc -n monitoring grafana`
- Local: Run `./scripts/port-forward.sh` then visit http://localhost:3000
- Credentials: `admin` / `admin`

## Included Dashboards

1. **Node Exporter Full** - Complete node/host metrics
2. **ArgoCD** - GitOps deployment monitoring
3. **Istio Performance** - Service mesh performance
4. **Istio Mesh** - Service mesh topology
5. **Istio Control Plane** - Control plane metrics
6. **Cert Manager** - Certificate management
7. **External Secrets** - Secrets synchronization
8. **Kubernetes Nodes** - Node-level Kubernetes metrics
9. **K8s Storage Volumes** - Persistent volume monitoring
10. **K8s Dashboard** - General cluster overview
11. **Kube State Metrics v2** - Cluster state metrics

## Documentation

📘 **[Deployment Guide](docs/deployment-guide.md)** - Complete deployment instructions for cloud and local
🔧 **[Configuration Guide](docs/configuration-guide.md)** - Customize components and metrics
🐛 **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions
🚀 **[K3D Quick Start](K3D-QUICKSTART.md)** - Local testing with k3d

## What Gets Deployed

### Base Stack (`./scripts/deploy.sh`)
- Prometheus (metrics collection + remote write)
- Grafana (visualization + 11 dashboards)
- Node Exporter (host/node metrics)

### Additional Components (`./scripts/helm-deploy.sh`)
- kube-state-metrics (Kubernetes state)
- cert-manager (certificate management)
- External Secrets Operator (secrets sync)
- ArgoCD (GitOps)
- Istio (service mesh)
- Sample applications (demo apps for metrics)

## Local Development with k3d

Perfect for testing locally on your laptop:

```bash
# Create local cluster
./k3d-setup.sh

# Deploy everything
./scripts/deploy.sh
./helm-deploy-k3d.sh

# Access services
./scripts/port-forward.sh
```

See **[K3D Quick Start Guide](K3D-QUICKSTART.md)** for details.

## Cloud Deployment

### GKE Example

```bash
# Create cluster
gcloud container clusters create monitoring-demo \
  --zone us-central1-a \
  --num-nodes 3 \
  --machine-type n1-standard-2

# Deploy
kubectl create namespace monitoring
kubectl create secret generic newrelic-license-key \
  -n monitoring \
  --from-literal=license-key=YOUR_KEY
./scripts/deploy.sh
./scripts/helm-deploy.sh

# Access via LoadBalancer
kubectl get svc -n monitoring grafana
```

Similar steps for EKS and AKS. See **[Deployment Guide](docs/deployment-guide.md)** for details.

## Customization

All components can be customized via:
- Kubernetes manifests in `manifests/`
- Helm values files in `helm-values/`
- Prometheus config in `manifests/prometheus/configmap.yaml`

See **[Configuration Guide](docs/configuration-guide.md)** for examples.

## Monitoring Multiple Clusters

Deploy to each cluster with unique labels:

```yaml
# Cluster 1
external_labels:
  cluster: production
  region: us-east-1

# Cluster 2
external_labels:
  cluster: staging
  region: us-west-2
```

Query across clusters in New Relic:
```sql
FROM Metric SELECT average(node_cpu_seconds_total)
FACET cluster
WHERE job = 'node-exporter'
```

## Cleanup

```bash
# Remove base stack
./scripts/cleanup.sh

# Remove Helm components
helm uninstall kube-state-metrics cert-manager external-secrets argocd -n monitoring
helm uninstall istio-ingressgateway istiod istio-base -n istio-system

# Delete k3d cluster (if using k3d)
k3d cluster delete monitoring-demo
```

## Project Structure

```
├── deploy.sh                 # Deploy base stack
├── helm-deploy.sh            # Deploy Helm components (cloud)
├── helm-deploy-k3d.sh        # Deploy Helm components (k3d)
├── k3d-setup.sh              # Create k3d cluster
├── cleanup.sh                # Remove all resources
├── port-forward.sh           # Port forwarding helper
├── manifests/                # Kubernetes manifests
│   ├── prometheus/          # Prometheus configuration
│   ├── grafana/             # Grafana with 11 dashboards
│   ├── node-exporter/       # Node Exporter DaemonSet
│   └── sample-apps/         # Sample applications
├── helm-values/             # Helm chart values
└── docs/                    # Documentation
    ├── deployment-guide.md
    ├── configuration-guide.md
    └── troubleshooting.md
```

## Support

- 📖 **Documentation**: See [docs/](docs/) folder
- 🐛 **Issues**: Check [Troubleshooting Guide](docs/troubleshooting.md)
- 💬 **Questions**: Open an issue with your question

## License

This demo environment is provided as-is for educational and testing purposes.
