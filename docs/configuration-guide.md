# Configuration Guide

Comprehensive configuration reference for customizing the monitoring stack.

## Table of Contents

- [Prometheus Configuration](#prometheus-configuration)
- [Grafana Configuration](#grafana-configuration)
- [Helm Component Configuration](#helm-component-configuration)
- [Advanced Configurations](#advanced-configurations)
- [Multi-Cluster Setup](#multi-cluster-setup)

## Prometheus Configuration

### Scrape Configuration

Prometheus configuration is in `manifests/prometheus/configmap.yaml`.

#### Change Scrape Interval

```yaml
global:
  scrape_interval: 30s  # Change from default 15s
  evaluation_interval: 30s
```

Apply changes:
```bash
kubectl apply -f manifests/prometheus/configmap.yaml
kubectl delete pods -n monitoring -l app=prometheus-server
```

#### Add Custom Scrape Jobs

Add to `scrape_configs` section:

```yaml
scrape_configs:
  # ... existing jobs ...

  - job_name: 'my-custom-app'
    static_configs:
      - targets: ['my-app.my-namespace.svc.cluster.local:8080']
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
```

### Remote Write Configuration

#### Customize Metrics Filter

Edit `write_relabel_configs` to filter which metrics are sent to New Relic:

```yaml
remote_write:
  - url: "https://metric-api.newrelic.com/prometheus/v1/write"
    bearer_token_file: /etc/secrets/newrelic/license-key
    write_relabel_configs:
      # Keep only specific metrics
      - source_labels: [__name__]
        regex: 'node_.*|up|prometheus_.*|my_custom_.*'
        action: keep

      # Drop high-cardinality labels
      - regex: 'pod|container_id'
        action: labeldrop
```

#### Add Additional Remote Write Endpoints

```yaml
remote_write:
  - url: "https://metric-api.newrelic.com/prometheus/v1/write"
    bearer_token_file: /etc/secrets/newrelic/license-key
    # ... config ...

  - url: "https://other-endpoint.example.com/write"
    basic_auth:
      username: myuser
      password: mypassword
```

### Storage Configuration

Edit `manifests/prometheus/deployment.yaml`:

```yaml
args:
  - --storage.tsdb.retention.time=48h  # Change from 24h
  - --storage.tsdb.retention.size=10GB  # Add size limit
```

### Resource Limits

Adjust Prometheus resources in `manifests/prometheus/deployment.yaml`:

```yaml
resources:
  requests:
    cpu: 500m      # Increase from 250m
    memory: 1Gi    # Increase from 512Mi
  limits:
    cpu: 1000m     # Increase from 500m
    memory: 2Gi    # Increase from 1Gi
```

## Grafana Configuration

### Change Service Type

Edit `manifests/grafana/service.yaml`:

```yaml
spec:
  type: ClusterIP  # Change from LoadBalancer
  # or
  type: NodePort
```

### Add Custom Dashboards

Grafana automatically downloads dashboards via init container. To add more:

Edit the init container in `manifests/grafana/deployment.yaml`:

```bash
DASHBOARDS="
  1860:node-exporter-full.json
  14584:argocd.json
  YOUR_DASHBOARD_ID:your-dashboard.json
"
```

Or manually import via Grafana UI:
1. Open Grafana → Dashboards → Import
2. Enter dashboard ID from grafana.com
3. Select Prometheus datasource

### Configure SMTP for Alerts

Add to Grafana deployment env vars:

```yaml
env:
  - name: GF_SMTP_ENABLED
    value: "true"
  - name: GF_SMTP_HOST
    value: "smtp.gmail.com:587"
  - name: GF_SMTP_USER
    value: "your-email@gmail.com"
  - name: GF_SMTP_PASSWORD
    valueFrom:
      secretKeyRef:
        name: grafana-smtp
        key: password
```

### Enable Anonymous Access

```yaml
env:
  - name: GF_AUTH_ANONYMOUS_ENABLED
    value: "true"
  - name: GF_AUTH_ANONYMOUS_ORG_ROLE
    value: "Viewer"
```

### Add Additional Datasources

Create a new ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasource-influxdb
  namespace: monitoring
data:
  influxdb.yaml: |
    apiVersion: 1
    datasources:
      - name: InfluxDB
        type: influxdb
        access: proxy
        url: http://influxdb:8086
        database: mydb
```

Mount in Grafana deployment:
```yaml
volumeMounts:
  - name: datasource-influxdb
    mountPath: /etc/grafana/provisioning/datasources/influxdb.yaml
    subPath: influxdb.yaml
volumes:
  - name: datasource-influxdb
    configMap:
      name: grafana-datasource-influxdb
```

## Helm Component Configuration

All Helm components can be customized via values files in `helm-values/`.

### Modify Helm Values

Edit the appropriate file:
- `helm-values/kube-state-metrics-values.yaml`
- `helm-values/cert-manager-values.yaml`
- `helm-values/external-secrets-values.yaml`
- `helm-values/argocd-values.yaml`
- `helm-values/istio-*-values.yaml`

Re-run deployment:
```bash
./scripts/helm-deploy.sh  # or helm-deploy-k3d.sh
```

Or update individual component:
```bash
helm upgrade cert-manager jetstack/cert-manager \
  --namespace monitoring \
  --values helm-values/cert-manager-values.yaml
```

### kube-state-metrics

**Enable/disable specific collectors:**

Edit `helm-values/kube-state-metrics-values.yaml`:

```yaml
collectors:
  - certificatesigningrequests
  - configmaps
  - cronjobs
  - daemonsets
  - deployments
  - endpoints
  # ... add or remove collectors
```

**Adjust resources:**

```yaml
resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi
```

### ArgoCD

**Configure SSO/RBAC:**

Edit `helm-values/argocd-values.yaml`:

```yaml
server:
  config:
    url: https://argocd.example.com
    dex.config: |
      connectors:
        - type: github
          id: github
          name: GitHub
          config:
            clientID: $github-client-id
            clientSecret: $github-client-secret
```

**Enable metrics:**

```yaml
controller:
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
```

### Istio

**Enable tracing:**

Edit `helm-values/istio-istiod-values.yaml`:

```yaml
global:
  tracer:
    zipkin:
      address: jaeger-collector.istio-system:9411
```

**Adjust proxy resources:**

```yaml
global:
  proxy:
    resources:
      limits:
        cpu: 200m
        memory: 256Mi
      requests:
        cpu: 100m
        memory: 128Mi
```

## Advanced Configurations

### Add Service Monitor for Custom Apps

Create a ServiceMonitor CRD:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app-monitor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
    - port: metrics
      interval: 30s
```

### Configure Persistent Storage for Prometheus

Add PVC to Prometheus deployment:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-storage
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
```

Mount in deployment:
```yaml
volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: prometheus-storage
volumeMounts:
  - name: storage
    mountPath: /prometheus
```

### Enable Prometheus High Availability

Edit `manifests/prometheus/deployment.yaml`:

```yaml
spec:
  replicas: 2  # Change from 1
```

Add anti-affinity rules:
```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
            - key: app
              operator: In
              values:
                - prometheus-server
        topologyKey: kubernetes.io/hostname
```

### Configure Network Policies

Restrict access to Prometheus:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: prometheus-network-policy
  namespace: monitoring
spec:
  podSelector:
    matchLabels:
      app: prometheus-server
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: grafana
      ports:
        - protocol: TCP
          port: 9090
```

### Add Custom Recording Rules

Edit Prometheus ConfigMap to add recording rules:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    # ... existing config ...

    rule_files:
      - /etc/prometheus/rules/*.yml

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-rules
  namespace: monitoring
data:
  custom.rules.yml: |
    groups:
      - name: custom_rules
        interval: 30s
        rules:
          - record: job:node_cpu_utilization:avg
            expr: avg without (cpu) (rate(node_cpu_seconds_total{mode!="idle"}[5m]))

          - record: job:node_memory_utilization:ratio
            expr: 1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)
```

## Multi-Cluster Setup

### Deploy to Multiple Clusters

Repeat deployment on each cluster with cluster-specific labels:

**Cluster 1:**
```yaml
# Add to Prometheus external_labels in configmap
external_labels:
  cluster: production
  region: us-east-1
```

**Cluster 2:**
```yaml
external_labels:
  cluster: staging
  region: us-west-2
```

All metrics will be tagged with cluster labels in New Relic.

### Query Across Clusters in New Relic

```sql
-- All metrics from production cluster
FROM Metric SELECT * WHERE cluster = 'production'

-- Compare metrics across clusters
FROM Metric SELECT average(node_cpu_seconds_total)
FACET cluster
WHERE job = 'node-exporter'
```

### Centralized Grafana for Multiple Clusters

Use Prometheus federation or configure multiple Prometheus datasources in Grafana:

```yaml
apiVersion: 1
datasources:
  - name: Prometheus-Prod
    type: prometheus
    access: proxy
    url: http://prometheus-prod.monitoring.svc.cluster.local:9090

  - name: Prometheus-Staging
    type: prometheus
    access: proxy
    url: http://prometheus-staging.monitoring.svc.cluster.local:9090
```

## Performance Considerations

- **Prometheus retention**: Default 24h (adjust based on storage)
- **Remote write queue**: Configured for up to 10,000 metrics in queue
- **Scrape interval**: 15s default (increase for large deployments)
- **High cardinality**: Avoid labels with unbounded values (UUIDs, timestamps)

### Optimize for Large Deployments

1. **Increase Prometheus resources**
2. **Use remote write sharding**
3. **Reduce scrape frequency** for less critical metrics
4. **Filter metrics** aggressively before remote write
5. **Use recording rules** for expensive queries

## File Structure Reference

```
grafana_takeout_demo_env/
├── manifests/
│   ├── prometheus/
│   │   ├── rbac.yaml             # ServiceAccount, RBAC
│   │   ├── configmap.yaml        # Prometheus configuration
│   │   ├── deployment.yaml       # Prometheus deployment
│   │   └── service.yaml          # Prometheus service
│   ├── grafana/
│   │   ├── configmap-datasource.yaml  # Prometheus datasource
│   │   ├── configmap-dashboard.yaml   # Dashboard provisioning
│   │   ├── deployment.yaml            # Grafana deployment
│   │   └── service.yaml               # Grafana service
│   ├── node-exporter/
│   │   ├── daemonset.yaml        # Node Exporter DaemonSet
│   │   └── service.yaml          # Node Exporter service
│   └── sample-apps/              # Sample applications
├── helm-values/                  # Helm chart values
│   ├── kube-state-metrics-values.yaml
│   ├── cert-manager-values.yaml
│   ├── external-secrets-values.yaml
│   ├── argocd-values.yaml
│   └── istio-*-values.yaml
└── secrets/
    └── README.md                 # Secret management guide
```
