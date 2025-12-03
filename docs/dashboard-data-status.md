# Dashboard Data Status and Traffic Generation

## Current Deployment Status

### ✅ Infrastructure Components Deployed

Based on the current cluster state, the following monitoring and platform components are **deployed and generating metrics**:

| Component | Status | Namespace | Metrics Generated |
|-----------|--------|-----------|-------------------|
| **Prometheus** | ✅ Running | monitoring | Scraping all targets |
| **Grafana** | ✅ Running | monitoring | Dashboards available |
| **Node Exporter** | ✅ Running (DaemonSet) | monitoring | Host/node metrics |
| **Kube State Metrics** | ✅ Running | monitoring | K8s object states |
| **Istio (istiod)** | ✅ Running | istio-system | Control plane metrics |
| **Istio Ingress Gateway** | ✅ Running | istio-system | Gateway metrics |
| **ArgoCD** | ✅ Running | monitoring | Platform metrics |
| **Cert Manager** | ✅ Running | monitoring | Controller metrics |
| **External Secrets** | ✅ Running | monitoring | Operator metrics |

---

### ❌ Sample Applications NOT Deployed

The **demo-apps namespace exists but is empty**. The following sample applications that generate application traffic are **NOT currently deployed**:

| Application | File | Purpose | Status |
|-------------|------|---------|--------|
| **demo-app (v1)** | sample-app-with-istio.yaml | HTTP echo service | ❌ Not deployed |
| **demo-app-v2** | sample-app-with-istio.yaml | HTTP echo service v2 | ❌ Not deployed |
| **traffic-generator** | sample-app-with-istio.yaml | CronJob to generate traffic | ❌ Not deployed |
| **sample certificates** | sample-certificate.yaml | Cert-manager test certs | ❌ Not deployed |
| **sample external secrets** | sample-externalsecret*.yaml | ESO test secrets | ❌ Not deployed |
| **ArgoCD guestbook apps** | sample-argocd-app.yaml | GitOps demo apps | ❌ Not deployed |

---

## Dashboard Data Availability

### Dashboards WITH Data (Infrastructure Only)

These dashboards currently have data from infrastructure components:

#### 1. ✅ Node Exporter Full
- **Status**: Fully populated
- **Data Source**: Node Exporter DaemonSet (3 pods running)
- **Metrics Available**:
  - CPU, memory, disk usage
  - Network interface statistics
  - System load and uptime
  - Filesystem metrics

#### 2. ✅ Kubernetes Nodes
- **Status**: Fully populated
- **Data Source**: Kube State Metrics + Node Exporter
- **Metrics Available**:
  - Node conditions and status
  - Kubelet performance
  - Pod capacity and allocation

#### 3. ✅ K8s Dashboard
- **Status**: Fully populated
- **Data Source**: Kube State Metrics + Kubelet
- **Metrics Available**:
  - Cluster overview (3 nodes)
  - All deployed workloads
  - Resource usage by namespace

#### 4. ✅ Kube State Metrics v2
- **Status**: Fully populated
- **Data Source**: Kube State Metrics
- **Metrics Available**:
  - All K8s object states
  - Deployment/StatefulSet/DaemonSet status
  - Pod phases and conditions

#### 5. ✅ K8s Storage Volumes
- **Status**: Fully populated
- **Data Source**: Kube State Metrics
- **Metrics Available**:
  - PV/PVC status
  - Storage class usage
  - local-path-provisioner volumes

#### 6. ⚠️ Istio Control Plane
- **Status**: Partial data
- **Data Source**: istiod and istio-ingressgateway
- **Metrics Available**:
  - Control plane health
  - Pilot configuration sync
  - Envoy proxy connections
- **Missing**: Application sidecar metrics (no apps with Istio sidecars deployed)

#### 7. ⚠️ Cert Manager
- **Status**: Minimal data
- **Data Source**: Cert-manager controller pods
- **Metrics Available**:
  - Controller health and performance
  - Ready/not-ready metrics
- **Missing**: Certificate lifecycle events (no test certificates deployed)

#### 8. ⚠️ External Secrets
- **Status**: Minimal data
- **Data Source**: External-secrets operator pods
- **Metrics Available**:
  - Operator health
  - Webhook status
- **Missing**: Secret sync operations (no ExternalSecrets deployed)

#### 9. ⚠️ ArgoCD
- **Status**: Minimal data
- **Data Source**: ArgoCD controller and server pods
- **Metrics Available**:
  - ArgoCD component health
  - Controller performance
- **Missing**: Application sync status (no applications deployed)

---

### Dashboards WITHOUT Application Traffic Data

These dashboards need sample applications to show meaningful service mesh traffic:

#### 10. ❌ Istio Performance
- **Status**: No application traffic data
- **What's Missing**:
  - Service-to-service request rates
  - HTTP latency metrics (P50, P90, P99)
  - Request success/error rates
  - Service mesh throughput
- **Needs**: demo-app v1 and v2 with traffic generator

#### 11. ❌ Istio Mesh
- **Status**: No service mesh topology
- **What's Missing**:
  - Service mesh topology visualization
  - Inter-service dependencies
  - Traffic flow patterns
  - mTLS status between services
- **Needs**: demo-app v1 and v2 with traffic generator

---

## How to Populate All Dashboards with Data

