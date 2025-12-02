# Troubleshooting Guide

Common issues and solutions for the Kubernetes monitoring demo environment.

## Table of Contents

- [Deployment Issues](#deployment-issues)
- [Pod Issues](#pod-issues)
- [Metrics Collection Issues](#metrics-collection-issues)
- [Remote Write Issues](#remote-write-issues)
- [Dashboard Issues](#dashboard-issues)
- [Component-Specific Issues](#component-specific-issues)

## Deployment Issues

### Secret Not Found Error

**Symptom:** `secret "newrelic-license-key" not found`

**Solution:**
```bash
kubectl create namespace monitoring
kubectl create secret generic newrelic-license-key \
  -n monitoring \
  --from-literal=license-key=YOUR_NEW_RELIC_LICENSE_KEY
```

### Pods Stuck in Pending

**Check node resources:**
```bash
kubectl get nodes
kubectl describe nodes
kubectl top nodes
```

**Common causes:**
- Insufficient cluster resources
- Node selector not matching
- Taints blocking pod scheduling

**Solution for k3d:**
```bash
# Reduce replicas
kubectl scale deployment -n demo-apps --replicas=1 --all
```

### Image Pull Errors

**Check pod events:**
```bash
kubectl describe pod -n monitoring <pod-name>
```

**Common causes:**
- Private registry authentication
- Image name typos
- Network connectivity issues

## Pod Issues

### Check Deployment Status

```bash
# Check all pods
kubectl get pods -n monitoring
kubectl get pods -n istio-system
kubectl get pods -n demo-apps

# Check pod logs
kubectl logs -n monitoring deployment/prometheus-server
kubectl logs -n monitoring deployment/grafana
kubectl logs -n monitoring daemonset/node-exporter

# Describe pod for events
kubectl describe pod -n monitoring <pod-name>
```

### Pod CrashLoopBackOff

**Check logs:**
```bash
kubectl logs -n monitoring <pod-name> --previous
```

**Common causes:**
- Configuration errors
- Missing dependencies
- Resource limits too low

**Solution:**
```bash
# Check resource limits
kubectl get pod -n monitoring <pod-name> -o yaml | grep -A 5 resources

# Increase limits if needed
kubectl edit deployment -n monitoring <deployment-name>
```

### Pod Not Ready

**Check readiness probe:**
```bash
kubectl describe pod -n monitoring <pod-name> | grep -A 10 "Readiness"
```

**Common causes:**
- Service not responding
- Port mismatch
- Probe timeout too short

## Metrics Collection Issues

### Prometheus Not Scraping Targets

**Check Prometheus targets:**
```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-server 9090:9090

# Open: http://localhost:9090/targets
```

**If targets show "DOWN":**

1. **Check service endpoints:**
   ```bash
   kubectl get endpoints -n monitoring
   kubectl get endpoints -n istio-system
   ```

2. **Verify service names in Prometheus config:**
   ```bash
   kubectl get configmap prometheus-config -n monitoring -o yaml
   ```

3. **Test connectivity from Prometheus pod:**
   ```bash
   kubectl exec -n monitoring deployment/prometheus-server -- \
     wget -qO- http://node-exporter.monitoring.svc.cluster.local:9100/metrics
   ```

### Node Exporter Not Collecting Metrics

**Check DaemonSet:**
```bash
kubectl get daemonset -n monitoring node-exporter
kubectl get pods -n monitoring -l app=node-exporter
```

**Verify metrics endpoint:**
```bash
# Port-forward to Node Exporter
kubectl port-forward -n monitoring svc/node-exporter 9100:9100

# Check metrics: http://localhost:9100/metrics
```

### kube-state-metrics Not Working

**Check deployment:**
```bash
kubectl get deployment -n monitoring kube-state-metrics
kubectl logs -n monitoring deployment/kube-state-metrics
```

**Common issues:**
- RBAC permissions missing
- API server connectivity

**Solution:**
```bash
# Verify RBAC
kubectl get clusterrole | grep kube-state-metrics
kubectl get clusterrolebinding | grep kube-state-metrics
```

## Remote Write Issues

### Prometheus Not Sending Metrics to New Relic

**Check Prometheus logs:**
```bash
kubectl logs -n monitoring deployment/prometheus-server | grep "remote_write"
```

**Common errors:**

1. **Authentication Failed (401):**
   ```bash
   # Verify license key
   kubectl get secret newrelic-license-key -n monitoring -o jsonpath='{.data.license-key}' | base64 -d
   ```

2. **Network Timeout:**
   ```bash
   # Test connectivity from Prometheus pod
   kubectl exec -n monitoring deployment/prometheus-server -- \
     curl -v https://metric-api.newrelic.com/prometheus/v1/write
   ```

3. **Invalid Metrics Format:**
   - Check write_relabel_configs in Prometheus config
   - Verify metric names don't have invalid characters

### Update New Relic Secret

```bash
kubectl delete secret newrelic-license-key -n monitoring
kubectl create secret generic newrelic-license-key \
  -n monitoring \
  --from-literal=license-key=NEW_LICENSE_KEY
kubectl rollout restart deployment/prometheus-server -n monitoring
```

## Dashboard Issues

### Grafana Shows "No Data"

**This is normal for some dashboards!**

1. **Immediate data**: Node Exporter Full
2. **1-2 minutes**: Kube State Metrics, Kubernetes Nodes
3. **3-5 minutes**: Istio (after traffic generation)
4. **5-10 minutes**: ArgoCD (after apps sync)

**Troubleshooting steps:**

1. **Verify Prometheus targets are UP:**
   ```bash
   kubectl port-forward -n monitoring svc/prometheus-server 9090:9090
   # Open: http://localhost:9090/targets
   ```

2. **Test query in Prometheus:**
   ```
   # Try a simple query
   up

   # Try component-specific queries
   node_cpu_seconds_total
   kube_pod_info
   istio_requests_total
   ```

3. **Check Grafana datasource:**
   - Go to Configuration → Data Sources
   - Test the Prometheus connection
   - Verify URL: `http://prometheus-server.monitoring.svc.cluster.local:9090`

### Reset Grafana Admin Password

```bash
kubectl exec -n monitoring deployment/grafana -- \
  grafana-cli admin reset-admin-password <newpassword>
```

### Dashboards Not Loading

**Check Grafana logs:**
```bash
kubectl logs -n monitoring deployment/grafana
```

**Verify dashboards were downloaded:**
```bash
kubectl exec -n monitoring deployment/grafana -- \
  ls -la /etc/grafana/provisioning/dashboards/
```

**Reimport dashboards:**
```bash
kubectl delete pod -n monitoring -l app=grafana
```

## Component-Specific Issues

### ArgoCD

**Get admin password:**
```bash
kubectl -n monitoring get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

**Check ArgoCD status:**
```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=argocd-server
kubectl logs -n monitoring deployment/argocd-server
```

**Access ArgoCD UI:**
```bash
kubectl port-forward svc/argocd-server -n monitoring 8080:443
# https://localhost:8080
```

### cert-manager

**Check certificate status:**
```bash
kubectl get certificates -A
kubectl describe certificate demo-certificate-monitoring -n monitoring
```

**Check cert-manager logs:**
```bash
kubectl logs -n monitoring deployment/cert-manager -f
```

**Force certificate renewal:**
```bash
kubectl delete secret demo-tls-secret -n monitoring
```

### External Secrets Operator

**Check ExternalSecret status:**
```bash
kubectl get externalsecrets -A
kubectl describe externalsecret demo-external-secret -n monitoring
```

**Check ESO logs:**
```bash
kubectl logs -n monitoring deployment/external-secrets -f
```

**Verify secret was created:**
```bash
kubectl get secret demo-secret-from-external -n monitoring
```

### Istio

**Check Istio control plane:**
```bash
kubectl get pods -n istio-system
kubectl logs -n istio-system deployment/istiod
```

**Verify sidecar injection:**
```bash
# Check namespace has injection label
kubectl get namespace demo-apps -o jsonpath='{.metadata.labels.istio-injection}'
# Should output: enabled

# Verify pods have sidecars
kubectl get pods -n demo-apps -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
# Should show both app container and istio-proxy
```

**Restart pods to inject sidecar:**
```bash
kubectl rollout restart deployment -n demo-apps
```

**Check Istio ingress gateway:**
```bash
kubectl get svc -n istio-system istio-ingressgateway
kubectl describe svc -n istio-system istio-ingressgateway
```

## General Debugging Tips

### Get All Events

```bash
kubectl get events -n monitoring --sort-by='.lastTimestamp'
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

### Check Resource Usage

```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -n monitoring
kubectl top pods -n istio-system
```

### Restart Components

```bash
# Restart specific deployment
kubectl rollout restart deployment <name> -n monitoring

# Restart all deployments in namespace
kubectl rollout restart deployment -n monitoring
```

### Check Network Policies

```bash
kubectl get networkpolicies -A
kubectl describe networkpolicy -n monitoring
```

### Exec into Pod

```bash
# Get shell access
kubectl exec -it -n monitoring deployment/prometheus-server -- /bin/sh

# Run specific command
kubectl exec -n monitoring deployment/prometheus-server -- wget -qO- http://node-exporter:9100/metrics
```

## Getting Help

If issues persist:

1. **Collect diagnostics:**
   ```bash
   kubectl get all -n monitoring
   kubectl get events -n monitoring --sort-by='.lastTimestamp'
   kubectl logs -n monitoring deployment/<component>
   ```

2. **Check documentation:**
   - [Deployment Guide](deployment-guide.md)
   - [Configuration Guide](configuration-guide.md)
   - [K3D Quick Start](../K3D-QUICKSTART.md)

3. **Open an issue** with:
   - Component versions
   - Error logs
   - Deployment method (cloud/k3d)
   - Steps to reproduce
