# Blindtest Reforged V2 Infrastructure Deployment Script (PowerShell)
# This script deploys the complete Kubernetes infrastructure

# Colors for output
$Red = "`e[0;31m"
$Green = "`e[0;32m"
$Yellow = "`e[1;33m"
$Blue = "`e[0;34m"
$NC = "`e[0m" # No Color

# Function to print section headers
function Write-Header {
    param([string]$Title)
    Write-Host "`n$Blue=== $Title ===$NC`n"
}

# Function to print status
function Write-Status {
    param([string]$Message)
    Write-Host "$Green✅$NC $Message"
}

# Function to print warning
function Write-Warning {
    param([string]$Message)
    Write-Host "$Yellow⚠️$NC $Message"
}

# Function to print error
function Write-Error {
    param([string]$Message)
    Write-Host "$Red❌$NC $Message"
}

# Check prerequisites
function Test-Prerequisites {
    Write-Header "Checking Prerequisites"
    
    # Check if kubectl is installed
    try {
        kubectl version --client 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Status "kubectl is available"
        } else {
            Write-Error "kubectl is not installed"
            exit 1
        }
    } catch {
        Write-Error "kubectl is not installed"
        exit 1
    }
    
    # Check if minikube is installed
    try {
        minikube version 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Status "minikube is available"
        } else {
            Write-Error "minikube is not installed"
            exit 1
        }
    } catch {
        Write-Error "minikube is not installed"
        exit 1
    }
    
    # Check if minikube is running
    $minikubeStatus = minikube status 2>$null
    if ($minikubeStatus -match "Running") {
        Write-Status "minikube is running"
    } else {
        Write-Warning "minikube is not running, starting it..."
        minikube start
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to start minikube"
            exit 1
        }
    }
    
    # Enable required addons
    Write-Header "Enabling Minikube Addons"
    minikube addons enable ingress
    minikube addons enable metrics-server
    Write-Status "Required addons enabled"
}

# Deploy infrastructure
function Deploy-Infrastructure {
    Write-Header "Deploying Infrastructure"
    
    # Apply all Kubernetes resources
    Write-Host "Applying Kubernetes manifests..."
    kubectl apply -k .
    
    if ($LASTEXITCODE -eq 0) {
        Write-Status "Infrastructure deployed successfully"
    } else {
        Write-Error "Failed to deploy infrastructure"
        exit 1
    }
}

# Wait for deployments to be ready
function Wait-ForReady {
    Write-Header "Waiting for Deployments to be Ready"
    
    $deployments = @("mongodb-deployment", "backend-deployment", "game-frontend-deployment", "admin-frontend-deployment", "mongo-express-deployment")
    
    foreach ($deployment in $deployments) {
        Write-Host "Waiting for $deployment to be ready..."
        kubectl wait --for=condition=available --timeout=300s deployment/$deployment -n blindtest
        
        if ($LASTEXITCODE -eq 0) {
            Write-Status "$deployment is ready"
        } else {
            Write-Warning "$deployment took longer than expected to be ready"
        }
    }
}

# Show access information
function Show-AccessInfo {
    Write-Header "Access Information"
    
    $minikubeIP = minikube ip
    
    Write-Host "Minikube IP: $Blue$minikubeIP$NC"
    Write-Host ""
    Write-Host "Add the following to your C:\Windows\System32\drivers\etc\hosts file:"
    Write-Host "$Yellow$minikubeIP blindtest.local$NC"
    Write-Host ""
    Write-Host "Available endpoints:"
    Write-Host "  • Game Frontend:    ${Green}http://blindtest.local/$NC"
    Write-Host "  • Admin Frontend:   ${Green}http://blindtest.local/admin$NC"
    Write-Host "  • Backend API:      ${Green}http://blindtest.local/api$NC"
    Write-Host "  • Database Admin:   ${Green}http://blindtest.local/database$NC (admin/blindtest123)"
    Write-Host ""
    Write-Host "To test the infrastructure, run:"
    Write-Host "  ${Blue}.\test-infrastructure.ps1$NC"
}

# Main execution
function Main {
    Write-Host "$Blue"
    Write-Host "🎵 Blindtest Reforged V2 Infrastructure Deployment"
    Write-Host "=================================================="
    Write-Host "$NC"
    
    Test-Prerequisites
    Deploy-Infrastructure
    Wait-ForReady
    Show-AccessInfo
    
    Write-Header "Deployment Complete"
    Write-Status "Infrastructure is ready!"
}

# Run the main function
Main
