# k3d Quick Start Guide

This guide will help you test the entire monitoring stack locally using k3d (Kubernetes in Docker).

## Prerequisites

- **Docker Desktop** (running)
- **k3d** ([install guide](https://k3d.io/#installation))
- **kubectl**
- **Helm 3.x** ([install guide](https://helm.sh/docs/intro/install/))
- **New Relic Ingest License Key** ([get one free](https://newrelic.com/signup))

### Install k3d (if not already installed)

```bash
# macOS
brew install k3d

# Linux
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Windows
choco install k3d
```

## Quick Start (5 Steps)

### Step 1: Create k3d Cluster

```bash
./k3d-setup.sh
```

This creates a local Kubernetes cluster with:
- 1 control plane node
- 2 worker nodes
- Port mappings for easy access

**Time:** ~2 minutes

### Step 2: Create New Relic Secret

```bash
kubectl create namespace monitoring

kubectl create secret generic newrelic-license-key \
  -n monitoring \
  --from-literal=license-key=YOUR_NEW_RELIC_LICENSE_KEY
```

Replace `YOUR_NEW_RELIC_LICENSE_KEY` with your actual license key from [New Relic](https://one.newrelic.com) → Settings → API Keys → Ingest - License.

### Step 3: Deploy Base Stack

```bash
./scripts/deploy.sh
```

This deploys:
- Prometheus (with New Relic remote write)
- Grafana (with 11 pre-configured dashboards)
- Node Exporter (on all nodes)

**Time:** ~2-3 minutes

### Step 4: Deploy Additional Components

```bash
./helm-deploy-k3d.sh
```

This deploys (with k3d-optimized resource limits):
- kube-state-metrics
- cert-manager
- External Secrets Operator
- ArgoCD
- Istio (control plane + ingress gateway)
- Sample applications with metrics

**Time:** ~10-15 minutes

### Step 5: Access Services

```bash
./scripts/port-forward.sh
```

Then open in your browser:
- **Grafana**: http://localhost:3000 (admin / admin)
- **Prometheus**: http://localhost:9090

## Verify Everything is Working

### Check All Pods are Running

```bash
# Base stack
kubectl get pods -n monitoring

# Helm components
kubectl get pods -n monitoring -l app.kubernetes.io/name=kube-state-metrics
kubectl get pods -n monitoring -l app.kubernetes.io/name=cert-manager

# Istio
kubectl get pods -n istio-system

# Sample apps
kubectl get pods -n demo-apps
```

All pods should be in `Running` or `Completed` state.

### Check Prometheus Targets

1. Port-forward: `kubectl port-forward -n monitoring svc/prometheus-server 9090:9090`
2. Open: http://localhost:9090/targets
3. All targets should show "UP" (may take 2-3 minutes)

Expected targets:
- prometheus
- node-exporter
- kube-state-metrics
- kubelet
- kubelet-cadvisor
- cert-manager
- external-secrets
- argocd-application-controller
- argocd-server
- argocd-repo-server
- istiod
- envoy-stats

### Check Grafana Dashboards

1. Open Grafana: http://localhost:3000
2. Login: admin / admin
3. Go to: Dashboards → Browse
4. You should see 11 dashboards

Try these dashboards to verify data:
- **Node Exporter Full** - Should show data immediately
- **Kube State Metrics v2** - Should show cluster state
- **Kubernetes Nodes** - Should show 3 nodes (1 server, 2 agents)
- **Istio Control Plane** - Should show istiod metrics
- **Cert Manager** - Should show 3 certificates

### Check ArgoCD

```bash
# Get password
kubectl -n monitoring get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Port-forward
kubectl port-forward svc/argocd-server -n monitoring 8080:443

# Access: https://localhost:8080
# Username: admin
# Password: (from above command)
```

## Troubleshooting

### Pods Stuck in Pending

```bash
# Check events
kubectl get events -n monitoring --sort-by='.lastTimestamp'

# Check node resources
kubectl top nodes

# If resources are low, reduce replicas
kubectl scale deployment -n demo-apps --replicas=1 --all
```

### Istio Sidecars Not Injecting

```bash
# Verify namespace has injection label
kubectl get namespace demo-apps -o jsonpath='{.metadata.labels.istio-injection}'
# Should output: enabled

# Restart pods to inject sidecar
kubectl rollout restart deployment -n demo-apps
```

### Prometheus Not Scraping Targets

```bash
# Check Prometheus logs
kubectl logs -n monitoring deployment/prometheus-server -f

# Check service endpoints
kubectl get endpoints -n monitoring
kubectl get endpoints -n istio-system

# Verify service names in Prometheus config
kubectl get configmap prometheus-config -n monitoring -o yaml
```

### Dashboard Shows "No Data"

This is normal! Some dashboards need time to collect metrics:

1. **Immediate data**: Node Exporter Full
2. **1-2 minutes**: Kube State Metrics, Kubernetes Nodes
3. **3-5 minutes**: Istio dashboards (after sample apps generate traffic)
4. **5-10 minutes**: ArgoCD (after apps sync)

Check Prometheus targets are UP: http://localhost:9090/targets

## Resource Usage

k3d cluster on a typical laptop:
- **CPU**: ~2-3 cores
- **Memory**: ~4-6 GB RAM
- **Disk**: ~5 GB

If your system struggles:

```bash
# Reduce component replicas
kubectl scale deployment -n demo-apps --replicas=1 --all

# Disable Istio (largest resource user)
helm uninstall istio-ingressgateway -n istio-system
helm uninstall istiod -n istio-system
```

## Cleanup

### Stop Cluster (Keep Data)

```bash
k3d cluster stop monitoring-demo
```

### Start Cluster Again

```bash
k3d cluster start monitoring-demo
kubectl config use-context k3d-monitoring-demo
```

### Delete Everything

```bash
k3d cluster delete monitoring-demo
```

This removes the entire cluster and all data.

## What's Different from Production?

k3d deployment uses:
- **Reduced resource limits** (50% less CPU/memory)
- **Fewer replicas** (1 instead of 2-3)
- **Disabled components** (Dex for ArgoCD, ArgoCD notifications)
- **Simplified networking** (no LoadBalancers, using port-forward)

For production deployment, use `helm-deploy.sh` instead of `helm-deploy-k3d.sh`.

## Tips

1. **Be patient** - k3d is slower than cloud clusters. Components can take 10-15 minutes to fully start.

2. **Check logs often**:
   ```bash
   kubectl logs -n monitoring <pod-name> -f
   ```

3. **Watch pod status**:
   ```bash
   watch kubectl get pods -A
   ```

4. **If stuck**, restart a component:
   ```bash
   kubectl rollout restart deployment <name> -n monitoring
   ```

## Next Steps

Once everything is working in k3d:

1. Explore the Grafana dashboards
2. Check metrics in New Relic
3. Modify Helm values in `helm-values/` to customize
4. Deploy to a real cluster (GKE, EKS, AKS)

## Support

If you encounter issues:
1. Check this troubleshooting guide
2. Review logs: `kubectl logs -n monitoring <component>`
3. Check events: `kubectl get events -n monitoring --sort-by='.lastTimestamp'`
4. Open an issue with logs and error messages
