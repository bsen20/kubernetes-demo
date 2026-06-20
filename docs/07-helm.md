# 07 — Helm

> The Kubernetes package manager — Charts, Templates, Releases, and Best Practices

---

## Table of Contents

1. [What is Helm?](#what-is-helm)
2. [Helm Architecture](#helm-architecture)
3. [Core Concepts](#core-concepts)
4. [Helm Charts](#helm-charts)
5. [Templating](#templating)
6. [Chart Repository](#chart-repository)
7. [Helmfile & Advanced Deployment](#helmfile--advanced-deployment)
8. [Best Practices](#best-practices)

---

## What is Helm?

Helm is the package manager for Kubernetes. It packages YAML manifests into reusable **charts** and manages **releases**.

```bash
# Install Helm on Windows (Chocolatey)
choco install kubernetes-helm

# Verify
helm version

# Quick start — install a chart
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install my-release bitnami/nginx

# List releases
helm list

# Uninstall
helm uninstall my-release
```

### Why Helm?

| Problem | Helm Solution |
|---------|--------------|
| **Copy-pasting YAML** | Reusable chart templates |
| **Environment differences** | Values override per env |
| **No versioning** | `helm list`, `helm rollback` |
| **Complex applications** | Dependency management |
| **No standard packaging** | Chart format (standardized) |

---

## Helm Architecture

```mermaid
flowchart LR
    subgraph Local[Your Machine]
        Helm[Helm CLI]
        Values[values.yaml]
    end
    subgraph Remote[Remote]
        Repo[Chart Repository<br/>artifacthub.io / ECR / OCI]
    end
    subgraph Cluster[Kubernetes Cluster]
        Tiller[Helm 2: Tiller<br/>(removed in Helm 3)]
        API[Kubernetes API]
    end
    Helm -->|helm install| API
    Helm -->|helm package| Repo
    Values -->|--values prod.yaml| Helm
```

### Helm 3 vs Helm 2

| Feature | Helm 2 | Helm 3 |
|---------|--------|--------|
| Server component | Tiller (in-cluster) | ❌ Removed |
| Security | Tiller has broad permissions | Uses kubeconfig (your permissions) |
| Release storage | ConfigMaps in Tiller's NS | Secrets in release namespace |
| CRD handling | Manual | Improved |
| OCI support | ❌ | ✅ |

---

## Core Concepts

| Concept | Description | Analogy |
|---------|-------------|---------|
| **Chart** | Package of pre-configured K8s resources | `.deb` / `.rpm` |
| **Release** | A deployed instance of a chart | Running program |
| **Repository** | Collection of published charts | APT / YUM repo |
| **Values** | Configuration overrides for a chart | Config file |
| **Template** | Go template with K8s YAML | Blueprint |

---

## Helm Charts

### Chart Structure

```
my-chart/
├── .helmignore              # Files to exclude (like .gitignore)
├── Chart.yaml               # Metadata (name, version, dependencies)
├── values.yaml              # Default configuration values
├── values.schema.json       # Optional JSON schema for values validation
├── charts/                  # Sub-charts (dependencies)
│   └── redis/               # Bundled dependency chart
├── templates/               # Go template files
│   ├── NOTES.txt            # Post-install instructions
│   ├── _helpers.tpl         # Reusable template helpers
│   ├── deployment.yaml      # Deployment template
│   ├── service.yaml         # Service template
│   ├── ingress.yaml         # Ingress template
│   ├── configmap.yaml       # ConfigMap template
│   ├── secret.yaml          # Secret template
│   ├── hpa.yaml             # HorizontalPodAutoscaler
│   ├── pvc.yaml             # PersistentVolumeClaim
│   └── tests/               # Test templates
│       └── test-connection.yaml
└── crds/                    # CustomResourceDefinitions (installed first)
    └── my-crd.yaml
```

### Chart.yaml

```yaml
apiVersion: v2                          # v2 for Helm 3+
name: myapp
description: A production-ready web application
version: 1.2.0                          # Chart version
appVersion: "2.5.0"                     # Application version
type: application                       # application | library

dependencies:
  - name: redis
    version: ">=17.0.0"
    repository: "https://charts.bitnami.com/bitnami"
    condition: redis.enabled            # Only install if true
    tags:
      - cache
  - name: postgresql
    version: "~12.0.0"
    repository: "oci://registry-1.docker.io/bitnamicharts"
    alias: postgres
    import-values:                       # Import child chart values
      - child: defaults
        parent: postgres
```

```bash
# Download chart dependencies
helm dependency update my-chart/

# Build dependencies (copy to charts/)
helm dependency build my-chart/
```

### values.yaml

```yaml
# Default values — overridden per environment
replicaCount: 3

image:
  repository: myapp
  tag: "2.5.0"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 8080

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: myapp.example.com
      paths:
        - path: /
          pathType: Prefix

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

redis:
  enabled: true
  architecture: standalone
  auth:
    enabled: true
    password: ""
  master:
    persistence:
      size: 8Gi

postgres:
  enabled: true
  global:
    postgresql:
      auth:
        database: myapp
        username: myapp
```

---

## Templating

Helm uses Go templates to generate Kubernetes YAML.

### Basic Template

```yaml
# templates/deployment.yaml
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
          env:
            - name: NODE_ENV
              value: {{ .Values.environment | default "production" }}
            - name: REDIS_URL
              value: {{ template "myapp.redisUrl" . }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
```

### Built-in Variables

| Variable | Description |
|----------|-------------|
| `.Values` | Values from values.yaml + `--set` |
| `.Chart` | Chart.yaml metadata |
| `.Release` | Release info (Name, Namespace, Service, IsUpgrade, IsInstall) |
| `.Files` | Access files packaged in the chart |
| `.Capabilities` | Cluster capabilities (API versions, K8s version) |
| `.Template` | Template metadata (Name, BasePath) |

### Helper Templates (`_helpers.tpl`)

```yaml
{{- define "myapp.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "myapp.labels" -}}
helm.sh/chart: {{ include "myapp.fullname" . }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "myapp.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "myapp.redisUrl" -}}
{{- if .Values.redis.enabled -}}
redis://{{ .Release.Name }}-redis-master:6379
{{- else -}}
{{ .Values.externalRedisUrl }}
{{- end -}}
{{- end -}}
```

### Template Functions & Pipelines

```yaml
# Default values
port: {{ .Values.service.port | default 8080 }}

# Quotes & escaping
name: {{ .Values.name | quote }}

# Upper / lower case
env: {{ .Values.environment | upper }}

# Indent / nindent
{{- toYaml .Values.resources | nindent 6 }}

# Conditionals
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
{{- end }}

# Ranges (loops)
{{- range .Values.ingress.hosts }}
  - host: {{ .host | quote }}
    http:
      paths:
      {{- range .paths }}
        - path: {{ .path }}
          pathType: {{ .pathType }}
      {{- end }}
{{- end }}

# With (enter object scope)
{{- with .Values.service }}
type: {{ .type }}
port: {{ .port }}
{{- end }}

# Include named templates
labels:
  {{- include "myapp.labels" . | nindent 4 }}

# tpl (render a string template from values)
hook: {{ tpl .Values.hookTemplate . }}

# fail (stop rendering with error)
{{- if not (semverCompare ">=1.19" .Capabilities.KubeVersion.Version) }}
{{- fail "Requires Kubernetes 1.19+" }}
{{- end }}
```

### Flow Control

```yaml
# if / else / end
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
{{- else if .Values.replicas }}
replicas: {{ .Values.replicas }}
{{- end }}

# with / end
{{- with .Values.database }}
host: {{ .host | required "database.host is required" }}
port: {{ .port | default 5432 }}
name: {{ .name }}
{{- end }}

# range / end
env:
{{- range $key, $value := .Values.envVars }}
  - name: {{ $key }}
    value: {{ $value | quote }}
{{- end }}
```

### Helm Template Debugging

```bash
# Render templates locally (does not install)
helm template my-release ./my-chart

# Render with custom values
helm template my-release ./my-chart -f prod-values.yaml

# Show computed values
helm get values my-release

# Dry run install
helm install my-release ./my-chart --dry-run --debug

# Check syntax
helm lint ./my-chart
```

---

## Chart Repository

### Working with Repositories

```bash
# Add a repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add stable https://charts.helm.sh/stable

# List repositories
helm repo list

# Search charts
helm search repo bitnami/nginx
helm search hub nginx                    # Artifact Hub search

# Update local cache
helm repo update

# Remove a repository
helm repo remove bitnami

# Package a chart
helm package ./my-chart/ -d ./packages/

# Index a repository (for hosting)
helm repo index ./packages/
```

### OCI Registries

```bash
# Helm charts can be stored in OCI-compatible registries
helm chart pull oci://registry-1.docker.io/bitnamicharts/nginx
helm chart export bitnamicharts/nginx --destination ./charts/

# Push your own chart
helm package ./my-chart/
helm chart push my-chart-1.2.0.tgz oci://myregistry.example.com/charts
```

### Chart Lifecycle

```bash
# Install a release
helm install my-release bitnami/nginx --namespace myapp --create-namespace

# Upgrade a release
helm upgrade my-release bitnami/nginx --set replicaCount=5

# Upgrade with values file
helm upgrade my-release ./my-chart -f prod-values.yaml

# Rollback to a previous revision
helm rollback my-release 2

# See revision history
helm history my-release

# Uninstall (keeps history by default)
helm uninstall my-release
helm uninstall my-release --keep-history

# Status
helm status my-release
```

### Release Names & Revisions

```bash
helm list -a                            # All namespaces
helm list -n myapp                      # Specific namespace
helm list --all --max=10                # Max 10 per namespace

# Revision example
# Revision 1: helm install my-release
# Revision 2: helm upgrade my-release --set image.tag=v2
# Revision 3: helm rollback my-release 1
```

---

## Helmfile & Advanced Deployment

### Helmfile

Helmfile helps manage multiple Helm releases declaratively.

```yaml
# helmfile.yaml
repositories:
  - name: bitnami
    url: https://charts.bitnami.com/bitnami
  - name: ingress-nginx
    url: https://kubernetes.github.io/ingress-nginx

releases:
  - name: ingress-nginx
    namespace: ingress
    chart: ingress-nginx/ingress-nginx
    version: "4.7.0"
    values:
      - controller:
          replicaCount: 2

  - name: myapp
    namespace: default
    chart: ./charts/myapp
    values:
      - values/{{ .Environment.Name }}/myapp.yaml
    secrets:
      - secrets/{{ .Environment.Name }}/myapp.yaml
    depends:
      - postgres
      - redis

  - name: postgres
    namespace: default
    chart: bitnami/postgresql
    version: "12.x"
    installed: true
    values:
      - values/{{ .Environment.Name }}/postgres.yaml

environments:
  dev:
    values:
      - environments/dev.yaml
  prod:
    values:
      - environments/prod.yaml
```

```bash
helmfile apply                          # Diff + apply changes
helmfile diff                           # Show pending changes
helmfile status                         # Show release statuses
helmfile destroy                        # Uninstall all releases
```

### Multi-Environment Values

```yaml
# values/dev.yaml
replicaCount: 1
environment: dev
resources:
  requests:
    cpu: 100m
    memory: 128Mi
```

```yaml
# values/prod.yaml
replicaCount: 5
environment: prod
resources:
  requests:
    cpu: 500m
    memory: 512Mi
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
ingress:
  enabled: true
```

---

## Best Practices

### Chart Organization

- Follow [Helm best practices guide](https://helm.sh/docs/chart_best_practices/)
- Use `values.schema.json` for validation
- Break large charts into sub-charts
- Use `library` charts for shared helpers
- Keep `Chart.yaml` version synchronized with your release process

### Values Management

```yaml
# Always use nested keys for organization
global:
  environment: production
  imagePullSecret: regcred

app:
  image: myapp
  tag: "1.0"
  replicas: 3

monitoring:
  enabled: true
  prometheus:
    port: 9090
```

### Security

- Never hardcode secrets in `values.yaml`
- Use `--set` or secrets management tools (Sealed Secrets, External Secrets Operator)
- Set `allowPrivilegeEscalation: false` by default
- Use `readOnlyRootFilesystem: true` where possible
- Pin chart versions (never use `latest`)

### CI/CD Integration

```yaml
# .github/workflows/deploy.yaml
- name: Deploy with Helm
  run: |
    helm upgrade --install my-release ./my-chart \
      --namespace myapp \
      --create-namespace \
      --values values/${{ github.ref_name }}.yaml \
      --set image.tag=${{ github.sha }} \
      --atomic \
      --timeout 5m \
      --wait
```

### Production CI Pipeline

```yaml
stages:
  - helm lint ./charts/*
  - helm template my-release ./charts/myapp | kubeval
  - helm upgrade --install --dry-run
  - helm upgrade --install --atomic --wait
  - helm test my-release
```

### Best Practices Checklist

| Area | Practice |
|------|----------|
| **Naming** | Use `include` for consistent naming |
| **Dependencies** | Pin versions, use `helm dependency update` |
| **Templates** | Prefer `nindent` over `indent` |
| **Values** | Always provide defaults in `values.yaml` |
| **Validation** | Use `values.schema.json` + `required` function |
| **Testing** | Include `templates/tests/` |
| **Hooks** | Use installation hooks sparingly |
| **Upgrades** | Test `helm upgrade` before `helm install` |
| **Secrets** | Never commit plain secrets |
| **Versioning** | Follow semver for chart + app versions |

---

## Common Commands Reference

```bash
# Quick reference
helm repo add <name> <url>
helm repo update
helm search repo <keyword>
helm install <release> <chart>
helm upgrade <release> <chart>
helm rollback <release> <revision>
helm uninstall <release>
helm list
helm status <release>
helm history <release>
helm template <release> <chart>
helm lint <chart>
helm package <chart>
helm dependency update
helm get values <release>
helm test <release>
```

---

## Summary

Helm solves configuration management at scale:

| Concept | Why It Matters |
|---------|---------------|
| **Charts** | Reusable, versioned application packages |
| **Templates** | Dynamic YAML generation with Go templating |
| **Values** | Environment-specific configuration |
| **Releases** | Tracked, versioned, rollbackable deployments |
| **Repositories** | Share and distribute charts |

---

## Next Steps

→ [08 — Commands Reference](./08-commands-reference.md)