### Option 1: Deploy All Sample Applications (Recommended)

Deploy the complete set of sample applications to populate all dashboards:

```bash
# Deploy sample apps with Istio sidecars
kubectl apply -f manifests/sample-apps/sample-app-with-istio.yaml

# Deploy sample certificates for cert-manager testing
kubectl apply -f manifests/sample-apps/sample-certificate.yaml

# Deploy sample external secrets (choose one based on your setup)
# For Kubernetes backend:
kubectl apply -f manifests/sample-apps/sample-externalsecret-kubernetes.yaml
# OR for Fake/AWS backend:
kubectl apply -f manifests/sample-apps/sample-externalsecret.yaml

# Deploy ArgoCD sample applications
kubectl apply -f manifests/sample-apps/sample-argocd-app.yaml
```

**Wait 2-3 minutes**, then verify:

```bash
# Check demo apps are running
kubectl get pods -n demo-apps

# Check traffic generator is scheduled
kubectl get cronjob -n demo-apps

# Check ArgoCD applications
kubectl get applications -n monitoring

# Check sample certificates
kubectl get certificates -n demo-apps

# Check external secrets
kubectl get externalsecrets -n demo-apps
```

---

### Option 2: Use Deployment Script

The deployment script should handle all sample apps, but appears to have not been run or completed:

```bash
# For k3d local cluster
./scripts/helm-deploy-k3d.sh

# For cloud clusters (GKE/EKS/AKS)
./scripts/helm-deploy.sh
```

**Note**: Check the script execution to ensure the sample-apps section completed successfully (around line 189-209 in helm-deploy.sh).

---

### Option 3: Deploy Selectively

If you only want specific dashboard data:

#### For Istio Service Mesh Dashboards Only:
```bash
kubectl apply -f manifests/sample-apps/sample-app-with-istio.yaml
```
This deploys:
- demo-app v1 and v2
- traffic-generator CronJob
- Populates: Istio Performance, Istio Mesh dashboards

#### For Cert Manager Dashboard Only:
```bash
kubectl apply -f manifests/sample-apps/sample-certificate.yaml
```
This creates test certificates with short renewal periods to show lifecycle events.

#### For External Secrets Dashboard Only:
```bash
kubectl apply -f manifests/sample-apps/sample-externalsecret-kubernetes.yaml
```
This creates test secret stores and external secrets to show sync operations.

#### For ArgoCD Dashboard Only:
```bash
kubectl apply -f manifests/sample-apps/sample-argocd-app.yaml
```
This deploys guestbook demo apps to show GitOps deployment tracking.

---

## Traffic Generator Details

Once deployed, the **traffic-generator CronJob** runs automatically:

- **Schedule**: Every 1 minute
- **Pattern**:
  - 10 requests to demo-app
  - 10 requests to demo-app-v2
  - 1-second delay between requests
- **Total**: 20 requests per minute
- **Tool**: curl (lightweight)

This generates consistent, predictable traffic that populates:
- Request rate metrics
- Latency distributions (P50, P90, P99)
- Success/error rates
- Service mesh connectivity graphs

---

## Verification Steps

After deploying sample applications, verify data is flowing:

### 1. Check Prometheus Targets
```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-server 9090:80

# Open http://localhost:9090/targets
# Verify all demo-app pods show as "UP"
```

### 2. Check Grafana Dashboards

```bash
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80

# Open http://localhost:3000 (admin/admin)
# Navigate to dashboards and verify data appears
```

Expected timeline:
- **Immediate** (0-30 seconds): Node, K8s cluster dashboards
- **1-2 minutes**: Istio control plane, component health
- **2-3 minutes**: Istio service mesh traffic (after traffic generator runs)
- **5-10 minutes**: Certificate renewals, secret syncs (based on configured intervals)

---

## Current Metrics Summary

### What You Can Monitor Right Now:

✅ **Infrastructure Health**
- All 3 nodes are healthy
- System resources (CPU, memory, disk, network)
- Kubernetes control plane health

✅ **Platform Components**
- All monitoring components running (Prometheus, Grafana)
- All platform services healthy (Istio, ArgoCD, cert-manager, external-secrets)
- Kube-state-metrics showing all cluster objects

✅ **Cluster Operations**
- Pod counts and status
- Deployment health
- Resource usage by namespace
- Storage volume usage

### What You CANNOT Monitor Yet:

❌ **Application Traffic**
- No service-to-service communication metrics
- No HTTP request/response metrics
- No application latency measurements
- No service mesh topology visualization

❌ **Platform Features in Action**
- No certificate lifecycle events (issuance, renewal)
- No secret synchronization operations
- No GitOps application deployments

---

## Recommended Next Step

**Deploy sample applications now** to populate all dashboards with meaningful data:

```bash
# Quick deploy all samples
kubectl apply -f manifests/sample-apps/
```

Then check Grafana in 2-3 minutes to see:
- Service mesh traffic in Istio dashboards
- Application metrics flowing through the system
- Complete end-to-end observability

---

## Related Documentation

- [Grafana Dashboards Overview](grafana-dashboards.md) - Detailed dashboard descriptions
- [Configuration Guide](configuration-guide.md) - Customization options
- [Deployment Guide](deployment-guide.md) - Full deployment instructions
- [Troubleshooting Guide](troubleshooting.md) - Common issues and solutions
