---
layout: guide-lesson.liquid
title: Final Validation Before Decommissioning

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 5
guide_lesson_id: 22
guide_lesson_abstract: >
  Perform comprehensive validation of Cluster B before decommissioning the k3s cluster.
guide_lesson_conclusion: >
  Cluster B is fully validated and ready for the final phase of migration.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-22.md
---

Before decommissioning Cluster A, perform thorough validation of Cluster B to ensure you won't need to rollback.

{% include guide-overview-link.liquid.html %}

## Validation Timeline

After the DNS cutover, allow time for confidence building:

| Time Since Cutover | Focus                                 |
| ------------------ | ------------------------------------- |
| 0-4 hours          | Active monitoring, quick fixes        |
| 4-24 hours         | Extended monitoring, verify stability |
| 24-48 hours        | Final validation                      |
| 48+ hours          | Ready for decommissioning             |

## Current State

```mermaid!
flowchart LR
  subgraph A["Cluster A · k3s"]
    A1["🧠 Node 1<br/><small>standby</small>"]
  end

  subgraph B["Cluster B · RKE2"]
    B2["🧠 Node 2"]
    B3["🧠 Node 3"]
    B4["🧠 Node 4"]
  end

  Traffic["🌐 Traffic"] --> B

  classDef clusterA fill:#9ca3af,color:#fff,stroke:#6b7280
  classDef clusterB fill:#16a34a,color:#fff,stroke:#166534

  class A clusterA
  class B clusterB
```

Cluster A remains on standby for rollback while Cluster B serves all traffic.

## Validation Areas

### Cluster Health

Verify all core components are healthy:

```bash
# All nodes Ready
kubectl get nodes

# etcd cluster healthy
etcdctl endpoint health --cluster

# All system pods Running
kubectl get pods -n kube-system
```

### Workload Health

Check application workloads:

```bash
# All pods Running (no CrashLoopBackOff, Pending, etc.)
kubectl get pods -A | grep -v Running | grep -v Completed

# No excessive restarts
kubectl get pods -A | awk '$5 > 5'

# All deployments at desired replicas
kubectl get deployments -A
```

### Storage Health

Verify persistent storage:

```bash
# All PVCs bound
kubectl get pvc -A | grep -v Bound

# Longhorn healthy
kubectl get pods -n longhorn-system
```

### Network Health

Check networking and ingress:

```bash
# Canal healthy
kubectl get pods -n kube-system -l k8s-app=canal

# Traefik running on all nodes
kubectl get pods -n traefik -o wide

# Load balancer targets healthy
hcloud load-balancer describe k8s-ingress
```

### Application Testing

Run application-specific tests:

- Health check endpoints
- Database connectivity
- Critical user flows
- API functionality

## Decision Point

**If validation passes:** Proceed to decommissioning Cluster A.

**If validation fails:**

- Document issues
- Fix problems before proceeding
- Re-validate after fixes
- Consider rollback if issues are severe

## Validation Checklist

### Infrastructure

- [ ] All 3 control plane nodes healthy
- [ ] etcd cluster healthy (3 members)
- [ ] All nodes have sufficient resources

### Workloads

- [ ] All pods Running
- [ ] No excessive restarts
- [ ] All services have endpoints

### Storage

- [ ] All PVCs bound
- [ ] Longhorn healthy

### Networking

- [ ] Canal healthy
- [ ] Ingress working
- [ ] Load balancer healthy

### Applications

- [ ] Health checks passing
- [ ] No application errors
- [ ] User-facing functionality working

In the next lesson, we'll safely decommission Cluster A.
