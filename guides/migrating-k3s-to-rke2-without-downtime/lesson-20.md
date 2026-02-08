---
layout: guide-lesson.liquid
title: Deploying Workloads to Cluster B

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 4
guide_lesson_id: 20
guide_lesson_abstract: >
  Deploy all application workloads from the exported manifests to Cluster B and verify functionality.
guide_lesson_conclusion: >
  All workloads are deployed and running on Cluster B, ready for traffic cutover.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-20.md
---

With storage configured and data migrated, we'll now deploy all workloads to Cluster B using the exported manifests.

{% include guide-overview-link.liquid.html %}

## Deployment Strategy

We'll deploy in this order to ensure dependencies are met:

1. **Namespaces** - Create isolated environments
2. **RBAC** - Service accounts and permissions
3. **Secrets and ConfigMaps** - Configuration data
4. **PersistentVolumeClaims** - Storage requests
5. **Services** - Network endpoints
6. **Deployments/StatefulSets** - Application workloads
7. **Ingress** - External access
8. **Network Policies** - Security rules

## Connect to Cluster B

```bash
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
cd /root/cluster-a-export
```

## 1. Deploy Namespaces

```bash
# Review namespaces
ls namespaces/

# Apply all namespace definitions
for ns in namespaces/*.yaml; do
    echo "Creating namespace from $ns"
    kubectl apply -f "$ns"
done

# Verify
kubectl get namespaces
```

## 2. Deploy RBAC Resources

```bash
# Apply service accounts
if [ -d "other/serviceaccounts" ]; then
    for ns_dir in other/serviceaccounts/*/; do
        ns=$(basename "$ns_dir")
        for sa in "$ns_dir"*.yaml; do
            if [ -f "$sa" ]; then
                echo "Creating service account from $sa"
                kubectl apply -f "$sa"
            fi
        done
    done
fi

# Apply cluster-level RBAC
if [ -f "other/clusterroles.yaml" ]; then
    kubectl apply -f other/clusterroles.yaml
fi
if [ -f "other/clusterrolebindings.yaml" ]; then
    kubectl apply -f other/clusterrolebindings.yaml
fi
```

## 3. Deploy Secrets and ConfigMaps

```bash
# Deploy ConfigMaps first (less sensitive)
for ns_dir in configmaps/*/; do
    ns=$(basename "$ns_dir")
    echo "=== Deploying ConfigMaps for namespace: $ns ==="
    for cm in "$ns_dir"*.yaml; do
        if [ -f "$cm" ]; then
            kubectl apply -f "$cm"
        fi
    done
done

# Deploy Secrets (handle carefully)
for ns_dir in secrets/*/; do
    ns=$(basename "$ns_dir")
    echo "=== Deploying Secrets for namespace: $ns ==="
    for secret in "$ns_dir"*.yaml; do
        if [ -f "$secret" ]; then
            kubectl apply -f "$secret"
        fi
    done
done

# Verify
kubectl get configmaps -A | grep -v kube-system
kubectl get secrets -A | grep -v kube-system | grep -v service-account-token
```

## 4. Deploy PersistentVolumeClaims

```bash
# Deploy PVCs
for ns_dir in pvc/*/; do
    if [ -d "$ns_dir" ]; then
        ns=$(basename "$ns_dir")
        echo "=== Deploying PVCs for namespace: $ns ==="
        for pvc in "$ns_dir"*.yaml; do
            if [ -f "$pvc" ]; then
                # Update storage class if needed
                # sed -i 's/storageClassName: old-class/storageClassName: longhorn/' "$pvc"
                kubectl apply -f "$pvc"
            fi
        done
    fi
done

# Wait for PVCs to be bound (Longhorn)
echo "Waiting for PVCs to be bound..."
kubectl get pvc -A | grep -v Bound | grep -v NAME

# Verify
kubectl get pvc -A
```

## 5. Deploy Services

```bash
# Deploy services (before deployments so DNS is ready)
for ns_dir in services/*/; do
    ns=$(basename "$ns_dir")
    echo "=== Deploying Services for namespace: $ns ==="
    for svc in "$ns_dir"*.yaml; do
        if [ -f "$svc" ]; then
            kubectl apply -f "$svc"
        fi
    done
done

# Verify
kubectl get svc -A | grep -v kube-system
```

## 6. Deploy Stateful Workloads First

