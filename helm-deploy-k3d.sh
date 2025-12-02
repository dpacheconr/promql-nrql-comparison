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
        echo ""
        echo "Did you run ./k3d-setup.sh first?"
        exit 1
    fi
    log_success "Connected to Kubernetes cluster"

    # Check if it's k3d
    if kubectl config current-context | grep -q "k3d"; then
        log_success "k3d cluster detected - using optimized settings"
    else
        log_warning "Not a k3d cluster - consider using helm-deploy.sh instead"
    fi
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

# Install kube-state-metrics (lightweight for k3d)
install_kube_state_metrics() {
    log_info "Installing kube-state-metrics (k3d optimized)..."

    helm upgrade --install kube-state-metrics \
        prometheus-community/kube-state-metrics \
        --namespace ${NAMESPACE} \
        --set resources.limits.cpu=50m \
        --set resources.limits.memory=64Mi \
        --set resources.requests.cpu=25m \
        --set resources.requests.memory=32Mi \
        --set-string podAnnotations."prometheus\.io/scrape"="true" \
        --set-string podAnnotations."prometheus\.io/port"="8080" \
        --wait \
        --timeout ${TIMEOUT}s

    log_success "kube-state-metrics installed"
}

# Install cert-manager (lightweight for k3d)
install_cert_manager() {
    log_info "Installing cert-manager (k3d optimized)..."

    helm upgrade --install cert-manager \
        jetstack/cert-manager \
        --namespace ${NAMESPACE} \
        --set installCRDs=true \
        --set resources.limits.cpu=50m \
        --set resources.limits.memory=64Mi \
        --set resources.requests.cpu=10m \
        --set resources.requests.memory=32Mi \
        --set webhook.resources.limits.cpu=50m \
        --set webhook.resources.limits.memory=64Mi \
        --set webhook.resources.requests.cpu=10m \
        --set webhook.resources.requests.memory=32Mi \
        --set cainjector.resources.limits.cpu=50m \
        --set cainjector.resources.limits.memory=64Mi \
        --set cainjector.resources.requests.cpu=10m \
        --set cainjector.resources.requests.memory=32Mi \
        --set prometheus.enabled=true \
        --wait \
        --timeout ${TIMEOUT}s

    log_success "cert-manager installed"

    # Wait for webhook to be ready
    log_info "Waiting for cert-manager webhook to be ready..."
    sleep 10
}

# Install External Secrets Operator (lightweight for k3d)
install_external_secrets() {
    log_info "Installing External Secrets Operator (k3d optimized)..."

    helm upgrade --install external-secrets \
        external-secrets/external-secrets \
        --namespace ${NAMESPACE} \
        --set installCRDs=true \
        --set resources.limits.cpu=50m \
        --set resources.limits.memory=64Mi \
        --set resources.requests.cpu=25m \
        --set resources.requests.memory=32Mi \
        --set webhook.resources.limits.cpu=50m \
        --set webhook.resources.limits.memory=64Mi \
        --set certController.resources.limits.cpu=50m \
        --set certController.resources.limits.memory=64Mi \
        --wait \
        --timeout ${TIMEOUT}s

    log_success "External Secrets Operator installed"
}

