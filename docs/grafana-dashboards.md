# Grafana Dashboards Overview

This document provides a high-level overview of each dashboard included in the Grafana monitoring stack.

## Dashboard Summary

The project includes **11 pre-configured dashboards** that are automatically provisioned during Grafana deployment. These dashboards provide comprehensive monitoring coverage for Kubernetes infrastructure, applications, and platform services.

## Dashboard Details

### 1. Node Exporter Full (ID: 1860)
**File:** `node-exporter-full.json`

**What it Monitors:**
- Complete host/node system metrics
- CPU usage, load average, and performance
- Memory utilization and swap usage
- Disk I/O, filesystem usage, and storage metrics
- Network traffic and interface statistics
- System uptime and kernel metrics

**Best For:** Understanding the health and performance of the underlying nodes in your Kubernetes cluster.

---

### 2. ArgoCD (ID: 14584)
**File:** `argocd.json`

**What it Monitors:**
- GitOps application deployment status
- Sync status and sync history
- Application health across the cluster
- Repository connection status
- Reconciliation performance
- Deployment frequency and trends

**Best For:** Tracking GitOps deployments and ensuring applications are synchronized with their Git repositories.

**Note:** Requires ArgoCD to be deployed (available via `scripts/helm-deploy.sh`).

---

### 3. Istio Performance (ID: 11829)
**File:** `istio-performance.json`

**What it Monitors:**
- Service mesh request rates and latency
- HTTP request/response metrics
- Service-to-service communication performance
- Request success/error rates
- P50, P90, P99 latency percentiles
- Throughput and bandwidth usage

**Best For:** Analyzing service mesh performance and identifying communication bottlenecks between services.

**Note:** Requires Istio service mesh to be deployed.

---

### 4. Istio Mesh (ID: 7639)
**File:** `istio-mesh.json`

**What it Monitors:**
- Service mesh topology and connections
- Overall mesh health
- Service discovery status
- mTLS certificate status
- Mesh-wide traffic patterns
- Inter-service dependencies

**Best For:** Understanding the overall service mesh topology and connectivity patterns.

**Note:** Requires Istio service mesh to be deployed.

---

### 5. Istio Control Plane (ID: 7645)
**File:** `istio-control-plane.json`

**What it Monitors:**
- Istiod (control plane) performance
- Pilot configuration sync status
- Envoy proxy connection status
- Control plane resource usage
- Configuration push rates
- Certificate issuance and rotation

**Best For:** Monitoring the health and performance of Istio's control plane components.

**Note:** Requires Istio service mesh to be deployed.

---

### 6. Cert Manager (ID: 11001)
**File:** `cert-manager.json`

**What it Monitors:**
- TLS certificate status and expiration
- Certificate issuance success/failure rates
- Certificate renewal operations
- ACME challenge status
- Certificate request queue
- Issuer health and connectivity

**Best For:** Tracking TLS certificate lifecycle and preventing certificate expiration issues.

**Note:** Requires cert-manager to be deployed.

---