Deploy StatefulSets before Deployments (databases before apps):

```bash
# Deploy StatefulSets
for ns_dir in statefulsets/*/; do
    ns=$(basename "$ns_dir")
    echo "=== Deploying StatefulSets for namespace: $ns ==="
    for sts in "$ns_dir"*.yaml; do
        if [ -f "$sts" ]; then
            kubectl apply -f "$sts"
        fi
    done
done

# Wait for StatefulSets to be ready
for ns_dir in statefulsets/*/; do
    ns=$(basename "$ns_dir")
    for sts in "$ns_dir"*.yaml; do
        if [ -f "$sts" ]; then
            sts_name=$(yq e '.metadata.name' "$sts")
            echo "Waiting for StatefulSet $ns/$sts_name..."
            kubectl rollout status statefulset/$sts_name -n $ns --timeout=300s || true
        fi
    done
done
```

## 7. Deploy Deployments

```bash
# Deploy Deployments
for ns_dir in deployments/*/; do
    ns=$(basename "$ns_dir")
    echo "=== Deploying Deployments for namespace: $ns ==="
    for dep in "$ns_dir"*.yaml; do
        if [ -f "$dep" ]; then
            kubectl apply -f "$dep"
        fi
    done
done

# Wait for Deployments
for ns_dir in deployments/*/; do
    ns=$(basename "$ns_dir")
    for dep in "$ns_dir"*.yaml; do
        if [ -f "$dep" ]; then
            dep_name=$(yq e '.metadata.name' "$dep")
            echo "Waiting for Deployment $ns/$dep_name..."
            kubectl rollout status deployment/$dep_name -n $ns --timeout=300s || true
        fi
    done
done
```

## 8. Deploy DaemonSets and CronJobs

```bash
# Deploy DaemonSets
if [ -d "other/daemonsets" ]; then
    for ns_dir in other/daemonsets/*/; do
        ns=$(basename "$ns_dir")
        for ds in "$ns_dir"*.yaml; do
            if [ -f "$ds" ]; then
                echo "Deploying DaemonSet from $ds"
                kubectl apply -f "$ds"
            fi
        done
    done
fi

# Deploy CronJobs
if [ -d "other/cronjobs" ]; then
    for ns_dir in other/cronjobs/*/; do
        ns=$(basename "$ns_dir")
        for cj in "$ns_dir"*.yaml; do
            if [ -f "$cj" ]; then
                echo "Deploying CronJob from $cj"
                kubectl apply -f "$cj"
            fi
        done
    done
fi
```

## 9. Deploy Ingress Resources

Before deploying ingress, update annotations for Traefik:

```bash
# Review ingress files for k3s-specific annotations
grep -r "kubernetes.io/ingress.class" ingress/
grep -r "traefik" ingress/

# Update if needed (k3s Traefik annotations should work)
# For Traefik 2.x/3.x, use:
# annotations:
#   traefik.ingress.kubernetes.io/router.entrypoints: websecure
#   traefik.ingress.kubernetes.io/router.tls: "true"

# Deploy ingress resources
for ns_dir in ingress/*/; do
    ns=$(basename "$ns_dir")
    echo "=== Deploying Ingress for namespace: $ns ==="
    for ing in "$ns_dir"*.yaml; do
        if [ -f "$ing" ]; then
            kubectl apply -f "$ing"
        fi
    done
done

# Verify
kubectl get ingress -A
```

## 10. Deploy Network Policies

```bash
# Deploy network policies
for ns_dir in networkpolicies/*/; do
    ns=$(basename "$ns_dir")
    echo "=== Deploying NetworkPolicies for namespace: $ns ==="
    for np in "$ns_dir"*.yaml; do
        if [ -f "$np" ]; then
            kubectl apply -f "$np"
        fi
    done
done

# Verify
kubectl get networkpolicies -A
```

## Verify All Deployments

### Check Overall Status

```bash
# All pods should be Running
kubectl get pods -A | grep -v Running | grep -v Completed

# Check for any issues
kubectl get events -A --sort-by='.lastTimestamp' | tail -50
```

### Check Per Namespace

