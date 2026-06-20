# Kubernetes Documentation

Comprehensive Kubernetes reference — fundamentals through production patterns.

## Contents

| # | Document | Description |
|---|----------|-------------|
| 01 | [Fundamentals](./01-kubernetes-fundamentals.md) | Architecture, control plane, node components, cluster networking, installation |
| 02 | [Pods & Containers](./02-pods-and-containers.md) | Pod lifecycle, init containers, sidecars, probes, resource management |
| 03 | [Workload Resources](./03-workload-resources.md) | Deployment, StatefulSet, DaemonSet, Job, CronJob |
| 04 | [Services & Networking](./04-services-and-networking.md) | Service types, Ingress, DNS, Network Policies |
| 05 | [Configuration & Secrets](./05-configuration-and-secrets.md) | ConfigMaps, Secrets, ServiceAccounts, RBAC, security context |
| 06 | [Storage](./06-storage.md) | Volumes, PV/PVC, StorageClass, Stateful storage patterns |
| 07 | [Helm](./07-helm.md) | Charts, templating, repositories, helmfile, best practices |
| 08 | [Commands Reference](./08-commands-reference.md) | kubectl, minikube, helm quick-reference with aliases |
| 09 | [Interview Questions](./09-interview-questions.md) | 50+ Q&A from fundamentals to senior-level architecture |
| 10 | [Practical Problems](./10-practical-problems.md) | 12 hands-on exercises with solutions and debugging guides |

## Quick Start

```bash
# Read in order for progressive learning, or jump to any topic
less 01-kubernetes-fundamentals.md
```

## Related

- [Project README](../README.md) — project overview and API docs
- [Kubernetes manifests](../k8s/) — example YAML files
