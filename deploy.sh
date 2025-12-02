#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="monitoring"
TIMEOUT=300

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
    log_success "kubectl found"

    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    log_success "Connected to Kubernetes cluster"
}

# Check if secret exists
check_newrelic_secret() {
    log_info "Checking for New Relic license key secret..."

    # Ensure namespace exists first
    kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - &> /dev/null

    if kubectl get secret newrelic-license-key -n ${NAMESPACE} &> /dev/null; then
        log_success "New Relic secret found"
        return 0
    else
        log_error "New Relic license key secret not found in ${NAMESPACE} namespace"
        echo ""
        echo -e "${YELLOW}To create the secret, run:${NC}"
        echo "  kubectl create secret generic newrelic-license-key \\"
        echo "    -n ${NAMESPACE} \\"
        echo "    --from-literal=license-key=YOUR_NEW_RELIC_LICENSE_KEY"
        echo ""
        echo "Your New Relic license key can be found at:"
        echo "  https://one.newrelic.com → Settings → API Keys → Ingest - License"
        echo ""
        return 1
    fi
}

# Deploy manifests
deploy_manifests() {
    log_info "Deploying Kubernetes manifests..."

    # Apply manifests in order
    log_info "Applying namespace..."
    kubectl apply -f manifests/namespace.yaml

    log_info "Applying Prometheus RBAC..."
    kubectl apply -f manifests/prometheus/rbac.yaml

    log_info "Applying Prometheus configuration..."
    kubectl apply -f manifests/prometheus/configmap.yaml

    log_info "Applying Prometheus deployment..."
    kubectl apply -f manifests/prometheus/deployment.yaml
    kubectl apply -f manifests/prometheus/service.yaml

    log_info "Applying Node Exporter..."
    kubectl apply -f manifests/node-exporter/daemonset.yaml
    kubectl apply -f manifests/node-exporter/service.yaml

    log_info "Applying Grafana datasource configuration..."
    kubectl apply -f manifests/grafana/configmap-datasource.yaml

    log_info "Applying Grafana dashboard configuration..."
    kubectl apply -f manifests/grafana/configmap-dashboard.yaml

    log_info "Applying Grafana deployment..."
    kubectl apply -f manifests/grafana/deployment.yaml
    kubectl apply -f manifests/grafana/service.yaml

    log_success "All manifests applied"
}

# Wait for deployments to be ready
wait_for_deployments() {
    log_info "Waiting for deployments to be ready (timeout: ${TIMEOUT}s)..."

    # Wait for Prometheus
    log_info "Waiting for Prometheus..."
    kubectl wait --for=condition=available --timeout=${TIMEOUT}s \
        deployment/prometheus-server -n ${NAMESPACE} || {
        log_error "Prometheus deployment failed to become ready"
        return 1
    }

    # Wait for Grafana
    log_info "Waiting for Grafana..."
    kubectl wait --for=condition=available --timeout=${TIMEOUT}s \
        deployment/grafana -n ${NAMESPACE} || {
        log_error "Grafana deployment failed to become ready"
        return 1
    }

    log_success "All deployments are ready"
}

# Display access information
display_access_info() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}          Deployment Complete - Access Information         ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Services are exposed via LoadBalancer (public IPs):${NC}"
    echo ""
    echo -e "${BLUE}To get the external IPs, run:${NC}"
    echo "  kubectl get svc -n ${NAMESPACE}"
    echo ""
    echo -e "${BLUE}Or wait for IPs to be assigned:${NC}"
    echo "  kubectl get svc grafana -n ${NAMESPACE} -w"
    echo "  kubectl get svc prometheus-server -n ${NAMESPACE} -w"
    echo ""
    echo -e "${BLUE}Once IPs are assigned, access:${NC}"
    echo "  • Grafana:     http://<GRAFANA_EXTERNAL_IP>:3000 (admin / admin)"
    echo "  • Prometheus:  http://<PROMETHEUS_EXTERNAL_IP>:9090"
    echo ""
    echo -e "${BLUE}Pre-installed Grafana Dashboards:${NC}"
    echo "  Navigate to Dashboards → Browse to view 11 dashboards:"
    echo "  • Node Exporter, ArgoCD, Istio, Cert Manager, K8s, External Secrets, and more"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}IMPORTANT: To generate data for ALL dashboards, run:${NC}"
    echo -e "${YELLOW}  ./helm-deploy.sh${NC}"
    echo -e "${YELLOW}This will install:${NC}"
    echo "  • kube-state-metrics (for Kubernetes state metrics)"
    echo "  • cert-manager (for certificate management)"
    echo "  • External Secrets Operator (for secrets management)"
    echo "  • ArgoCD (for GitOps)"
    echo "  • Istio (for service mesh)"
    echo "  • Sample applications to generate metrics"
    echo ""
    echo -e "${YELLOW}Without these components, most dashboards will be empty!${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}To verify remote write to New Relic:${NC}"
    echo "  • Open Prometheus: http://localhost:9090/api/v1/query?query=up"
    echo "  • Check Status → Remote Write"
    echo ""
    echo -e "${BLUE}To view logs:${NC}"
    echo "  kubectl logs -n ${NAMESPACE} deployment/prometheus-server"
    echo "  kubectl logs -n ${NAMESPACE} deployment/grafana"
    echo ""
    echo -e "${YELLOW}Note: It may take a few minutes for metrics to appear in New Relic.${NC}"
    echo ""
}

# Main execution
main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}   Prometheus + Node Exporter + Grafana Deployment       ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    check_prerequisites
    check_newrelic_secret || exit 1
    deploy_manifests
    wait_for_deployments
    display_access_info

    log_success "Deployment completed successfully!"
}

main