```bash
# Create verification script
cat <<'EOF' > /root/verify-workloads.sh
#!/bin/bash
echo "=== Workload Verification ==="
echo ""

for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v -E "^kube-|^default$|longhorn|traefik|local-path"); do
    echo "--- Namespace: $ns ---"

    # Pods
    total=$(kubectl get pods -n $ns --no-headers 2>/dev/null | wc -l)
    running=$(kubectl get pods -n $ns --no-headers 2>/dev/null | grep Running | wc -l)
    echo "Pods: $running/$total running"

    # Non-running pods
    kubectl get pods -n $ns --no-headers 2>/dev/null | grep -v Running | grep -v Completed

    # Deployments
    kubectl get deployments -n $ns --no-headers 2>/dev/null | while read line; do
        name=$(echo $line | awk '{print $1}')
        ready=$(echo $line | awk '{print $2}')
        echo "Deployment $name: $ready"
    done

    echo ""
done
EOF

chmod +x /root/verify-workloads.sh
/root/verify-workloads.sh
```

### Verify Services

```bash
# Check all services have endpoints
kubectl get endpoints -A | grep -v kube-system

# Test internal DNS
kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup <service>.<namespace>.svc.cluster.local
```

### Verify Ingress

```bash
# Get Load Balancer IP
LB_IP=$(hcloud load-balancer describe k8s-ingress -o format='{{.PublicNet.IPv4.IP}}')

# List all ingress hosts
kubectl get ingress -A -o jsonpath='{range .items[*]}{.spec.rules[*].host}{"\n"}{end}'

# Test each host
for host in $(kubectl get ingress -A -o jsonpath='{range .items[*]}{.spec.rules[*].host}{"\n"}{end}'); do
    echo "Testing $host..."
    curl -s -o /dev/null -w "%{http_code}" -H "Host: $host" http://${LB_IP}/
    echo ""
done
```

## Troubleshooting Common Issues

### Pods in CrashLoopBackOff

```bash
# Check logs
kubectl logs -n <namespace> <pod-name>

# Check previous logs
kubectl logs -n <namespace> <pod-name> --previous

# Common causes:
# - Missing ConfigMaps or Secrets
# - Database connection issues
# - PVC not mounted
```

### Pods in Pending

```bash
# Check events
kubectl describe pod -n <namespace> <pod-name>

# Common causes:
# - Insufficient resources
# - PVC not bound
# - Node selector issues
```

### Service Has No Endpoints

```bash
# Check if pods are running and have correct labels
kubectl get pods -n <namespace> --show-labels

# Check service selector
kubectl describe svc -n <namespace> <service-name>
```

## Record Deployment Status

```bash
# Generate deployment report
cat <<'EOF' > /root/deployment-report.sh
#!/bin/bash
echo "=== Cluster B Deployment Report ==="
echo "Generated: $(date)"
echo ""

echo "=== Nodes ==="
kubectl get nodes -o wide
echo ""

echo "=== Namespaces ==="
kubectl get namespaces
echo ""

echo "=== Workload Summary ==="
echo "Deployments: $(kubectl get deployments -A --no-headers | wc -l)"
echo "StatefulSets: $(kubectl get statefulsets -A --no-headers | wc -l)"
echo "DaemonSets: $(kubectl get daemonsets -A --no-headers | wc -l)"
echo "Pods Running: $(kubectl get pods -A --no-headers | grep Running | wc -l)"
echo "Pods Not Running: $(kubectl get pods -A --no-headers | grep -v Running | grep -v Completed | wc -l)"
echo ""

echo "=== Storage ==="
echo "PVCs: $(kubectl get pvc -A --no-headers | wc -l)"
echo "PVCs Bound: $(kubectl get pvc -A --no-headers | grep Bound | wc -l)"
echo ""

echo "=== Ingress ==="
kubectl get ingress -A
echo ""

echo "=== Non-Running Pods ==="
kubectl get pods -A | grep -v Running | grep -v Completed | grep -v NAME
EOF

chmod +x /root/deployment-report.sh
/root/deployment-report.sh | tee /root/deployment-report-$(date +%Y%m%d).txt
```

## Deployment Checklist

- [ ] All namespaces created
- [ ] RBAC resources applied
- [ ] Secrets and ConfigMaps deployed
- [ ] PVCs bound
- [ ] StatefulSets running
- [ ] Deployments running
- [ ] Services have endpoints
- [ ] Ingress resources created
- [ ] Network policies applied
- [ ] All pods in Running state
- [ ] Basic functionality verified

In the next lesson, we'll perform the DNS cutover to switch traffic from Cluster A to Cluster B.
