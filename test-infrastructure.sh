#!/bin/bash

# Blindtest Reforged V2 Infrastructure Test Script
# This script tests all Kubernetes components for the Blindtest application

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

# Function to print test results
print_test() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if [ $2 -eq 0 ]; then
        echo -e "${GREEN}✅ PASS${NC}: $1"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: $1"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        if [ ! -z "$3" ]; then
            echo -e "   ${YELLOW}Details:${NC} $3"
        fi
    fi
}

# Function to print info
print_info() {
    echo -e "${YELLOW}ℹ️  INFO${NC}: $1"
}

# Function to check if minikube is running
check_minikube() {
    print_header "Minikube Status"
    
    if ! command -v minikube &> /dev/null; then
        print_test "Minikube command available" 1 "minikube command not found"
        return 1
    fi
    
    local status=$(minikube status --format='{{.Host}}' 2>/dev/null)
    if [ "$status" == "Running" ]; then
        print_test "Minikube is running" 0
        print_info "Minikube IP: $(minikube ip 2>/dev/null)"
    else
        print_test "Minikube is running" 1 "Status: $status"
        return 1
    fi
}

# Function to check namespace
check_namespace() {
    print_header "Namespace Check"
    
    if kubectl get namespace blindtest &>/dev/null; then
        print_test "Namespace 'blindtest' exists" 0
    else
        print_test "Namespace 'blindtest' exists" 1
        return 1
    fi
}

