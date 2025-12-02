# Deployment Guide

> ⚠️ **DEMO PURPOSES ONLY** - This is a demonstration environment, not intended for production use. No support or warranty is provided.

Complete guide for deploying the Kubernetes monitoring demo environment.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Cloud Deployment (GKE/EKS/AKS)](#cloud-deployment)
- [Local k3d Deployment](#local-k3d-deployment)
- [Deployed Components](#deployed-components)
- [Accessing Services](#accessing-services)
- [Verification](#verification)

## Prerequisites

### Required

- **Kubernetes cluster** (v1.20+) - local (k3d) or cloud (EKS, GKE, AKS)
- **kubectl** installed and configured
- **New Relic account** with Ingest License Key ([Get one free](https://newrelic.com/signup))

### Optional (for full stack)

- **Helm 3.x** - Required for additional components ([Install Helm](https://helm.sh/docs/intro/install/))
- **Sufficient cluster resources** - Recommended: 3+ nodes with 2 CPU, 4GB RAM each

## Quick Start

### 1. Create New Relic Secret

```bash
kubectl create namespace monitoring

kubectl create secret generic newrelic-license-key \
  -n monitoring \
  --from-literal=license-key=YOUR_NEW_RELIC_LICENSE_KEY
```

**Where to find your license key:**
- Log in to New Relic: https://one.newrelic.com
- Go to **Settings** → **API Keys**
- Copy your license key from the "Ingest - License" section

### 2. Deploy Base Stack

```bash
./scripts/deploy.sh
```

This deploys:
- Prometheus (with New Relic remote write)
- Grafana (with 11 pre-configured dashboards)
- Node Exporter (on all nodes)

**Deployment time:** ~2-3 minutes

### 3. Deploy Additional Components (Optional)

⚠️ **The base deployment only includes Prometheus, Grafana, and Node Exporter.**

To populate **ALL 11 dashboards with data**, deploy additional components:

```bash
# For production/cloud clusters
./scripts/helm-deploy.sh

# For local k3d clusters (optimized resource limits)
./helm-deploy-k3d.sh
```

This installs:
- kube-state-metrics
- cert-manager
- External Secrets Operator
- ArgoCD
- Istio (control plane + ingress)
- Sample applications

**Deployment time:** ~15-20 minutes

## Cloud Deployment

### Setting up GKE Cluster

```bash
# Create GKE cluster
gcloud container clusters create monitoring-demo \
  --zone us-central1-a \
  --num-nodes 3 \
  --machine-type n1-standard-2

# Get credentials
gcloud container clusters get-credentials monitoring-demo --zone us-central1-a
```

### Accessing Services (LoadBalancer)

Services are exposed via LoadBalancer with external IPs:

```bash
# Get external IPs (may take 2-3 minutes)
kubectl get svc -n monitoring

# Watch for IP assignment
kubectl get svc grafana -n monitoring -w
```

Once assigned:
- **Grafana**: http://\<GRAFANA_EXTERNAL_IP\>:3000 (admin / admin)
- **Prometheus**: http://\<PROMETHEUS_EXTERNAL_IP\>:9090

### Security Considerations for Public Deployments

⚠️ **Important:** This demo uses default credentials and LoadBalancer services for easy access.

For production:

1. **Change Grafana Admin Password:**
   ```bash
   kubectl exec -n monitoring deployment/grafana -- grafana-cli admin reset-admin-password <new-password>
   ```

2. **Enable HTTPS/TLS:**
   - Use Ingress with TLS certificates (cert-manager)
   - Configure SSL termination at load balancer

3. **Restrict Access:**
   - Configure firewall rules to limit IP ranges
   - Use network policies
   - Consider private clusters with VPN/bastion host

Example GKE firewall rule:
```bash
gcloud compute firewall-rules create grafana-access \
  --allow tcp:3000 \
  --source-ranges YOUR_IP/32 \
  --target-tags gke-cluster-node
```

## Local k3d Deployment

For local testing, see the complete guide: **[docs/k3d-quickstart.md](../docs/k3d-quickstart.md)**

Quick summary:

```bash
# 1. Create k3d cluster
./k3d-setup.sh

# 2. Create New Relic secret (same as above)

# 3. Deploy base stack
./scripts/deploy.sh

# 4. Deploy additional components (k3d optimized)
./helm-deploy-k3d.sh

# 5. Access services
./scripts/port-forward.sh
```

Access via:
- **Grafana**: http://localhost:3000 (admin / admin)
- **Prometheus**: http://localhost:9090

## Deployed Components

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

## Accessing Services

### Port Forwarding (Local/k3d)

```bash
./scripts/port-forward.sh
```

Or manually:

```bash
# Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80

# Prometheus
kubectl port-forward -n monitoring svc/prometheus-server 9090:9090

# ArgoCD
kubectl port-forward -n monitoring svc/argocd-server 8080:443
```

### ArgoCD Access

```bash
# Get initial admin password
kubectl -n monitoring get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Access: https://localhost:8080 or http://<external-ip>:8080
# Username: admin
# Password: (from command above)
```

## Verification

### View Grafana Dashboards

1. Open Grafana (via external IP or localhost:3000)
2. Log in with admin / admin
3. Go to **Dashboards** → **Browse**
4. Available dashboards:
   - **Node Exporter Full** - Comprehensive node metrics ✅ (immediate data)
   - **ArgoCD** - GitOps deployment monitoring
   - **Istio Performance** - Service mesh performance
   - **Istio Mesh** - Service mesh topology
   - **Istio Control Plane** - Istio control plane metrics
   - **Cert Manager** - Certificate management
   - **External Secrets** - Secrets synchronization
   - **Kubernetes Nodes** - Node-level metrics
   - **K8s Storage Volumes** - Persistent volume monitoring
   - **K8s Dashboard** - General cluster overview
   - **Kube State Metrics v2** - Cluster state metrics

### Check Prometheus Targets

```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-server 9090:9090

# Open: http://localhost:9090/targets
# All targets should be "UP"
```

Expected targets:
- prometheus
- node-exporter
- kube-state-metrics (if deployed)
- kubelet & cadvisor (if deployed)
- cert-manager (if deployed)
- external-secrets (if deployed)
- argocd components (if deployed)
- istiod (if deployed)
- envoy-stats (if deployed)

### Verify Remote Write to New Relic

```bash
# Check Prometheus logs
kubectl logs -n monitoring deployment/prometheus-server | grep "remote_write"

# Check in New Relic (after 1-2 minutes)
# Go to: Query your data → Metrics
# Run: FROM Metric SELECT * WHERE instrumentation.name = 'remote-write'
```

## Cleanup

### Remove Base Stack

```bash
./scripts/cleanup.sh
```

### Remove Helm Components

```bash
# Remove Helm releases
helm uninstall kube-state-metrics cert-manager external-secrets argocd -n monitoring
helm uninstall istio-ingressgateway istiod istio-base -n istio-system

# Delete namespaces
kubectl delete namespace istio-system demo-apps
```

### Delete k3d Cluster

```bash
k3d cluster delete monitoring-demo
```

## Next Steps

- [Configuration Guide](configuration-guide.md) - Customize components and metrics
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
