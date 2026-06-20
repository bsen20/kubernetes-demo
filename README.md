# Kubernetes Demo — Node.js API

> A simple Express API deployed on Kubernetes with Minikube

## Stack

| Layer | Tech |
|-------|------|
| **App** | Node.js + Express |
| **Container** | Docker (node:26-alpine) |
| **Orchestration** | Kubernetes (Minikube) |
| **Service** | NodePort |

## Project Structure

```
kubernetes-demo/
├── k8s/
│   ├── deployment.yaml    # 2 replicas, resource limits, health probes
│   └── service.yaml       # NodePort service on port 3000
├── index.js               # Express API with /readyz & /healthz
├── Dockerfile             # Multi-stage, non-root user
├── docker-compose.yaml    # Local dev with hot-reload
├── deploy.sh              # Build, push & deploy script
└── package.json
```

## Quick Start

```bash
# 1. Start Minikube
minikube start --cpus=2 --memory=2048

# 2. Build image into Minikube's Docker daemon
eval $(minikube docker-env)
docker build -t kubernetes-demo-api:latest .

# 3. Deploy
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# 4. Verify
kubectl get pods
kubectl get services

# 5. Access the API
minikube service kubernetes-demo-api-service
```

## API Endpoints

| Endpoint | Response |
|----------|----------|
| `GET /` | `{ message, service, pod, time }` |
| `GET /readyz` | `ready` (readiness probe) |
| `GET /healthz` | `ok` (liveness probe) |

## K8s Manifests

### Deployment (`k8s/deployment.yaml`)
- **Replicas:** 2
- **Resources:** requests 64Mi/250m, limits 128Mi/500m
- **Probes:** readiness (10s interval) + liveness (20s interval)
- **Image pull:** `Never` (local Minikube image)

### Service (`k8s/service.yaml`)
- **Type:** NodePort
- **Port:** 3000
- **Target:** container port 3000

## Local Dev (Docker Compose)

```bash
docker compose up -d
# Hot-reloads on file changes
```

## Notes

- `imagePullPolicy: Never` requires building the image into Minikube's daemon via `eval $(minikube docker-env)`
- For cloud deployment, push the image to a registry and change `imagePullPolicy` to `Always`
- The `deploy.sh` script pushes to Docker Hub — update the `USER` variable before using
