# 10 — Practical Problems

> Hands-on exercises to build real Kubernetes skills

---

## Table of Contents

1. [Problem 01 — Deploy a Stateless App](#problem-01--deploy-a-stateless-app)
2. [Problem 02 — Service Discovery & DNS](#problem-02--service-discovery--dns)
3. [Problem 03 — Zero-Downtime Deployment](#problem-03--zero-downtime-deployment)
4. [Problem 04 — Horizontal Scaling with HPA](#problem-04--horizontal-scaling-with-hpa)
5. [Problem 05 — Stateful Application with PostgreSQL](#problem-05--stateful-application-with-postgresql)
6. [Problem 06 — Configuration with ConfigMaps & Secrets](#problem-06--configuration-with-configmaps--secrets)
7. [Problem 07 — Securing the Cluster with RBAC & NetworkPolicies](#problem-07--securing-the-cluster-with-rbac--networkpolicies)
8. [Problem 08 — Ingress with TLS](#problem-08--ingress-with-tls)
9. [Problem 09 — Multi-Container Pod with Sidecar](#problem-09--multi-container-pod-with-sidecar)
10. [Problem 10 — Helm Chart Authoring](#problem-10--helm-chart-authoring)
11. [Problem 11 — Cluster Troubleshooting](#problem-11--cluster-troubleshooting)
12. [Problem 12 — Disaster Recovery](#problem-12--disaster-recovery)

---

## Problem 01 — Deploy a Stateless App

**Objective:** Deploy a simple web app with a LoadBalancer Service.

### Requirements

- Create a Deployment named `webapp` with:
  - Image: `nginx:alpine`
  - 3 replicas
  - Port 80
  - Resource requests: 128Mi memory, 100m CPU
  - Resource limits: 256Mi memory, 200m CPU
  - Readiness probe: HTTP GET / on port 80
  - Liveness probe: HTTP GET / on port 80
- Create a Service named `webapp-svc`:
  - Type: LoadBalancer (or NodePort on Minikube)
  - Port 80 → targetPort 80

### Solution

<details>
<summary>Click to expand</summary>

```yaml
# 01-webapp.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: 128Mi
              cpu: 100m
            limits:
              memory: 256Mi
              cpu: 200m
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 15
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: webapp-svc
spec:
  type: NodePort
  selector:
    app: webapp
  ports:
    - port: 80
      targetPort: 80
```
</details>

### Verification

```bash
kubectl apply -f 01-webapp.yaml
kubectl get pods -l app=webapp -w
kubectl get svc webapp-svc
kubectl port-forward svc/webapp-svc 8080:80
# Visit http://localhost:8080
kubectl logs -l app=webapp
```

---

## Problem 02 — Service Discovery & DNS

**Objective:** Deploy two apps and have them communicate via DNS.

### Requirements

- `frontend` deployment (nginx) with 2 replicas, Service named `frontend`
- `backend` deployment (nginx) with 1 replica, Service named `backend`
- Exec into a frontend pod and verify it can reach `backend` via DNS:
  - `curl http://backend`
  - `nslookup backend`

### Solution

<details>
<summary>Click to expand</summary>

```yaml
# 02-service-discovery.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
        - name: frontend
          image: nginx:alpine
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  selector:
    app: frontend
  ports:
    - port: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: nginx:alpine
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  selector:
    app: backend
  ports:
    - port: 80
```
</details>

### Verification

```bash
kubectl apply -f 02-service-discovery.yaml
FRONTEND_POD=$(kubectl get pod -l app=frontend -o name | head -1)
kubectl exec -it $FRONTEND_POD -- apk add curl
kubectl exec -it $FRONTEND_POD -- curl http://backend
kubectl exec -it $FRONTEND_POD -- nslookup backend
kubectl exec -it $FRONTEND_POD -- nslookup backend.default.svc.cluster.local
```

---

## Problem 03 — Zero-Downtime Deployment

**Objective:** Perform a rolling update with zero downtime.

### Requirements

- Create a Deployment with `version: v1` annotation
- Update to `version: v2`
- Verify no downtime during the update
- Rollback to v1

### Solution

<details>
<summary>Click to expand</summary>

```yaml
# 03-rolling-update.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1              # Can create 1 extra pod
      maxUnavailable: 0         # Must keep all pods available during update
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: app
          image: nginx:alpine
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 2
            periodSeconds: 2
---
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp
  ports:
    - port: 80
```
</details>

### Verification

```bash
kubectl apply -f 03-rolling-update.yaml

# Watch for downtime (in another terminal)
kubectl run test --image=nginx:alpine -it --rm --restart=Never -- /bin/sh -c \
  "while true; do curl -s -o /dev/null -w '%{http_code}\n' http://myapp; sleep 0.5; done"

# Update to v2 (change image)
kubectl set image deployment/myapp app=nginx:1.25-alpine
# Or: kubectl edit deployment myapp

# Watch rollout
kubectl rollout status deployment/myapp
kubectl rollout history deployment/myapp

# Rollback
kubectl rollout undo deployment/myapp
kubectl rollout status deployment/myapp
```

---

## Problem 04 — Horizontal Scaling with HPA

**Objective:** Autoscale a deployment based on CPU usage.

### Requirements

- Deploy a CPU-intensive app
- Configure HPA to scale between 1-10 pods at 50% CPU
- Generate load and observe scaling

### Solution

<details>
<summary>Click to expand</summary>

```yaml
# 04-hpa.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cpu-stress
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cpu-stress
  template:
    metadata:
      labels:
        app: cpu-stress
    spec:
      containers:
        - name: stress
          image: containerstack/alpine-stress
          command: ["stress", "--cpu", "4", "--timeout", "600s"]
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 256Mi
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: cpu-stress-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: cpu-stress
  minReplicas: 1
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```
</details>

### Verification

```bash
# Ensure metrics-server is running
kubectl top nodes
# If no metrics, enable: minikube addons enable metrics-server

kubectl apply -f 04-hpa.yaml

# Watch HPA
kubectl get hpa cpu-stress-hpa -w

# Watch pods scale
kubectl get pods -l app=cpu-stress -w

# Generate more load if needed
# kubectl scale deployment cpu-stress --replicas=5

# Clean up
kubectl delete deployment cpu-stress
kubectl delete hpa cpu-stress-hpa
```

---

## Problem 05 — Stateful Application with PostgreSQL

**Objective:** Deploy PostgreSQL with persistent storage using a StatefulSet.

### Requirements

- StatefulSet named `postgres`
- Image: `postgres:16-alpine`
- 1 replica
- Environment variables for POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB from a Secret
- PVC via volumeClaimTemplates: 5GB, RWO
- Service named `postgres` (ClusterIP, port 5432)
- Readiness probe: `pg_isready -U $POSTGRES_USER`

### Solution

<details>
<summary>Click to expand</summary>

```yaml
# 05-postgres.yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
type: Opaque
stringData:
  POSTGRES_USER: myapp
  POSTGRES_PASSWORD: changeme123!
  POSTGRES_DB: myapp
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  labels:
    app: postgres
spec:
  clusterIP: None
  selector:
    app: postgres
  ports:
    - name: postgres
      port: 5432
      targetPort: 5432
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: POSTGRES_USER
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: POSTGRES_PASSWORD
            - name: POSTGRES_DB
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: POSTGRES_DB
          resources:
            requests:
              memory: 256Mi
              cpu: 250m
            limits:
              memory: 512Mi
              cpu: 500m
          readinessProbe:
            exec:
              command:
                - pg_isready
                - -U
                - myapp
            initialDelaySeconds: 15
            periodSeconds: 5
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 5Gi
```
</details>

### Verification

```bash
kubectl apply -f 05-postgres.yaml
kubectl get pvc                    # Should see data-postgres-0
kubectl get pods -l app=postgres
kubectl exec -it postgres-0 -- psql -U myapp -d myapp -c "\l"
kubectl exec -it postgres-0 -- psql -U myapp -d myapp -c "CREATE TABLE test (id SERIAL PRIMARY KEY, data TEXT);"
kubectl exec -it postgres-0 -- psql -U myapp -d myapp -c "INSERT INTO test (data) VALUES ('hello k8s');"
kubectl exec -it postgres-0 -- psql -U myapp -d myapp -c "SELECT * FROM test;"

# Data persists even if pod is deleted
kubectl delete pod postgres-0
kubectl get pod postgres-0 -w     # Wait for re-creation
kubectl exec -it postgres-0 -- psql -U myapp -d myapp -c "SELECT * FROM test;"
```

---

## Problem 06 — Configuration with ConfigMaps & Secrets

**Objective:** Configure an app using ConfigMaps and Secrets.

### Requirements

- ConfigMap `app-config`: NODE_ENV=production, LOG_LEVEL=info, API_URL=http://api:3000
- Secret `app-secret`: API_KEY, DB_URL
- Deployment `config-demo` mounting:
  - All ConfigMap keys as env vars (with prefix `APP_`)
  - Specific ConfigMap keys as env vars (API_URL)
  - Secret keys as env vars
  - ConfigMap as volume at `/etc/config`

### Solution

<details>
<summary>Click to expand</summary>

```yaml
# 06-config-demo.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  NODE_ENV: production
  LOG_LEVEL: info
  API_URL: http://api:3000
  config.yaml: |
    server:
      host: "0.0.0.0"
      port: 8080
    database:
      pool: 10
---
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
stringData:
  API_KEY: sk-abc123def456
  DB_URL: postgres://myapp:changeme123!@postgres:5432/myapp
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: config-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: config-demo
  template:
    metadata:
      labels:
        app: config-demo
    spec:
      containers:
        - name: app
          image: nginx:alpine
          ports:
            - containerPort: 80
          env:
            # Specific ConfigMap key
            - name: API_URL
              valueFrom:
                configMapKeyRef:
                  name: app-config
                  key: API_URL
            # Specific Secret key
            - name: DB_URL
              valueFrom:
                secretKeyRef:
                  name: app-secret
                  key: DB_URL
          # All ConfigMap keys (with prefix)
          envFrom:
            - configMapRef:
                name: app-config
                prefix: APP_
            - secretRef:
                name: app-secret
          volumeMounts:
            - name: config-volume
              mountPath: /etc/config
              readOnly: true
          command:
            - /bin/sh
            - -c
            - |
              echo "=== Env Vars ===" > /usr/share/nginx/html/index.html
              env | sort >> /usr/share/nginx/html/index.html
              echo -e "\n=== Config File ===" >> /usr/share/nginx/html/index.html
              cat /etc/config/* >> /usr/share/nginx/html/index.html
              nginx -g 'daemon off;'
      volumes:
        - name: config-volume
          configMap:
            name: app-config
            items:
              - key: config.yaml
                path: app.yaml
```
</details>

### Verification

```bash
kubectl apply -f 06-config-demo.yaml
kubectl port-forward deployment/config-demo 8080:80
curl http://localhost:8080
# Should show env vars and config file content
```

---

## Problem 07 — Securing the Cluster with RBAC & NetworkPolicies

**Objective:** Implement least-privilege access and pod network isolation.

### Requirements

- Namespace `secured`
- ServiceAccount `app-sa` in `secured`
- Role `pod-reader` with get/list/watch on pods
- RoleBinding binding `app-sa` to `pod-reader`
- NetworkPolicy `deny-all` in `secured`
- NetworkPolicy `allow-frontend` allowing ingress from pods with label `app: frontend`

### Solution

<details>
<summary>Click to expand</summary>

```yaml
# 07-security.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: secured
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: secured
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: secured
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-sa-reader
  namespace: secured
subjects:
  - kind: ServiceAccount
    name: app-sa
    namespace: secured
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: secured
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
  namespace: secured
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
```
</details>

### Verification

```bash
kubectl apply -f 07-security.yaml

# Deploy pods in secured namespace
kubectl run frontend --image=nginx:alpine -n secured -l app=frontend
kubectl run backend --image=nginx:alpine -n secured -l app=backend --port=80
kubectl expose pod backend --port=80 -n secured

# Test connectivity (should work — frontend can reach backend)
kubectl exec -it frontend -n secured -- curl http://backend

# Run a pod without the frontend label (should fail)
kubectl run attacker --image=nginx:alpine -n secured
kubectl exec -it attacker -n secured -- curl http://backend --connect-timeout 5
# This should timeout — NetworkPolicy blocks it

# Test RBAC
kubectl run test -n secured --image=nginx:alpine --serviceaccount=app-sa --rm -it --restart=Never -- /bin/sh -c "
  curl -s --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  -H \"Authorization: Bearer \$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)\" \
  https://kubernetes.default.svc/api/v1/namespaces/secured/pods
"
```

---

## Problem 08 — Ingress with TLS

**Objective:** Expose a service via Ingress with TLS termination.

### Requirements

- 2 Deployments: `app` and `api`
- 2 Services: `app-svc` (port 80), `api-svc` (port 80)
- Ingress `myapp-ingress`:
  - Host: `myapp.local`
  - `/` → `app-svc`
  - `/api` → `api-svc`
  - TLS with a self-signed certificate

### Solution

<details>
<summary>Click to expand</summary>

```yaml
# 08-ingress.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
        - name: app
          image: nginx:alpine
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: app-svc
spec:
  selector:
    app: app
  ports:
    - port: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
        - name: api
          image: nginx:alpine
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: api-svc
spec:
  selector:
    app: api
  ports:
    - port: 80
---
# Generate a self-signed cert:
# openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
#   -keyout tls.key -out tls.crt -subj "/CN=myapp.local"
apiVersion: v1
kind: Secret
metadata:
  name: myapp-tls
type: kubernetes.io/tls
stringData:
  tls.crt: |
    -----BEGIN CERTIFICATE-----
    MIIDXTCCAkUCFDzfAuZfs0pZpRhObwLeQljD8XcLMA0GCSqGSIb3DQEBCwUAMEUx
    CzAJBgNVBAYTAlVTMRMwEQYDVQQIDApDYWxpZm9ybmlhMRIwEAYDVQQHDAlTYW4g
    RGllZ28xDTALBgNVBAMMBG15YXBwMB4XDTI0MDEwMTAwMDAwMFoXDTI1MDEwMTAw
    MDAwMFowRTELMAkGA1UEBhMCVVMxEzARBgNVBAgMCkNhbGlmb3JuaWExEjAQBgNV
    BAcMCVNhbiBEaWVnbzENMAsGA1UEAwwEbXlhcHAwggEiMA0GCSqGSIb3DQEBAQUA
    A4IBDwAwggEKAoIBAQDQr6T2cPbNnH8az1cTIAc+Xw5FYTKJnvH2GJLSE+XZ5D/F
    7pEHlEKQBiYN4S6VdF5kYJsIPMKSgGQ3Y2/MRMLqO13jlIDCNgNPiIVfA1tCz0N+
    h0kjQzDCfSm+2LpQ2mVx5MEhZ+O0Q6EAVT/JmgNb4tqHM0/9xq09A2ofAwbghVG/
    zPzZAYqL78QsHmdOYixWF6gnV3pb+xZHLwZ9VNKawUn/ltk72x7JkPk3TS1+b4z7
    Slv+jEQDB6GnkQjYbFK9gPVq9Uq5YLL9SZICMQ0fEK2OrEqPDxM6MxLOwFnlV3Si
    AgMBAAEwDQYJKoZIhvcNAQELBQADggEBAG/AgKEX3Gh9U0lgG1PfaASJSRqCgZgE
    qCkQNv2h0x0o0ImOaTDqTB27aRQfECMtRKIBn8jQbQXBLqRZ1BZ/gz3hMF30OqHB
    5hfVgJJLH6BgBSsnBcMVa8W3q0t4lx/GQjq3ZOVpMgBq0G5AFRSdl29aBeV6JhJG
    50h28EB7Ak5hRE7a+K7dqX5j3oxGONfKHFhDx89F8aEZ8ByI+sECRi9dULvV7tnQ
    a2A+f1MEnkV8GD/DxLsd6FZS3gI0v1PcK8l+wvGAShl0AzaHcp6i/ZRL/3mhxNgc
    LUPJ/z3SFcYakCWliVPAJCfbIlQLuYAFXQNPy1KHQSjxKEUwFWWyKt8=
    -----END CERTIFICATE-----
  tls.key: |
    -----BEGIN PRIVATE KEY-----
    MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDQr6T2cPbNnH8a
    z1cTIAc+Xw5FYTKJnvH2GJLSE+XZ5D/F7pEHlEKQBiYN4S6VdF5kYJsIPMKSgGQ3
    Y2/MRMLqO13jlIDCNgNPiIVfA1tCz0N+h0kjQzDCfSm+2LpQ2mVx5MEhZ+O0Q6EA
    VT/JmgNb4tqHM0/9xq09A2ofAwbghVG/zPzZAYqL78QsHmdOYixWF6gnV3pb+xZH
    LwZ9VNKawUn/ltk72x7JkPk3TS1+b4z7Slv+jEQDB6GnkQjYbFK9gPVq9Uq5YLL9
    SZICMQ0fEK2OrEqPDxM6MxLOwFnlV3SiAgMBAAECggEAaJL2DIEjTYnZAPQw7R2D
    hqxPbd0BqR1a2/5oX2n5+RQI/lH4mOMC3SMHgFOllKGiWD2BilBfFT65Y58QqL3B
    mRkRxyZQK4U4S3bRLPqrpSlRRtffpQZ8QlIPYqOuz+ApFQ8h0QVmBcE4CrWn4U+m
    U1FfABBDY9pO5s9b9MtaqMYmtm2e97Zln8yMnxE2rBt7Fc1NLfQNcqZ7Xj2zVBCk
    MzCnFUzEQhHy6tOQNULbC5AK85jTB9T5UG7yHrwjY0FqCCHJZ3E/NAITzH9XH6E+
    iGhBVzPNEURl2/slnq0Z2rTCWwNpPKE9/5MbGzCFenHq59kqh7vBC5OYFKezH5TA
    MQKBgQD2uQiw8+WeSSYLqf9n93/dJUCmJXz1IBBexqOhnjC5As3AylMZ8gMaEE2h
    hQ2aP1e2r7k1l8vRBmM9M0XFnq+avE+5VZ5BS/YlAqRxLHBAU7ldS0IT/L9gqGvQ
    OT6F3O45AVLMW+Q1wFf9VpYM9K2UStm1VqROtA3bI5TLGNn2DQKBgQDYsRGcWCmz
    Hj9tl0Amwv+quLLfCEBJpqOzQzVBFj4FNth0ZTRgBm5FNjVXBBRRLm3KkIF9WhA+
    85yTLf1Wq4aOFNcXOPoKVz3Wp3bI1HK5pPE5FHCECQKBDghFS2RqJHTq9LQ4gqHG
    dOD3CAFZPlqSnEqNkTKte3JzAS2M30tW1wKBgQCxYrC2XwF3WbJjCXEPvSDm4VjX
    jjCQ5FU+7JHKYOnYL1bBdQx1j2V9m2LXtPDJ9XyRds0VB6wF9aGJ5Lq1OvnXjBn4
    LvXUQCgYI2bqIXmxxJ/z0YNKYJ/W9YLstvPLjfVFxns9pwWsnxLFF2SnIh8FPrU0
    xIcuJ8rqDHhCn2Mx6QKBgD7R74W7eZn5g3W3THqRxG/3I+zgTaLFo1QUO4+ntLCS
    Bf9CnE06n8yTxes3LLP3vRfh8WHo0i0dPm6UASOUflBPgOqTSArqrwBqcjhFSJxV
    UQ7aYLQ1hHB9DQcFy2gnGnGgjkxQMQOOkld6rZ4N35cCq3nRplxYRZQNBBzTKeJv
    AoGAdg+khFmI81qkYLdBSx3Md3TE3aqhF5DNN4j94Gp5vV6HeS/YbFPQ7rTpN2v+
    cuQvwQ7xtFB0bnllS8dMBBh49rJh5WDHe2zYgQ1+LVrjR1YYftN4AOYjysqWs6wD
    /WzZWMFrA2/D/Xu41VCADCHnQMN3mHyG2ERQBP87aYQcLBU=
    -----END PRIVATE KEY-----
---
# Enable ingress addon in minikube: minikube addons enable ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - myapp.local
      secretName: myapp-tls
  rules:
    - host: myapp.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-svc
                port:
                  number: 80
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: api-svc
                port:
                  number: 80
```
</details>

### Verification

```bash
# Enable ingress
minikube addons enable ingress

kubectl apply -f 08-ingress.yaml

# Wait for ingress to get an address
kubectl get ingress -w

# Add to hosts file (Windows: C:\Windows\System32\drivers\etc\hosts)
# <minikube ip> myapp.local

# Test
curl -k https://myapp.local
curl -k https://myapp.local/api

# Without TLS
# curl http://myapp.local
```

---

## Problem 09 — Multi-Container Pod with Sidecar

**Objective:** Create a pod with a main app and a sidecar container.

### Requirements

- Pod `web-with-logger`
- Main container `web`: nginx serving on port 80
- Sidecar `logger`: busybox that tails nginx logs and outputs them
- Shared emptyDir volume `logs` mounted at `/var/log/nginx` (web) and `/logs` (sidecar)

### Solution

<details>
<summary>Click to expand</summary>

```yaml
# 09-sidecar.yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-with-logger
  labels:
    app: web-with-logger
spec:
  containers:
    - name: web
      image: nginx:alpine
      ports:
        - containerPort: 80
      volumeMounts:
        - name: logs
          mountPath: /var/log/nginx

    - name: logger
      image: busybox
      command:
        - /bin/sh
        - -c
        - |
          echo "=== Sidecar Logger Started ==="
          tail -f /logs/access.log /logs/error.log
      volumeMounts:
        - name: logs
          mountPath: /logs

  volumes:
    - name: logs
      emptyDir: {}

---
apiVersion: v1
kind: Service
metadata:
  name: web-with-logger
spec:
  selector:
    app: web-with-logger
  ports:
    - port: 80
```
</details>

### Verification

```bash
kubectl apply -f 09-sidecar.yaml

# Generate traffic
kubectl port-forward pod/web-with-logger 8080:80 &
curl http://localhost:8080

# Watch sidecar logs (show nginx access logs)
kubectl logs web-with-logger -c logger -f

# Check both containers
kubectl describe pod web-with-logger
kubectl exec web-with-logger -c web -- ls /var/log/nginx
kubectl exec web-with-logger -c logger -- ls /logs
```

---

## Problem 10 — Helm Chart Authoring

**Objective:** Create a reusable Helm chart for the web app.

### Requirements

- Chart name: `myapp`
- Templates: deployment.yaml, service.yaml, configmap.yaml, ingress.yaml, _helpers.tpl
- Configurable: replicaCount, image, service, ingress, resources
- values.yaml with sensible defaults
- Include NOTES.txt with post-install instructions

### Solution

<details>
<summary>Click to expand</summary>

Create the chart structure:

```bash
mkdir -p helm-charts/myapp/templates
touch helm-charts/myapp/{Chart.yaml,values.yaml,values.schema.json}
```

```yaml
# helm-charts/myapp/Chart.yaml
apiVersion: v2
name: myapp
description: A configurable web application
type: application
version: 0.1.0
appVersion: "1.0.0"
```

```yaml
# helm-charts/myapp/values.yaml
replicaCount: 2

image:
  repository: nginx
  tag: alpine
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: false
  className: ""
  hosts:
    - host: myapp.local
      paths:
        - path: /
          pathType: Prefix
  tls: []

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

configmap:
  data:
    NODE_ENV: production
    LOG_LEVEL: info
```

```yaml
# helm-charts/myapp/values.schema.json
{
  "$schema": "https://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "replicaCount": {
      "type": "integer",
      "minimum": 1
    },
    "image": {
      "type": "object",
      "properties": {
        "repository": { "type": "string" },
        "tag": { "type": "string" },
        "pullPolicy": { "type": "string" }
      }
    },
    "service": {
      "type": "object",
      "properties": {
        "type": { "type": "string" },
        "port": { "type": "integer" }
      }
    }
  },
  "required": ["replicaCount", "image", "service"]
}
```

Create the templates:

```yaml
# helm-charts/myapp/templates/_helpers.tpl
{{- define "myapp.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "myapp.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "myapp.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "myapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "myapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "myapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "myapp.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "myapp.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}
```

```yaml
# helm-charts/myapp/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "myapp.fullname" . }}
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "myapp.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "myapp.selectorLabels" . | nindent 8 }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.service.port }}
          envFrom:
            - configMapRef:
                name: {{ include "myapp.fullname" . }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
```

```yaml
# helm-charts/myapp/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "myapp.fullname" . }}
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  selector:
    {{- include "myapp.selectorLabels" . | nindent 4 }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.port }}
      protocol: TCP
```

```yaml
# helm-charts/myapp/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "myapp.fullname" . }}
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
data:
  {{- range $key, $value := .Values.configmap.data }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
```

```yaml
# helm-charts/myapp/templates/ingress.yaml
{{- if .Values.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "myapp.fullname" . }}
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
spec:
  ingressClassName: {{ .Values.ingress.className }}
  {{- if .Values.ingress.tls }}
  tls:
    {{- range .Values.ingress.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ include "myapp.fullname" $ }}
                port:
                  number: {{ $.Values.service.port }}
          {{- end }}
    {{- end }}
{{- end }}
```

```txt
# helm-charts/myapp/templates/NOTES.txt
Thank you for installing {{ .Chart.Name }}!

Release name: {{ .Release.Name }}
Namespace: {{ .Release.Namespace }}
Application version: {{ .Chart.AppVersion }}

Get the application URL by running:
kubectl get svc {{ include "myapp.fullname" . }}
```
</details>

### Verification

```bash
# Lint the chart
helm lint helm-charts/myapp

# Template (dry run)
helm template test-release helm-charts/myapp

# Install
helm install my-release helm-charts/myapp --namespace myapp --create-namespace

# Install with overrides
helm install my-release helm-charts/myapp \
  --set replicaCount=3 \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=app.example.com

# Verify
helm list -n myapp
kubectl get all -n myapp

# Upgrade
helm upgrade my-release helm-charts/myapp -f prod-values.yaml

# Rollback
helm rollback my-release 1

# Uninstall
helm uninstall my-release
```

---

## Problem 11 — Cluster Troubleshooting

**Objective:** Diagnose and fix common Kubernetes issues.

### Scenario 1: Pod stuck in Pending

```bash
kubectl get events --sort-by='.lastTimestamp' | tail -20
kubectl describe pod <pod-name>
kubectl describe node
kubectl get pvc               # Check PVC status
kubectl describe pvc          # Check PVC events
```

**Common fixes:**

| Issue | Fix |
|-------|-----|
| No node available | Check node status, uncordon, add nodes |
| Insufficient CPU/memory | Reduce requests, add nodes |
| PVC not bound | Create PV, check StorageClass |
| Failed pulling image | Check image name, registry credentials |
| Taints/tolerations mismatch | Add toleration to pod or remove taint |

### Scenario 2: CrashLoopBackOff

```bash
kubectl logs <pod> --previous
kubectl describe pod <pod> | grep -A 10 "Last State"
kubectl logs <pod> -c <container>
```

**Fixes:**

| Exit code | Likely cause | Fix |
|-----------|-------------|-----|
| 137 (OOM) | Out of memory | Increase memory limit |
| 143 (SIGTERM) | Pod killed, usually graceful | Check graceful shutdown |
| 1 | Application error | Fix app code, check config |
| 139 (SIGSEGV) | Segmentation fault | Bug in app, check memory |
| 127 | Command not found | Fix container command/entrypoint |

### Scenario 3: Service not accessible

```bash
kubectl get endpoints                    # Are there endpoints?
kubectl get pods -l <selector> -w       # Pods match selector?
kubectl describe svc <name>             # Check selector and ports
kubectl get networkpolicies             # Blocking traffic?
kubectl exec -it debug-pod -- curl http://<service-name>
```

**Fixes:**

| Issue | Fix |
|-------|-----|
| No endpoints | Fix pod labels to match Service selector |
| Wrong port | Update Service port/targetPort |
| NetworkPolicy blocking | Update policy to allow traffic |
| DNS not resolving | Check CoreDNS, `nslookup <service>.default.svc.cluster.local` |

### Scenario 4: API server unreachable

```bash
kubectl cluster-info
kubectl config view
minikube status
kubectl get nodes
```

**Fixes:**

| Issue | Fix |
|-------|-----|
| Wrong context | `kubectl config use-context <name>` |
| Minikube stopped | `minikube start` |
| API server crashed | Check control plane, restart |
| Firewall blocking | Check security group rules |

---

## Problem 12 — Disaster Recovery

**Objective:** Back up and restore a namespace.

### Step 1: Export all resources in a namespace

```bash
# Export all resources in namespace
kubectl get all -n myapp -o yaml > myapp-backup.yaml
kubectl get configmap,secret,serviceaccount,role,rolebinding -n myapp -o yaml >> myapp-backup.yaml
kubectl get pvc -n myapp -o yaml > myapp-pvc-backup.yaml
```

### Step 2: Back up with Velero (recommended)

```bash
# Install Velero
velero install \
  --provider aws \
  --bucket kubernetes-backups \
  --backup-location-config region=us-east-1

# Backup a namespace
velero backup create myapp-backup --include-namespaces myapp

# Schedule regular backups
velero schedule create daily-backup --schedule="0 1 * * *" --include-namespaces myapp --ttl=72h

# Restore
velero restore create --from-backup myapp-backup

# List backups
velero backup get
```

### Step 3: Restore from scratch

```bash
# Recreate namespace
kubectl create namespace myapp

# Apply exported YAML
kubectl apply -f myapp-backup.yaml -n myapp

# For PVCs, check if PVs still exist
kubectl get pv
kubectl apply -f myapp-pvc-backup.yaml -n myapp

# For StatefulSets with data, restore from database backup
kubectl exec -it postgres-0 -- psql -U myapp -d myapp < database_dump.sql
```

---

## Quick Reference

### Essential Debugging Chain

```bash
# 1. Check pod status
kubectl get pods -o wide

# 2. Describe the problem
kubectl describe pod <name>

# 3. Check logs
kubectl logs <name>
kubectl logs <name> --previous

# 4. Check events
kubectl get events --sort-by='.lastTimestamp'

# 5. Check resources
kubectl top pod
kubectl top node

# 6. Check services
kubectl get endpoints
kubectl describe svc <name>
```

### Common kubectl One-Liners

```bash
# Delete all failed pods
kubectl delete pod --field-selector=status.phase=Failed

# Get pod IPs
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}'

# Check image versions
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'

# Watch all resources
kubectl get pods,svc,deployments -w

# Get resource usage by namespace
kubectl top pod --all-namespaces

# Show labels
kubectl get pods --show-labels

# Force delete a pod
kubectl delete pod <name> --grace-period=0 --force
```

---

This concludes the Kubernetes documentation series. You've gone from fundamentals through advanced topics — architecture, workloads, networking, configuration, storage, security, Helm, and practical debugging. Apply these concepts in your own projects to build real muscle memory.
