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
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
}

# Confirm deletion
confirm_deletion() {
    echo ""
    echo -e "${YELLOW}This will delete the entire '${NAMESPACE}' namespace and all resources within it.${NC}"
    echo ""
    read -p "Are you sure? (yes/no): " confirmation

    if [[ "$confirmation" != "yes" ]]; then
        log_info "Cleanup cancelled"
        exit 0
    fi
}

# Delete namespace and all resources
delete_resources() {
    log_info "Deleting namespace '${NAMESPACE}' and all resources..."

    if kubectl delete namespace ${NAMESPACE} --wait=true; then
        log_success "Namespace deleted successfully"
    else
        log_error "Failed to delete namespace"
        return 1
    fi
}

# Main execution
main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}                    Cleanup Resources                      ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    check_prerequisites
    confirm_deletion
    delete_resources

    echo ""
    log_success "Cleanup completed successfully!"
    echo ""
}

main
