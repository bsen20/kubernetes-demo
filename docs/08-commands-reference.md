# 08 — Commands Reference

> Quick-reference for `kubectl`, `minikube`, and `helm`

---

## Table of Contents

1. [kubectl — Context & Cluster](#kubectl--context--cluster)
2. [kubectl — Resource Management](#kubectl--resource-management)
3. [kubectl — Debugging & Troubleshooting](#kubectl--debugging--troubleshooting)
4. [kubectl — RBAC & Security](#kubectl--rbac--security)
5. [kubectl — Configuration & Secrets](#kubectl--configuration--secrets)
6. [kubectl — Storage](#kubectl--storage)
7. [kubectl — Networking](#kubectl--networking)
8. [kubectl — Advanced](#kubectl--advanced)
9. [kubectl — Output & Formatting](#kubectl--output--formatting)
10. [Minikube Commands](#minikube-commands)
11. [Helm Commands](#helm-commands)
12. [Aliases & Shortcuts](#aliases--shortcuts)

---

## kubectl — Context & Cluster

```bash
# Cluster info
kubectl cluster-info
kubectl cluster-info dump
kubectl version --short
kubectl api-resources
kubectl api-versions
kubectl get componentstatuses

# Context (cluster/user/namespace)
kubectl config current-context
kubectl config get-contexts
kubectl config use-context minikube
kubectl config set-context --current --namespace=myapp
kubectl config set-context my-context --cluster=prod --namespace=default --user=admin
kubectl config delete-context my-context
kubectl config view

# Nodes
kubectl get nodes
kubectl get nodes -o wide
kubectl describe node minikube
kubectl top node
kubectl cordon node-name       # Mark unschedulable
kubectl uncordon node-name     # Mark schedulable
kubectl drain node-name        # Evict pods (maintenance)
```

---

## kubectl — Resource Management

### Create & Apply

```bash
# Imperative
kubectl run nginx --image=nginx
kubectl create deployment myapp --image=myapp --replicas=3
kubectl create namespace myapp
kubectl create configmap my-config --from-literal=key=value
kubectl create secret generic my-secret --from-literal=password=secret

# Declarative (preferred)
kubectl apply -f deployment.yaml
kubectl apply -f ./manifests/
kubectl apply -f https://example.com/deployment.yaml
kubectl apply -f - < stdin                # From stdin

# Dry run
kubectl apply -f deployment.yaml --dry-run=client -o yaml
```

### Get & List

```bash
kubectl get all                           # Common resources
kubectl get pods
kubectl get pods -o wide                  # + node/ip
kubectl get pods -w                       # Watch
kubectl get pods --all-namespaces
kubectl get pods --show-labels
kubectl get pods --field-selector=status.phase=Running
kubectl get pods -l app=myapp,tier=frontend
kubectl get deployments
kubectl get services
kubectl get ingress
kubectl get nodes
kubectl get events --sort-by=.metadata.creationTimestamp
```

### Describe

```bash
kubectl describe pod myapp-5d7f8c9b6-abc12
kubectl describe deployment myapp
kubectl describe node minikube
kubectl describe svc myapp-service
```

### Delete

```bash
kubectl delete pod myapp-5d7f8c9b6-abc12
kubectl delete deployment myapp
kubectl delete service myapp-service
kubectl delete pod --all                   # Delete all pods in namespace
kubectl delete all --all                   # Delete all resources
kubectl delete -f deployment.yaml
kubectl delete pod myapp-pod --grace-period=0 --force
```

### Edit & Patch

```bash
kubectl edit deployment myapp              # Opens $EDITOR
kubectl patch deployment myapp -p '{"spec":{"replicas":5}}'
kubectl patch pod myapp-pod -p '{"metadata":{"labels":{"version":"v2"}}}'
```

### Scale

```bash
kubectl scale deployment myapp --replicas=5
kubectl scale statefulset postgres --replicas=3
kubectl scale deployment myapp --replicas=0  # Scale to zero
kubectl autoscale deployment myapp --min=2 --max=10 --cpu-percent=80
```

### Rollout

```bash
kubectl rollout status deployment/myapp
kubectl rollout history deployment/myapp
kubectl rollout history deployment/myapp --revision=2
kubectl rollout undo deployment/myapp
kubectl rollout undo deployment/myapp --to-revision=1
kubectl rollout restart deployment/myapp
kubectl rollout pause deployment/myapp
kubectl rollout resume deployment/myapp
```

### Labels & Annotations

```bash
kubectl label pod myapp-pod version=v2
kubectl label pod myapp-pod version-                 # Remove label
kubectl annotate pod myapp-pod description="frontend"
kubectl annotate pod myapp-pod description-          # Remove annotation
```

---

## kubectl — Debugging & Troubleshooting

### Logs

```bash
kubectl logs myapp-pod
kubectl logs myapp-pod -c sidecar          # Specific container
kubectl logs -l app=myapp                  # Multi-pod logs (K8s 1.14+)
kubectl logs myapp-pod --tail=100          # Last 100 lines
kubectl logs myapp-pod -f                  # Follow (stream)
kubectl logs myapp-pod --since=1h          # Since time
kubectl logs myapp-pod --previous          # Previous (crashed) container
```

### Exec

```bash
kubectl exec myapp-pod -- ls /app
kubectl exec -it myapp-pod -- /bin/sh
kubectl exec -it myapp-pod -c sidecar -- bash
kubectl exec deployment/myapp -- env        # Exec on first pod
```

### Port Forward

```bash
kubectl port-forward pod/myapp-pod 8080:3000
kubectl port-forward deployment/myapp 8080:3000
kubectl port-forward service/myapp 8080:80   # Service forwarding (K8s 1.23+)
kubectl port-forward pod/myapp-pod 8080:3000 --address 0.0.0.0
```

### Copy Files

```bash
kubectl cp ./local/file.txt myapp-pod:/remote/path
kubectl cp myapp-pod:/remote/file.txt ./local/
kubectl cp ./backup/ myapp-pod:/backup/ -c sidecar
```

### Debug

```bash
kubectl debug myapp-pod                     # Ephemeral container
kubectl debug node/minikube -it             # Debug node
kubectl debug myapp-pod -it --image=busybox --copy-to=debug-pod
```

### Events & Top

```bash
kubectl get events
kubectl get events --sort-by='.lastTimestamp'
kubectl get events --field-selector type=Warning
kubectl top pod                            # CPU/memory per pod
kubectl top node                           # CPU/memory per node
```

---

## kubectl — RBAC & Security

```bash
# Auth checks
kubectl auth can-i create deployments
kubectl auth can-i delete pods --as=system:serviceaccount:default:myapp-sa
kubectl auth can-i get pods --all-namespaces --as=admin@example.com
kubectl auth whoami

# RBAC resources
kubectl get roles
kubectl get rolebindings
kubectl get clusterroles
kubectl get clusterrolebindings
kubectl describe role pod-reader

# ServiceAccounts
kubectl create serviceaccount myapp-sa
kubectl get serviceaccounts
```

---

## kubectl — Configuration & Secrets

### ConfigMaps

```bash
kubectl create configmap my-config \
  --from-literal=key=value
kubectl create configmap my-config \
  --from-file=config.json
kubectl create configmap my-config \
  --from-env-file=.env
kubectl create configmap my-config \
  --from-file=./configs/

kubectl get configmap my-config -o yaml
```

### Secrets

```bash
kubectl create secret generic my-secret \
  --from-literal=password=secret123
kubectl create secret tls my-tls \
  --cert=server.crt --key=server.key
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=user \
  --docker-password=token

kubectl get secret my-secret -o yaml
kubectl get secret my-secret -o jsonpath='{.data.password}' | base64 -d
```

---

## kubectl — Storage

```bash
kubectl get pv
kubectl get pvc
kubectl get storageclass
kubectl describe pv pvc-abc123
kubectl describe pvc myapp-pvc

# Expand PVC
kubectl patch pvc myapp-pvc -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'

# Delete PVC
kubectl delete pvc myapp-pvc
```

---

## kubectl — Networking

```bash
kubectl get services
kubectl get endpoints
kubectl get ingress
kubectl describe svc myapp-service
kubectl describe ingress myapp-ingress

# NetworkPolicy
kubectl get networkpolicies
kubectl describe networkpolicy deny-all
```

---

## kubectl — Advanced

### Custom Columns

```bash
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase
kubectl get pods -o custom-columns-file=columns.txt
```

### JSON Path

```bash
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
kubectl get pods -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}'
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
```

### Wait

```bash
kubectl wait --for=condition=Ready pod/myapp-pod --timeout=60s
kubectl wait --for=condition=Available deployment/myapp --timeout=5m
kubectl wait --for=delete pod/myapp-pod --timeout=30s
kubectl wait --for=jsonpath='{.status.phase}'=Running pod/myapp-pod
```

### Impersonation

```bash
kubectl get pods --as=admin@example.com
kubectl get pods --as=system:serviceaccount:default:myapp-sa
kubectl get pods --as-group=system:masters
```

### Taints & Tolerations

```bash
kubectl taint node minikube key=value:NoSchedule
kubectl taint node minikube key=value:NoSchedule-
```

---

## kubectl — Output & Formatting

### Output Formats

```bash
kubectl get pods -o wide                    # Extra columns
kubectl get pods -o yaml                    # YAML manifest
kubectl get pods -o json                    # JSON
kubectl get pods -o jsonpath='{.items[*].metadata.name}'  # JSON path
kubectl get pods -o name                    # Only resource type/name
kubectl get pods -o custom-columns=NAME:.metadata.name
kubectl get pods --sort-by=.metadata.creationTimestamp
kubectl get pods --sort-by=.status.podIP
```

### Templates

```bash
# Go template
kubectl get pods -o go-template='{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'

# Template file
kubectl get pods -o go-template-file=template.txt
```

---

## Minikube Commands

```bash
# Cluster lifecycle
minikube start \
  --driver=docker \
  --cpus=4 \
  --memory=8192 \
  --kubernetes-version=v1.28.0
minikube stop
minikube delete
minikube status

# Addons
minikube addons list
minikube addons enable ingress
minikube addons enable dashboard
minikube addons enable metrics-server
minikube addons disable ingress

# Dashboard
minikube dashboard                    # Open in browser
minikube dashboard --url              # Get URL only

# Networking
minikube ip                           # Cluster IP
minikube service my-service           # Open service in browser
minikube service my-service --url     # Get service URL
minikube tunnel                       # Expose LoadBalancer services

# Docker
minikube docker-env                   # Get Docker env vars
eval $(minikube docker-env)           # Use minikube's Docker daemon

# Images
minikube image build -t myapp:latest .
minikube image load myapp:latest
minikube image list

# SSH
minikube ssh                          # SSH into node

# Logs
minikube logs                         # Minikube logs

# Profiles
minikube profile list
minikube profile my-cluster
minikube start -p my-cluster

# Config
minikube config set memory 4096
minikube config set cpus 4
minikube config set driver docker
minikube config view
```

---

## Helm Commands

```bash
# Repositories
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo list
helm repo update
helm repo remove bitnami

# Search
helm search hub nginx                  # Artifact Hub
helm search repo nginx                 # Local repos
helm search repo nginx --versions      # All versions

# Install / Upgrade / Rollback
helm install my-release bitnami/nginx
helm install my-release ./my-chart --values prod.yaml
helm upgrade my-release bitnami/nginx --set replicaCount=5
helm upgrade my-release ./my-chart -f prod.yaml --atomic --timeout 5m
helm rollback my-release 2

# List & Inspect
helm list
helm list -a                           # All namespaces
helm list --all                        # Include uninstalled
helm status my-release
helm history my-release
helm get values my-release
helm get manifest my-release
helm get notes my-release

# Template & Lint
helm template my-release ./my-chart
helm template my-release ./my-chart --debug
helm lint ./my-chart

# Package
helm package ./my-chart -d ./packages/
helm repo index ./packages/

# Dependencies
helm dependency update ./my-chart
helm dependency list ./my-chart

# Uninstall
helm uninstall my-release
helm uninstall my-release --keep-history

# Test
helm test my-release

# OCI
helm chart pull oci://registry-1.docker.io/bitnamicharts/nginx
helm chart export bitnamicharts/nginx --destination ./charts/
helm chart save ./my-chart myregistry.io/charts/my-chart:1.0.0
helm chart push my-chart-1.0.0.tgz oci://myregistry.io/charts

# Plugin management
helm plugin install https://github.com/databus/helm-s3
helm plugin list
helm plugin uninstall s3
```

---

## Aliases & Shortcuts

```bash
# Common aliases to add to ~/.bashrc or ~/.zshrc
alias k='kubectl'
alias kg='kubectl get'
alias kgp='kubectl get pods'
alias kgd='kubectl get deployments'
alias kgs='kubectl get services'
alias kga='kubectl get all'
alias kgn='kubectl get nodes'
alias kd='kubectl describe'
alias kdp='kubectl describe pod'
alias kdd='kubectl describe deployment'
alias kl='kubectl logs'
alias klf='kubectl logs -f'
alias kex='kubectl exec -it'
alias kpf='kubectl port-forward'
alias ka='kubectl apply -f'
alias kdf='kubectl delete -f'
alias kubeon='kubectl config use-context minikube'
alias kubeoff='kubectl config use-context docker-desktop'
alias kns='kubectl config set-context --current --namespace'
alias kctx='kubectl config use-context'

# Helm aliases
alias h='helm'
alias hi='helm install'
alias hu='helm upgrade'
alias hl='helm list'
alias hls='helm list -a'
alias hsta='helm status'
alias hhist='helm history'

# Completion
source <(kubectl completion bash)
source <(helm completion bash)
source <(minikube completion bash)
```

### kubectl Cheatsheet (Quick)

| Action | Command |
|--------|---------|
| List pods | `kubectl get pods` |
| Describe pod | `kubectl describe pod <name>` |
| Pod logs | `kubectl logs <name> [-f]` |
| Exec into pod | `kubectl exec -it <name> -- sh` |
| Apply manifests | `kubectl apply -f <file>` |
| Delete resource | `kubectl delete -f <file>` |
| Scale deployment | `kubectl scale deploy/<name> --replicas=N` |
| Rollout status | `kubectl rollout status deploy/<name>` |
| Port forward | `kubectl port-forward pod/<name> local:remote` |
| Watch resources | `kubectl get pods -w` |
| All namespaces | `--all-namespaces` or `-A` |
| Wide output | `-o wide` |
| YAML output | `-o yaml` |

---

## Next Steps

→ [09 — Interview Questions](./09-interview-questions.md)