### 7. External Secrets (GitHub)
**File:** `external-secrets.json`
**Source:** [External Secrets Operator GitHub](https://github.com/external-secrets/external-secrets)

**What it Monitors:**
- Secret synchronization status
- SecretStore connectivity
- Sync success/failure rates
- Secret refresh operations
- Backend provider health
- Sync latency and performance

**Best For:** Monitoring external secret synchronization and ensuring secrets are kept up-to-date.

**Note:** Requires external-secrets-operator to be deployed. Dashboard is sourced directly from the ESO project repository.

---

### 8. Kubernetes Nodes (ID: 8171)
**File:** `kubernetes-nodes.json`

**What it Monitors:**
- Node-level Kubernetes metrics
- Kubelet performance and health
- Pod capacity and allocation
- Node conditions (Ready, MemoryPressure, DiskPressure)
- Container runtime metrics
- Node resource reservations

**Best For:** Understanding node-level Kubernetes operations and capacity planning.

---

### 9. K8s Storage Volumes (ID: 11454)
**File:** `k8s-storage-volumes.json`

**What it Monitors:**
- Persistent Volume (PV) usage and capacity
- Persistent Volume Claim (PVC) status
- Storage class utilization
- Volume mount status
- Storage I/O metrics
- Volume expansion operations

**Best For:** Monitoring storage consumption and identifying storage-related issues before they impact applications.

---

### 10. K8s Dashboard (ID: 15661)
**File:** `k8s-dashboard.json`

**What it Monitors:**
- General cluster overview and health
- Namespace resource usage
- Pod status across the cluster
- Deployment and StatefulSet status
- Service and Ingress status
- Cluster-wide resource consumption

**Best For:** Getting a high-level view of overall cluster health and resource usage.

---

### 11. Kube State Metrics v2 (ID: 13332)
**File:** `kube-state-metrics-v2.json`

**What it Monitors:**
- Kubernetes object state metrics
- Deployment, DaemonSet, StatefulSet status
- Pod phases and conditions
- Job and CronJob execution
- ConfigMap and Secret counts
- Resource quota usage

**Best For:** Deep dive into Kubernetes object states and tracking cluster configuration.

**Note:** Requires kube-state-metrics to be deployed.

---

## Dashboard Categories

### Infrastructure Monitoring
- **Node Exporter Full** - Host/node system metrics
- **Kubernetes Nodes** - Node-level K8s operations

### Cluster State & Resources
- **K8s Dashboard** - Overall cluster overview
- **Kube State Metrics v2** - Kubernetes object states
- **K8s Storage Volumes** - Persistent storage monitoring

### Service Mesh (Istio)
- **Istio Performance** - Service mesh performance
- **Istio Mesh** - Mesh topology and connectivity
- **Istio Control Plane** - Control plane health

### Platform Services
- **ArgoCD** - GitOps deployments
- **Cert Manager** - TLS certificate lifecycle
- **External Secrets** - Secret synchronization

---

## Accessing Dashboards

### Grafana Login
- **Username:** `admin`
- **Password:** `admin`
- **URL:**
  - Cloud deployments: `http://<EXTERNAL_IP>:3000`
  - Local k3d: `http://localhost:3000` (after port-forward)

### Finding Dashboards
1. Log into Grafana
2. Click "Dashboards" in the left sidebar (or the four-squares icon)
3. Browse or search for the dashboard you need
4. Dashboards are organized in the "General" folder

---

## Data Requirements

### Immediate Data (After Base Deployment)
- **Node Exporter Full** - Shows data immediately from node metrics

### Requires Additional Components
The following dashboards need specific components deployed via `scripts/helm-deploy.sh`:

- **ArgoCD Dashboard** → Requires ArgoCD
- **Istio Dashboards** → Requires Istio service mesh
- **Cert Manager Dashboard** → Requires cert-manager
- **External Secrets Dashboard** → Requires external-secrets-operator
- **Kube State Metrics Dashboard** → Requires kube-state-metrics
- **Storage/Node Dashboards** → Requires kube-state-metrics and node-exporter

To deploy all components and populate all dashboards with data:
```bash
./scripts/helm-deploy.sh
```

---

## Technical Details

### Provisioning Method
Dashboards are automatically provisioned via an init container in the Grafana deployment that:
1. Downloads dashboard JSON files from Grafana.com API during pod startup
2. Stores them in `/var/lib/grafana/dashboards`
3. Auto-loads via the dashboard provider configuration

### Configuration Files
- **Provisioning Config:** [manifests/grafana/configmap-dashboard.yaml](../manifests/grafana/configmap-dashboard.yaml)
- **Datasource Config:** [manifests/grafana/configmap-datasource.yaml](../manifests/grafana/configmap-datasource.yaml)
- **Deployment Manifest:** [manifests/grafana/deployment.yaml](../manifests/grafana/deployment.yaml)

### Auto-Reload
Dashboards are configured to auto-reload every 10 seconds, so any changes or additions are picked up automatically.

---

## Adding Custom Dashboards

To add your own custom dashboards, see the [Configuration Guide](configuration-guide.md#adding-custom-dashboards) for detailed instructions.

---

## Troubleshooting

### Dashboard Shows "No Data"
1. Verify Prometheus is scraping metrics: Check Prometheus UI → Targets
2. Ensure required components are deployed (see "Data Requirements" above)
3. Check datasource configuration in Grafana → Configuration → Data Sources
4. Verify time range selection in dashboard (top-right corner)

### Dashboard Not Appearing
1. Check Grafana pod logs: `kubectl logs -n monitoring deployment/grafana`
2. Verify init container completed successfully
3. Check dashboard provisioning config: `kubectl describe configmap -n monitoring grafana-dashboard`

### Metrics Missing for Specific Services
1. Ensure ServiceMonitor is created for the service
2. Check Prometheus has discovered the ServiceMonitor
3. Verify service pods have metrics endpoints exposed
4. Check network policies aren't blocking Prometheus scraping

---

## Related Documentation

- [README](../README.md) - Project overview and quick start
- [Deployment Guide](deployment-guide.md) - Step-by-step deployment instructions
- [Configuration Guide](configuration-guide.md) - Customization and configuration options
- [Troubleshooting Guide](troubleshooting.md) - Common issues and solutions
