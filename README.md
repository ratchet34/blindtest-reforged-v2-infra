# Blindtest Reforged V2 Infrastructure

This repository contains Kubernetes infrastructure manifests for Blindtest Reforged V2, a multi-component web application with game and admin interfaces.

## Architecture Overview

The application consists of four main components:
- **Backend**: API service (currently nginx placeholder)
- **Game Frontend**: Main game interface 
- **Admin Frontend**: Administrative interface
- **MongoDB**: Database service for data persistence

All components are routed through a single ingress:
- `/` → Game Frontend (main application)
- `/admin` → Admin Frontend (administration panel)
- `/api` → Backend (API endpoints)

The backend communicates with MongoDB internally via the `mongodb-service` on port 27017.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [minikube](https://minikube.sigs.k8s.io/docs/start/)

## Setup Instructions

### 1. Start Minikube

```bash
# Start minikube with recommended settings
minikube start --driver=docker --memory=4096 --cpus=2

# Verify cluster is running
kubectl cluster-info
```

### 2. Enable Required Addons

```bash
# Enable ingress controller (nginx)
minikube addons enable ingress

# Enable metrics server for resource monitoring
minikube addons enable metrics-server

# Verify addons are enabled
minikube addons list
```

### 3. Deploy the Application

```bash
# Deploy all components using kustomize
kubectl apply -k .

# Verify all resources are created
kubectl get all -n blindtest
```

### 4. Configure Local Access

Since the ingress is configured for `blindtest.local`, you need to add it to your hosts file:

```bash
# Get minikube IP
minikube ip

# Add this line to your hosts file (replace <MINIKUBE_IP> with actual IP):
<MINIKUBE_IP> blindtest.local
```

**Windows:**
- Hosts file location: `C:\Windows\System32\drivers\etc\hosts`
- PowerShell (Run as Administrator):
```powershell
# Get minikube IP and add to hosts
$minikubeIP = minikube ip
Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "$minikubeIP blindtest.local"
```

**Linux/macOS:**
- Hosts file location: `/etc/hosts`
- Command:
```bash
# Get minikube IP and add to hosts
echo "$(minikube ip) blindtest.local" | sudo tee -a /etc/hosts
```

### 5. Access the Application

Once deployed and hosts file is configured:

- **Game Interface**: http://blindtest.local
- **Admin Interface**: http://blindtest.local/admin
- **API Endpoints**: http://blindtest.local/api

## Verification Commands

```bash
# Check pod status
kubectl get pods -n blindtest

# Check services
kubectl get services -n blindtest

# Check ingress
kubectl get ingress -n blindtest

# View pod logs
kubectl logs -n blindtest deployment/mongodb-deployment
kubectl logs -n blindtest deployment/backend-deployment
kubectl logs -n blindtest deployment/game-frontend-deployment
kubectl logs -n blindtest deployment/admin-frontend-deployment

# Get ingress details
kubectl describe ingress blindtest-ingress -n blindtest
```

## Troubleshooting

### Common Issues

**Pods not starting:**
```bash
# Check pod events
kubectl describe pod <pod-name> -n blindtest

# Check resource usage
kubectl top pods -n blindtest
```

**Ingress not working:**
```bash
# Verify ingress controller is running
kubectl get pods -n ingress-nginx

# Check ingress configuration
kubectl describe ingress blindtest-ingress -n blindtest

# Verify minikube tunnel (if needed)
minikube tunnel
```

**Cannot access application:**
1. Verify minikube IP: `minikube ip`
2. Check hosts file entry
3. Verify ingress controller: `kubectl get pods -n ingress-nginx`
4. Test direct service access: `minikube service game-frontend-service -n blindtest`

### Resource Monitoring

```bash
# View resource usage
kubectl top nodes
kubectl top pods -n blindtest

# Monitor events
kubectl get events -n blindtest --sort-by='.lastTimestamp'
```

### MongoDB Database Access

The MongoDB database is accessible internally to the backend service via:
- **Service Name**: `mongodb-service`
- **Port**: 27017
- **Database**: `blindtest`

**Configuration Management:**
- **ConfigMap** (`mongodb-config`): Non-sensitive configuration (host, port, database name)
- **Secret** (`mongodb-secret`): Sensitive data (username, password, connection URI)

To connect to MongoDB for debugging:
```bash
# Port forward to access MongoDB locally
kubectl port-forward -n blindtest service/mongodb-service 27017:27017

# Connect using mongo client (in another terminal)
mongosh "mongodb://admin:blindtest123@localhost:27017/blindtest?authSource=admin"
```

**Viewing Configuration:**
```bash
# View ConfigMap data
kubectl get configmap mongodb-config -n blindtest -o yaml

# View Secret keys (values are base64 encoded)
kubectl get secret mongodb-secret -n blindtest -o yaml
```

## Development Workflow

### Making Changes

1. Edit the manifest files
2. Apply changes: `kubectl apply -k .`
3. Verify deployment: `kubectl get pods -n blindtest`

### Updating Images

Currently all deployments use `nginx:latest` placeholders. To update with actual application images:

1. Edit deployment files in `01_deployments/`
2. Update the `image` field with your application images
3. Apply changes: `kubectl apply -k .`

### Scaling

```bash
# Scale a deployment
kubectl scale deployment backend-deployment --replicas=3 -n blindtest

# Or edit the manifest file and apply
```

## Cleanup

```bash
# Delete all resources
kubectl delete -k .

# Stop minikube
minikube stop

# Delete minikube cluster (optional)
minikube delete
```

## Next Steps

1. Replace `nginx:latest` images with actual application containers
2. Set up persistent volumes for MongoDB data storage
3. Configure resource limits based on actual application requirements  
4. Add health checks and readiness probes
5. Set up TLS/SSL certificates for secure communication
6. Implement proper secrets management (consider external secret stores like Azure Key Vault, AWS Secrets Manager, or HashiCorp Vault)
7. Add monitoring and logging solutions (Prometheus, Grafana, ELK stack)