# Function to check deployments
check_deployments() {
    print_header "Deployments Status"
    
    local deployments=("mongodb-deployment" "backend-deployment" "game-frontend-deployment" "admin-frontend-deployment" "mongo-express-deployment")
    
    for deployment in "${deployments[@]}"; do
        local ready=$(kubectl get deployment $deployment -n blindtest -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
        local desired=$(kubectl get deployment $deployment -n blindtest -o jsonpath='{.spec.replicas}' 2>/dev/null)
        
        if [ "$ready" == "$desired" ] && [ ! -z "$ready" ]; then
            print_test "Deployment $deployment is ready ($ready/$desired)" 0
        else
            print_test "Deployment $deployment is ready" 1 "Ready: $ready, Desired: $desired"
        fi
    done
}

# Function to check pods
check_pods() {
    print_header "Pods Status"
    
    local pods=$(kubectl get pods -n blindtest --no-headers 2>/dev/null)
    
    if [ -z "$pods" ]; then
        print_test "Pods exist in blindtest namespace" 1 "No pods found"
        return 1
    fi
    
    while IFS= read -r line; do
        local name=$(echo $line | awk '{print $1}')
        local ready=$(echo $line | awk '{print $2}')
        local status=$(echo $line | awk '{print $3}')
        local restarts=$(echo $line | awk '{print $4}')
        
        if [ "$status" == "Running" ] && [[ "$ready" =~ ^[0-9]+/[0-9]+$ ]]; then
            local ready_count=$(echo $ready | cut -d'/' -f1)
            local total_count=$(echo $ready | cut -d'/' -f2)
            
            if [ "$ready_count" == "$total_count" ]; then
                print_test "Pod $name is running and ready" 0
            else
                print_test "Pod $name is running and ready" 1 "Ready: $ready"
            fi
        else
            print_test "Pod $name is running and ready" 1 "Status: $status, Ready: $ready"
        fi
    done <<< "$pods"
}

# Function to check services
check_services() {
    print_header "Services Status"
    
    local services=("mongodb-service" "backend-service" "game-frontend-service" "admin-frontend-service" "mongo-express-service")
    
    for service in "${services[@]}"; do
        local cluster_ip=$(kubectl get service $service -n blindtest -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
        
        if [ ! -z "$cluster_ip" ] && [ "$cluster_ip" != "None" ]; then
            print_test "Service $service has ClusterIP assigned" 0
            print_info "  ClusterIP: $cluster_ip"
        else
            print_test "Service $service has ClusterIP assigned" 1
        fi
    done
}

# Function to check endpoints
check_endpoints() {
    print_header "Endpoints Status"
    
    local services=("mongodb-service" "backend-service" "game-frontend-service" "admin-frontend-service" "mongo-express-service")
    
    for service in "${services[@]}"; do
        local endpoints=$(kubectl get endpoints $service -n blindtest -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
        
        if [ ! -z "$endpoints" ]; then
            local endpoint_count=$(echo $endpoints | wc -w)
            print_test "Service $service has endpoints" 0
            print_info "  Endpoints: $endpoint_count ($endpoints)"
        else
            print_test "Service $service has endpoints" 1
        fi
    done
}

# Function to check ingress
check_ingress() {
    print_header "Ingress Status"
    
    local ingresses=("blindtest-ingress" "database-ingress")
    
    for ingress in "${ingresses[@]}"; do
        local address=$(kubectl get ingress $ingress -n blindtest -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        
        if [ ! -z "$address" ]; then
            print_test "Ingress $ingress has address assigned" 0
            print_info "  Address: $address"
        else
            print_test "Ingress $ingress has address assigned" 1
        fi
    done
}

# Function to check HTTP endpoints
check_http_endpoints() {
    print_header "HTTP Endpoints Test"
    
    local minikube_ip=$(minikube ip 2>/dev/null)
    if [ -z "$minikube_ip" ]; then
        print_test "HTTP endpoints reachable" 1 "Cannot get minikube IP"
        return 1
    fi
    
    # Test main routes
    local routes=("/" "/admin" "/api")
    
    for route in "${routes[@]}"; do
        local response=$(curl -s -o /dev/null -w "%{http_code}" "http://blindtest.local$route" --max-time 10 2>/dev/null)
        
        if [ "$response" == "200" ]; then
            print_test "Route $route returns HTTP 200" 0
        else
            print_test "Route $route returns HTTP 200" 1 "Got HTTP $response"
        fi
    done
    
    # Test database route (should require auth)
    local db_response=$(curl -s -o /dev/null -w "%{http_code}" "http://blindtest.local/database" --max-time 10 2>/dev/null)
    
    if [ "$db_response" == "401" ]; then
        print_test "Route /database requires authentication" 0
    else
        print_test "Route /database requires authentication" 1 "Got HTTP $db_response instead of 401"
    fi
    
    # Test database route with auth
    local db_auth_response=$(curl -s -o /dev/null -w "%{http_code}" -u "admin:blindtest123" "http://blindtest.local/database" --max-time 10 2>/dev/null)
    
    if [ "$db_auth_response" == "200" ]; then
        print_test "Route /database accessible with credentials" 0
    else
        print_test "Route /database accessible with credentials" 1 "Got HTTP $db_auth_response"
    fi
}

# Function to check persistent volumes
check_persistent_volumes() {
    print_header "Persistent Storage"
    
    local pvc_status=$(kubectl get pvc mongodb-pvc -n blindtest -o jsonpath='{.status.phase}' 2>/dev/null)
    
    if [ "$pvc_status" == "Bound" ]; then
        print_test "MongoDB PVC is bound" 0
        local storage_size=$(kubectl get pvc mongodb-pvc -n blindtest -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null)
        print_info "  Storage size: $storage_size"
    else
        print_test "MongoDB PVC is bound" 1 "Status: $pvc_status"
    fi
}

# Function to check MongoDB connectivity
check_mongodb() {
    print_header "MongoDB Connectivity"
    
    # Check if MongoDB pod is ready
    local mongo_pod=$(kubectl get pods -n blindtest -l app=mongodb --no-headers -o custom-columns=":metadata.name" 2>/dev/null | head -1)
    
    if [ ! -z "$mongo_pod" ]; then
        print_test "MongoDB pod exists" 0
        
        # Test MongoDB connection
        local mongo_test=$(kubectl exec -n blindtest $mongo_pod -- mongosh --quiet --eval "db.adminCommand('ping').ok" 2>/dev/null | tail -1)
        
        if [ "$mongo_test" == "1" ]; then
            print_test "MongoDB is responding to ping" 0
        else
            print_test "MongoDB is responding to ping" 1
        fi
    else
        print_test "MongoDB pod exists" 1
    fi
}

# Function to print summary
print_summary() {
    print_header "Test Summary"
    
    echo -e "Total tests: $TOTAL_TESTS"
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
    echo -e "${RED}Failed: $FAILED_TESTS${NC}"
    
    local success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo -e "Success rate: ${success_rate}%"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "\n${GREEN}🎉 All tests passed! Infrastructure is working correctly.${NC}"
        return 0
    else
        echo -e "\n${RED}⚠️  Some tests failed. Please check the infrastructure.${NC}"
        return 1
    fi
}

# Main execution
main() {
    echo -e "${BLUE}"
    echo "🎵 Blindtest Reforged V2 Infrastructure Test"
    echo "=============================================="
    echo -e "${NC}"
    
    check_minikube
    check_namespace
    check_deployments
    check_pods
    check_services
    check_endpoints
    check_ingress
    check_persistent_volumes
    check_mongodb
    check_http_endpoints
    
    print_summary
    return $?
}

# Run the main function
main "$@"
