#!/bin/bash

# Port forwarding script for local/development environments
# 
# NOTE: For GKE/cloud deployments, services are exposed via LoadBalancer.
# This script is only needed for local clusters (k3d, minikube, etc.)
# where LoadBalancer IPs are not available.
#
# For LoadBalancer access, run: kubectl get svc -n monitoring

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="monitoring"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi

    # Check if namespace exists
    if ! kubectl get namespace ${NAMESPACE} &> /dev/null; then
        log_error "Namespace '${NAMESPACE}' does not exist"
        log_info "Please run './deploy.sh' first"
        exit 1
    fi
}

# Check if services are ready
check_services() {
    log_info "Checking if services are ready..."

    # Check if services have LoadBalancer external IPs
    GRAFANA_EXTERNAL_IP=$(kubectl get svc grafana -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    PROM_EXTERNAL_IP=$(kubectl get svc prometheus-server -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

    if [ ! -z "$GRAFANA_EXTERNAL_IP" ] || [ ! -z "$PROM_EXTERNAL_IP" ]; then
        echo ""
        echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║${NC}              Services Exposed via LoadBalancer            ${YELLOW}║${NC}"
        echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}Your services are accessible via external IPs:${NC}"
        [ ! -z "$GRAFANA_EXTERNAL_IP" ] && echo -e "  • Grafana:     http://${GRAFANA_EXTERNAL_IP}:3000"
        [ ! -z "$PROM_EXTERNAL_IP" ] && echo -e "  • Prometheus:  http://${PROM_EXTERNAL_IP}:9090"
        echo ""
        echo -e "${YELLOW}Port forwarding is not necessary for cloud deployments.${NC}"
        echo -e "${YELLOW}Do you want to continue anyway? (yes/no)${NC}"
        read -r response
        if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            log_info "Exiting..."
            exit 0
        fi
    fi

    # Check Prometheus
    if ! kubectl get deployment prometheus-server -n ${NAMESPACE} &> /dev/null; then
        log_error "Prometheus deployment not found"
        exit 1
    fi

    # Check Grafana
    if ! kubectl get deployment grafana -n ${NAMESPACE} &> /dev/null; then
        log_error "Grafana deployment not found"
        exit 1
    fi

    log_success "Services are ready"
}

# Display access information
display_access_info() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}              Port Forwarding - Access Information         ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Services are now accessible at:${NC}"
    echo ""
    echo -e "  ${BLUE}Prometheus:${NC}  http://localhost:9090"
    echo -e "  ${BLUE}Grafana:${NC}     http://localhost:3000"
    echo ""
    echo -e "${YELLOW}Press Ctrl+C to stop port forwarding${NC}"
    echo ""
}

# Setup cleanup on exit
cleanup() {
    echo ""
    log_info "Stopping port forwarding..."
    kill $PROM_PID $GRAFANA_PID 2>/dev/null || true
    exit 0
}

trap cleanup SIGINT SIGTERM

# Main execution
main() {
    check_prerequisites
    check_services
    display_access_info

    # Start port forwarding for both services
    log_info "Starting port forwarding..."

    # Start port forwarding in background
    kubectl port-forward -n ${NAMESPACE} svc/prometheus-server 9090:9090 &
    PROM_PID=$!

    kubectl port-forward -n ${NAMESPACE} svc/grafana 3000:3000 &
    GRAFANA_PID=$!

    log_success "Prometheus port forwarding started (PID: $PROM_PID)"
    log_success "Grafana port forwarding started (PID: $GRAFANA_PID)"

    # Give kubectl a moment to establish the connection
    sleep 2

    # Verify connections are working
    if curl -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
        log_success "Prometheus is accessible at http://localhost:9090"
    else
        log_warning "Could not verify Prometheus connection, but port forwarding is running"
    fi

    if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
        log_success "Grafana is accessible at http://localhost:3000"
    else
        log_warning "Could not verify Grafana connection, but port forwarding is running"
    fi

    echo ""
    log_info "Keeping port forwarding active. Press Ctrl+C to stop."
    echo ""

    # Wait for both processes to keep them running
    wait $PROM_PID $GRAFANA_PID
}

main