# Install ArgoCD (lightweight for k3d)
install_argocd() {
    log_info "Installing ArgoCD (k3d optimized)..."

    helm upgrade --install argocd \
        argo/argo-cd \
        --namespace ${NAMESPACE} \
        --set controller.resources.limits.cpu=250m \
        --set controller.resources.limits.memory=256Mi \
        --set controller.resources.requests.cpu=100m \
        --set controller.resources.requests.memory=128Mi \
        --set server.resources.limits.cpu=200m \
        --set server.resources.limits.memory=128Mi \
        --set server.resources.requests.cpu=50m \
        --set server.resources.requests.memory=64Mi \
        --set repoServer.resources.limits.cpu=200m \
        --set repoServer.resources.limits.memory=128Mi \
        --set repoServer.resources.requests.cpu=50m \
        --set repoServer.resources.requests.memory=64Mi \
        --set redis.resources.limits.cpu=100m \
        --set redis.resources.limits.memory=64Mi \
        --set redis.image.repository=redis \
        --set redis.image.tag=7.2-alpine \
        --set dex.enabled=false \
        --set notifications.enabled=false \
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

# Install Istio (minimal for k3d)
install_istio() {
    log_info "Installing Istio base (CRDs)..."

    helm upgrade --install istio-base \
        istio/base \
        --namespace istio-system \
        --wait \
        --timeout ${TIMEOUT}s

    log_success "Istio base installed"

    log_info "Installing Istio control plane (k3d optimized)..."

    helm upgrade --install istiod \
        istio/istiod \
        --namespace istio-system \
        --set pilot.resources.limits.cpu=200m \
        --set pilot.resources.limits.memory=256Mi \
        --set pilot.resources.requests.cpu=100m \
        --set pilot.resources.requests.memory=128Mi \
        --set global.proxy.resources.limits.cpu=100m \
        --set global.proxy.resources.limits.memory=128Mi \
        --set global.proxy.resources.requests.cpu=50m \
        --set global.proxy.resources.requests.memory=64Mi \
        --wait \
        --timeout ${TIMEOUT}s

    log_success "Istiod installed"

    log_info "Installing Istio ingress gateway (k3d optimized)..."

    helm upgrade --install istio-ingressgateway \
        istio/gateway \
        --namespace istio-system \
        --set resources.limits.cpu=200m \
        --set resources.limits.memory=128Mi \
        --set resources.requests.cpu=50m \
        --set resources.requests.memory=64Mi \
        --set service.type=NodePort \
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

    # Note: Skipping External Secrets with fake provider due to compatibility issues with v1.1.0
    # The fake provider is not recommended for production anyway - use AWS Secrets Manager, Vault, etc.
    # For a working demo, see: manifests/sample-apps/sample-externalsecret-kubernetes.yaml
    log_warning "Skipping External Secrets samples (fake provider has issues in v1.1.0)"

    # Deploy sample apps with Istio sidecar (reduced replicas for k3d)
    cat manifests/sample-apps/sample-app-with-istio.yaml | \
        sed 's/replicas: 2/replicas: 1/g' | \
        kubectl apply -f -

    # Deploy sample ArgoCD applications
    kubectl apply -f manifests/sample-apps/sample-argocd-app.yaml

    log_success "Sample applications deployed"
}

# Display component status
display_status() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}        k3d Deployment Complete                            ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    log_info "Checking component status..."
    echo ""

    # Check components
    for component in kube-state-metrics cert-manager external-secrets argocd-server; do
        if kubectl get deployment $component -n ${NAMESPACE} &> /dev/null; then
            echo -e "${GREEN}✓${NC} $component: Installed"
        else
            echo -e "${YELLOW}○${NC} $component: Not found (may be different name)"
        fi
    done

    if kubectl get deployment istiod -n istio-system &> /dev/null; then
        echo -e "${GREEN}✓${NC} Istio: Installed"
    else
        echo -e "${RED}✗${NC} Istio: Not found"
    fi

    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "  1. Ensure base stack is deployed: ./deploy.sh"
    echo "  2. Wait for all pods to be ready (may take 2-5 minutes on k3d)"
    echo "  3. Run './port-forward.sh' to access services"
    echo "  4. Open Grafana: http://localhost:3000 (admin/admin)"
    echo ""

    echo -e "${BLUE}Check pod status:${NC}"
    echo "  kubectl get pods -n ${NAMESPACE}"
    echo "  kubectl get pods -n istio-system"
    echo "  kubectl get pods -n demo-apps"
    echo ""

    echo -e "${BLUE}ArgoCD Access:${NC}"
    echo "  • Port-forward: kubectl port-forward svc/argocd-server -n ${NAMESPACE} 8080:443"
    echo "  • URL: https://localhost:8080"
    echo "  • Username: admin"
    echo "  • Password: (see above)"
    echo ""

    echo -e "${YELLOW}Note: k3d uses fewer resources. Components may start slowly.${NC}"
    echo -e "${YELLOW}If pods are pending, check: kubectl get events -n ${NAMESPACE}${NC}"
    echo ""
}

# Main execution
main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}   k3d Optimized Helm Components Deployment               ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    check_prerequisites
    add_helm_repos
    create_namespaces

    log_info "Starting component installations (optimized for k3d)..."
    log_warning "This may take 10-15 minutes on k3d..."
    echo ""

    install_kube_state_metrics
    install_cert_manager
    install_external_secrets
    install_argocd
    install_istio
    deploy_sample_apps

    display_status

    log_success "All k3d components deployed successfully!"
}

main
