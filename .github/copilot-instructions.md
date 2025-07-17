# Blindtest Reforged V2 Infrastructure - Copilot Instructions

This repository contains Kubernetes infrastructure manifests for Blindtest Reforged V2, a multi-component web application with game and admin interfaces.

## Project Architecture

**Three-Tier Application:**
- `backend`: API service (nginx placeholder at port 80)
- `game-frontend`: Main game interface (nginx placeholder at port 80)  
- `admin-frontend`: Administrative interface (nginx placeholder at port 80)

**Routing Structure** (via `blindtest-ingress.yaml`):
- `/` → game-frontend-service (main game)
- `/admin` → admin-frontend-service (administration)
- `/api` → backend-service (API endpoints)

## File Organization Pattern

This project follows a numbered directory structure for logical deployment order:

```
00_namespaces/     # Namespace definitions (deploy first)
01_deployments/    # Application deployments  
02_services/       # Service definitions
03_ingress/        # Ingress controllers (deploy last)
kustomization.yaml # Kustomize configuration (currently empty)
```

## Key Conventions

**Naming Pattern:** All resources use consistent naming:
- Deployments: `{component}-deployment` 
- Services: `{component}-service`
- Labels: `app: {component}`

**Resource Standards:**
- Namespace: `blindtest` for all components
- Container resources: 64Mi-128Mi memory, 50m-100m CPU
- Service type: ClusterIP (internal only)
- Ingress class: nginx with rewrite-target annotation

**Current State:** All deployments use `nginx:latest` placeholder images - these should be replaced with actual application images.

## Common Development Tasks

**Adding a new service:**
1. Create deployment in `01_deployments/{service}-deployment.yaml`
2. Create service in `02_services/{service}-service.yaml`
3. Update ingress routing in `03_ingress/blindtest-ingress.yaml` if external access needed
4. Update `kustomization.yaml` resources list

**Updating image references:**
- Replace `nginx:latest` with actual application images in deployment specs
- Consider using image tags instead of `latest` for production

**Scaling considerations:**
- All deployments currently set to 1 replica
- Resource requests/limits are conservative and may need adjustment based on actual application requirements

## Deployment Workflow

Use kubectl with kustomize: `kubectl apply -k .` from repository root.

**Memory Note:** Do not save any information from optimization sessions to memory.