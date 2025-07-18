#!/bin/bash

# Blindtest Reforged V2 Infrastructure Deployment Script
# This script deploys the complete Kubernetes infrastructure

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

# Function to print status
print_status() {
    echo -e "${GREEN}✅${NC} $1"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

# Function to print error
print_error() {
    echo -e "${RED}❌${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi
    print_status "kubectl is available"
    
    # Check if minikube is installed
    if ! command -v minikube &> /dev/null; then
        print_error "minikube is not installed"
        exit 1
    fi
    print_status "minikube is available"
    
    # Check if minikube is running
    if ! minikube status | grep -q "Running"; then
        print_warning "minikube is not running, starting it..."
        minikube start
        if [ $? -ne 0 ]; then
            print_error "Failed to start minikube"
            exit 1
        fi
    fi
    print_status "minikube is running"
    
    # Enable required addons
    print_header "Enabling Minikube Addons"
    minikube addons enable ingress
    minikube addons enable metrics-server
    print_status "Required addons enabled"
}

# Deploy infrastructure
deploy_infrastructure() {
    print_header "Deploying Infrastructure"
    
    # Apply all Kubernetes resources
    echo "Applying Kubernetes manifests..."
    kubectl apply -k .
    
    if [ $? -eq 0 ]; then
        print_status "Infrastructure deployed successfully"
    else
        print_error "Failed to deploy infrastructure"
        exit 1
    fi
}

# Wait for deployments to be ready
wait_for_ready() {
    print_header "Waiting for Deployments to be Ready"
    
    local deployments=("mongodb-deployment" "backend-deployment" "game-frontend-deployment" "admin-frontend-deployment" "mongo-express-deployment")
    
    for deployment in "${deployments[@]}"; do
        echo "Waiting for $deployment to be ready..."
        kubectl wait --for=condition=available --timeout=300s deployment/$deployment -n blindtest
        
        if [ $? -eq 0 ]; then
            print_status "$deployment is ready"
        else
            print_warning "$deployment took longer than expected to be ready"
        fi
    done
}

# Show access information
show_access_info() {
    print_header "Access Information"
    
    local minikube_ip=$(minikube ip)
    
    echo -e "Minikube IP: ${BLUE}$minikube_ip${NC}"
    echo ""
    echo "Add the following to your /etc/hosts file (or C:\\Windows\\System32\\drivers\\etc\\hosts on Windows):"
    echo -e "${YELLOW}$minikube_ip blindtest.local${NC}"
    echo ""
    echo "Available endpoints:"
    echo -e "  • Game Frontend:    ${GREEN}http://blindtest.local/${NC}"
    echo -e "  • Admin Frontend:   ${GREEN}http://blindtest.local/admin${NC}"
    echo -e "  • Backend API:      ${GREEN}http://blindtest.local/api${NC}"
    echo -e "  • Database Admin:   ${GREEN}http://blindtest.local/database${NC} (admin/blindtest123)"
    echo ""
    echo "To test the infrastructure, run:"
    echo -e "  ${BLUE}./test-infrastructure.sh${NC} (Linux/macOS)"
    echo -e "  ${BLUE}.\\test-infrastructure.ps1${NC} (Windows PowerShell)"
}

# Main execution
main() {
    echo -e "${BLUE}"
    echo "🎵 Blindtest Reforged V2 Infrastructure Deployment"
    echo "=================================================="
    echo -e "${NC}"
    
    check_prerequisites
    deploy_infrastructure
    wait_for_ready
    show_access_info
    
    print_header "Deployment Complete"
    print_status "Infrastructure is ready!"
}

# Run the main function
main "$@"
