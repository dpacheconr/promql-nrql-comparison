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
TIMEOUT=600

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

    if ! command -v helm &> /dev/null; then
        log_error "helm is not installed"
        echo ""
        echo "Please install Helm: https://helm.sh/docs/intro/install/"
        exit 1
    fi
    log_success "helm found"

    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    log_success "Connected to Kubernetes cluster"
}

# Add Helm repositories
add_helm_repos() {
    log_info "Adding Helm repositories..."

    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
    helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
    helm repo add external-secrets https://charts.external-secrets.io 2>/dev/null || true
    helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
    helm repo add istio https://istio-release.storage.googleapis.com/charts 2>/dev/null || true

    log_info "Updating Helm repositories..."
    helm repo update

    log_success "Helm repositories ready"
}

# Create namespaces
create_namespaces() {
    log_info "Creating namespaces..."

    kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - &> /dev/null
    kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f - &> /dev/null
    kubectl create namespace demo-apps --dry-run=client -o yaml | kubectl apply -f - &> /dev/null

    log_success "Namespaces created"
}

# Install kube-state-metrics
install_kube_state_metrics() {
    log_info "Installing kube-state-metrics..."

    helm upgrade --install kube-state-metrics \
        prometheus-community/kube-state-metrics \
        --namespace ${NAMESPACE} \
        --values helm-values/kube-state-metrics-values.yaml \
        --wait \
        --timeout ${TIMEOUT}s

    log_success "kube-state-metrics installed"
}

# Install cert-manager
install_cert_manager() {
    log_info "Installing cert-manager..."

    helm upgrade --install cert-manager \
        jetstack/cert-manager \
        --namespace ${NAMESPACE} \
        --values helm-values/cert-manager-values.yaml \
        --wait \
        --timeout ${TIMEOUT}s

    log_success "cert-manager installed"

    # Wait a bit for webhook to be ready
    log_info "Waiting for cert-manager webhook to be ready..."
    sleep 10
}

# Install External Secrets Operator
install_external_secrets() {
    log_info "Installing External Secrets Operator..."

    helm upgrade --install external-secrets \
        external-secrets/external-secrets \
        --namespace ${NAMESPACE} \
        --values helm-values/external-secrets-values.yaml \
        --wait \
        --timeout ${TIMEOUT}s

    log_success "External Secrets Operator installed"
}

# Install ArgoCD
install_argocd() {
    log_info "Installing ArgoCD..."

    helm upgrade --install argocd \
        argo/argo-cd \
        --namespace ${NAMESPACE} \
        --values helm-values/argocd-values.yaml \
        --wait \
        --timeout ${TIMEOUT}s

    log_success "ArgoCD installed"

    # Get initial admin password
    log_info "Retrieving ArgoCD admin password..."
    echo ""
    log_warning "ArgoCD admin password (save this):"
    kubectl -n ${NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "Password not yet available"
    echo ""
}

# Install Istio
install_istio() {
    log_info "Installing Istio base (CRDs)..."

    helm upgrade --install istio-base \
        istio/base \
        --namespace istio-system \
        --values helm-values/istio-base-values.yaml \
        --wait \
        --timeout ${TIMEOUT}s

    log_success "Istio base installed"

    log_info "Installing Istio control plane (istiod)..."

    helm upgrade --install istiod \
        istio/istiod \
        --namespace istio-system \
        --values helm-values/istio-istiod-values.yaml \
        --wait \
        --timeout ${TIMEOUT}s

    log_success "Istiod installed"

    log_info "Installing Istio ingress gateway..."

    helm upgrade --install istio-ingressgateway \
        istio/gateway \
        --namespace istio-system \
        --values helm-values/istio-gateway-values.yaml \
        --wait \
        --timeout ${TIMEOUT}s

    log_success "Istio ingress gateway installed"
}

# Deploy sample applications
deploy_sample_apps() {
    log_info "Deploying sample applications and resources..."

    # Create demo-apps namespace with Istio injection
    kubectl apply -f manifests/sample-apps/demo-namespace.yaml

    # Deploy sample certificates (after cert-manager is ready)
    kubectl apply -f manifests/sample-apps/sample-certificate.yaml

    # Deploy sample External Secrets (after ESO is ready)
    kubectl apply -f manifests/sample-apps/sample-externalsecret.yaml

    # Deploy sample apps with Istio sidecar
    kubectl apply -f manifests/sample-apps/sample-app-with-istio.yaml

    # Deploy sample ArgoCD applications
    kubectl apply -f manifests/sample-apps/sample-argocd-app.yaml

    log_success "Sample applications deployed"
}

# Display component status
display_status() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}        Helm Components Deployment Complete                ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    log_info "Checking component status..."
    echo ""

    # Check kube-state-metrics
    if kubectl get deployment kube-state-metrics -n ${NAMESPACE} &> /dev/null; then
        echo -e "${GREEN}✓${NC} kube-state-metrics: Installed"
    else
        echo -e "${RED}✗${NC} kube-state-metrics: Not found"
    fi

    # Check cert-manager
    if kubectl get deployment cert-manager -n ${NAMESPACE} &> /dev/null; then
        echo -e "${GREEN}✓${NC} cert-manager: Installed"
    else
        echo -e "${RED}✗${NC} cert-manager: Not found"
    fi

    # Check external-secrets
    if kubectl get deployment external-secrets -n ${NAMESPACE} &> /dev/null; then
        echo -e "${GREEN}✓${NC} external-secrets: Installed"
    else
        echo -e "${RED}✗${NC} external-secrets: Not found"
    fi

    # Check ArgoCD
    if kubectl get deployment argocd-server -n ${NAMESPACE} &> /dev/null; then
        echo -e "${GREEN}✓${NC} ArgoCD: Installed"
    else
        echo -e "${RED}✗${NC} ArgoCD: Not found"
    fi

    # Check Istio
    if kubectl get deployment istiod -n istio-system &> /dev/null; then
        echo -e "${GREEN}✓${NC} Istio: Installed"
    else
        echo -e "${RED}✗${NC} Istio: Not found"
    fi

    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "  1. Run the main deploy.sh to deploy Prometheus, Grafana, and Node Exporter"
    echo "  2. Run './port-forward.sh' to access services"
    echo "  3. Access Grafana at http://localhost:3000 (admin/admin)"
    echo "  4. All 11 dashboards should now show data!"
    echo ""

    echo -e "${BLUE}ArgoCD Access:${NC}"
    echo "  • Port-forward: kubectl port-forward svc/argocd-server -n ${NAMESPACE} 8080:443"
    echo "  • URL: https://localhost:8080"
    echo "  • Username: admin"
    echo "  • Password: (see above or run: kubectl -n ${NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d)"
    echo ""

    echo -e "${BLUE}To view all components:${NC}"
    echo "  kubectl get all -n ${NAMESPACE}"
    echo "  kubectl get all -n istio-system"
    echo "  kubectl get all -n demo-apps"
    echo ""
}

# Main execution
main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}   Helm Components Deployment (Kubernetes Monitoring)     ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    check_prerequisites
    add_helm_repos
    create_namespaces

    log_info "Starting component installations (this may take 10-15 minutes)..."
    echo ""

    install_kube_state_metrics
    install_cert_manager
    install_external_secrets
    install_argocd
    install_istio
    deploy_sample_apps

    display_status

    log_success "All Helm components deployed successfully!"
}

main
