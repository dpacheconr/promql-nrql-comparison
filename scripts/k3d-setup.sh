#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="monitoring-demo"
AGENTS=2  # Worker nodes

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

    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        echo "Please install Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    log_success "Docker found"

    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    log_success "Docker daemon running"

    if ! command -v k3d &> /dev/null; then
        log_error "k3d is not installed"
        echo ""
        echo "Install k3d:"
        echo "  macOS:   brew install k3d"
        echo "  Linux:   curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash"
        echo "  Windows: choco install k3d"
        echo ""
        echo "Or visit: https://k3d.io/#installation"
        exit 1
    fi
    log_success "k3d found"

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
    log_success "kubectl found"

    if ! command -v helm &> /dev/null; then
        log_warning "Helm is not installed - you'll need it for helm-deploy.sh"
        echo "Install Helm: https://helm.sh/docs/intro/install/"
    else
        log_success "helm found"
    fi
}

# Create registry configuration
create_registry_config() {
    local config_file="k3d-registries.yaml"

    if [ -f "$config_file" ]; then
        log_info "Registry configuration already exists"
        return 0
    fi

    log_info "Creating registry configuration..."

    cat > "$config_file" <<'EOF'
mirrors:
  "docker.io":
    endpoint:
      - https://registry-1.docker.io
  "quay.io":
    endpoint:
      - https://quay.io
  "gcr.io":
    endpoint:
      - https://gcr.io
  "ghcr.io":
    endpoint:
      - https://ghcr.io

configs:
  "quay.io":
    tls:
      insecure_skip_verify: true
  "docker.io":
    tls:
      insecure_skip_verify: true
  "gcr.io":
    tls:
      insecure_skip_verify: true
  "ghcr.io":
    tls:
      insecure_skip_verify: true
EOF

    log_success "Registry configuration created"
}

# Create k3d cluster
create_cluster() {
    log_info "Checking if cluster '${CLUSTER_NAME}' already exists..."

    if k3d cluster list | grep -q "^${CLUSTER_NAME}"; then
        log_warning "Cluster '${CLUSTER_NAME}' already exists"
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deleting existing cluster..."
            k3d cluster delete ${CLUSTER_NAME}
        else
            log_info "Using existing cluster"
            kubectl config use-context k3d-${CLUSTER_NAME}
            return 0
        fi
    fi

    log_info "Creating k3d cluster '${CLUSTER_NAME}' with ${AGENTS} worker nodes..."

    # Create cluster with:
    # - 1 server (control plane)
    # - N agents (worker nodes)
    # - Port mappings for Grafana and Prometheus
    # - Registry configuration to handle TLS properly
    k3d cluster create ${CLUSTER_NAME} \
        --agents ${AGENTS} \
        --port "3000:30000@server:0" \
        --port "9090:30090@server:0" \
        --port "8080:30080@server:0" \
        --api-port 6550 \
        --registry-config "$(pwd)/k3d-registries.yaml" \
        --wait

    log_success "k3d cluster created"

    # Set context
    kubectl config use-context k3d-${CLUSTER_NAME}
    log_success "kubectl context set to k3d-${CLUSTER_NAME}"
}

# Display cluster info
display_cluster_info() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}          k3d Cluster Ready                                ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    log_info "Cluster information:"
    echo ""
    kubectl cluster-info
    echo ""

    log_info "Nodes:"
    kubectl get nodes
    echo ""

    echo -e "${BLUE}Next steps:${NC}"
    echo ""
    echo "  1. Create New Relic secret:"
    echo "     ${YELLOW}kubectl create namespace monitoring${NC}"
    echo "     ${YELLOW}kubectl create secret generic newrelic-license-key \\${NC}"
    echo "     ${YELLOW}  -n monitoring \\${NC}"
    echo "     ${YELLOW}  --from-literal=license-key=YOUR_LICENSE_KEY${NC}"
    echo ""
    echo "  2. Deploy base stack:"
    echo "     ${YELLOW}./deploy.sh${NC}"
    echo ""
    echo "  3. Deploy additional components (Helm):"
    echo "     ${YELLOW}./helm-deploy.sh${NC}"
    echo ""
    echo "  4. Access services:"
    echo "     ${YELLOW}./port-forward.sh${NC}"
    echo "     • Grafana:    http://localhost:3000 (admin/admin)"
    echo "     • Prometheus: http://localhost:9090"
    echo ""
    echo -e "${BLUE}Tips for k3d:${NC}"
    echo "  • Cluster name: ${CLUSTER_NAME}"
    echo "  • View logs:    k3d cluster list"
    echo "  • Stop cluster: k3d cluster stop ${CLUSTER_NAME}"
    echo "  • Start cluster: k3d cluster start ${CLUSTER_NAME}"
    echo "  • Delete cluster: k3d cluster delete ${CLUSTER_NAME}"
    echo ""
    echo -e "${YELLOW}Note: k3d uses fewer resources than full clusters.${NC}"
    echo -e "${YELLOW}Some components may take longer to start.${NC}"
    echo ""
}

# Main execution
main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}   k3d Cluster Setup for Monitoring Demo                  ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    check_prerequisites
    create_registry_config
    create_cluster
    display_cluster_info

    log_success "k3d cluster setup complete!"
}

main
