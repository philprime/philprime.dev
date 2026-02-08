---
layout: guide-lesson.liquid
title: Exporting Workload Manifests from Cluster A

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 4
guide_lesson_id: 16
guide_lesson_abstract: >
  Export all workload manifests, configurations, and secrets from the k3s cluster for migration to RKE2.
guide_lesson_conclusion: >
  All workload manifests have been exported and prepared for deployment to Cluster B.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-16.md
---

Before we can migrate workloads to Cluster B, we need to export all necessary manifests, configurations, and
secrets from Cluster A.

{% include guide-overview-link.liquid.html %}

## Current State

```
Cluster A (k3s):          Cluster B (RKE2):
┌─────────────────┐       ┌─────────────────────┐
│ Node 1 (CP)     │       │ Node 2 (CP)         │
│ [All Workloads] │  ──>  │ Node 3 (CP)         │
│                 │       │ Node 4 (CP)         │
└─────────────────┘       └─────────────────────┘
  Source                    Target (ready for workloads)
```

## Connect to Cluster A

```bash
# Set kubeconfig for Cluster A
export KUBECONFIG=/path/to/cluster-a-kubeconfig

# Verify connection
kubectl cluster-info
kubectl get nodes
```

## Create Export Directory

```bash
# Create organized export structure
mkdir -p /root/cluster-a-export/{namespaces,deployments,statefulsets,services,configmaps,secrets,ingress,pvc,networkpolicies,other}
cd /root/cluster-a-export
```

## Export Namespaces

```bash
# List all namespaces
kubectl get namespaces

# Export namespace definitions (exclude system namespaces)
for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v -E "^kube-|^default$"); do
    kubectl get namespace $ns -o yaml > namespaces/${ns}.yaml
    echo "Exported namespace: $ns"
done
```

## Export Deployments

```bash
# Export all deployments (excluding system namespaces)
for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v -E "^kube-"); do
    deployments=$(kubectl get deployments -n $ns -o jsonpath='{.items[*].metadata.name}')
    if [ -n "$deployments" ]; then
        mkdir -p deployments/$ns
        for dep in $deployments; do
            kubectl get deployment $dep -n $ns -o yaml > deployments/$ns/${dep}.yaml
            echo "Exported deployment: $ns/$dep"
        done
    fi
done
```

## Export StatefulSets

```bash
# Export all statefulsets
for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v -E "^kube-"); do
    statefulsets=$(kubectl get statefulsets -n $ns -o jsonpath='{.items[*].metadata.name}')
    if [ -n "$statefulsets" ]; then
        mkdir -p statefulsets/$ns
        for sts in $statefulsets; do
            kubectl get statefulset $sts -n $ns -o yaml > statefulsets/$ns/${sts}.yaml
            echo "Exported statefulset: $ns/$sts"
        done
    fi
done
```

## Export Services

```bash
# Export all services
for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v -E "^kube-"); do
    services=$(kubectl get services -n $ns -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v "^kubernetes$")
    if [ -n "$services" ]; then
        mkdir -p services/$ns
        for svc in $services; do
            kubectl get service $svc -n $ns -o yaml > services/$ns/${svc}.yaml
            echo "Exported service: $ns/$svc"
        done
    fi
done
```

## Export ConfigMaps

```bash
# Export configmaps (excluding system-generated ones)
for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v -E "^kube-"); do
    configmaps=$(kubectl get configmaps -n $ns -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v "kube-root-ca.crt")
    if [ -n "$configmaps" ]; then
        mkdir -p configmaps/$ns
        for cm in $configmaps; do
            kubectl get configmap $cm -n $ns -o yaml > configmaps/$ns/${cm}.yaml
            echo "Exported configmap: $ns/$cm"
        done
    fi
done
```

## Export Secrets

{% include alert.liquid.html type='warning' title='Security Warning' content='
Secrets contain sensitive data. Store exported secrets securely and delete them after migration. Never commit secrets to version control.
' %}

```bash
# Export secrets (excluding service account tokens)
for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v -E "^kube-"); do
    secrets=$(kubectl get secrets -n $ns -o jsonpath='{.items[?(@.type!="kubernetes.io/service-account-token")].metadata.name}')
    if [ -n "$secrets" ]; then
        mkdir -p secrets/$ns
        chmod 700 secrets/$ns
        for secret in $secrets; do
            kubectl get secret $secret -n $ns -o yaml > secrets/$ns/${secret}.yaml
            chmod 600 secrets/$ns/${secret}.yaml
            echo "Exported secret: $ns/$secret"
        done
    fi
done
```

## Export Ingress Resources

```bash
# Export ingress resources
for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v -E "^kube-"); do
    ingresses=$(kubectl get ingress -n $ns -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    if [ -n "$ingresses" ]; then
        mkdir -p ingress/$ns
        for ing in $ingresses; do
            kubectl get ingress $ing -n $ns -o yaml > ingress/$ns/${ing}.yaml
            echo "Exported ingress: $ns/$ing"
        done
    fi
done
```

## Export PersistentVolumeClaims

```bash
# Export PVCs
for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v -E "^kube-"); do
    pvcs=$(kubectl get pvc -n $ns -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    if [ -n "$pvcs" ]; then
        mkdir -p pvc/$ns
        for pvc in $pvcs; do
            kubectl get pvc $pvc -n $ns -o yaml > pvc/$ns/${pvc}.yaml
            echo "Exported PVC: $ns/$pvc"
        done
    fi
done

# Export PersistentVolumes (cluster-level)
kubectl get pv -o yaml > pvc/persistent-volumes.yaml
```

## Export Network Policies

```bash
# Export network policies
for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v -E "^kube-"); do
    netpols=$(kubectl get networkpolicies -n $ns -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    if [ -n "$netpols" ]; then
        mkdir -p networkpolicies/$ns
        for np in $netpols; do
            kubectl get networkpolicy $np -n $ns -o yaml > networkpolicies/$ns/${np}.yaml
            echo "Exported networkpolicy: $ns/$np"
        done
    fi
done
```

## Export Other Resources

```bash
# DaemonSets
for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v -E "^kube-"); do
    daemonsets=$(kubectl get daemonsets -n $ns -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    if [ -n "$daemonsets" ]; then
        mkdir -p other/daemonsets/$ns
        for ds in $daemonsets; do
            kubectl get daemonset $ds -n $ns -o yaml > other/daemonsets/$ns/${ds}.yaml
        done
    fi
done

# CronJobs
for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v -E "^kube-"); do
    cronjobs=$(kubectl get cronjobs -n $ns -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    if [ -n "$cronjobs" ]; then
        mkdir -p other/cronjobs/$ns
        for cj in $cronjobs; do
            kubectl get cronjob $cj -n $ns -o yaml > other/cronjobs/$ns/${cj}.yaml
        done
    fi
done

# ServiceAccounts (non-default)
for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v -E "^kube-"); do
    sas=$(kubectl get serviceaccounts -n $ns -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v "^default$")
    if [ -n "$sas" ]; then
        mkdir -p other/serviceaccounts/$ns
        for sa in $sas; do
            kubectl get serviceaccount $sa -n $ns -o yaml > other/serviceaccounts/$ns/${sa}.yaml
        done
    fi
done

# RBAC (ClusterRoles, ClusterRoleBindings, Roles, RoleBindings)
kubectl get clusterroles -o yaml | grep -v "system:" > other/clusterroles.yaml 2>/dev/null || true
kubectl get clusterrolebindings -o yaml | grep -v "system:" > other/clusterrolebindings.yaml 2>/dev/null || true
```

## Clean Exported Manifests

Remove cluster-specific metadata that shouldn't be transferred:

```bash
# Create cleanup script
cat <<'EOF' > /root/cluster-a-export/cleanup-manifests.sh
#!/bin/bash
# Remove cluster-specific fields from manifests

find . -name "*.yaml" -type f | while read file; do
    # Remove status, resourceVersion, uid, creationTimestamp, generation
    yq eval 'del(.status) | del(.metadata.resourceVersion) | del(.metadata.uid) | del(.metadata.creationTimestamp) | del(.metadata.generation) | del(.metadata.managedFields)' -i "$file"
done

echo "Manifests cleaned"
EOF

chmod +x cleanup-manifests.sh

# Install yq if not present
curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/local/bin/yq
chmod +x /usr/local/bin/yq

# Run cleanup
./cleanup-manifests.sh
```

## Generate Export Summary

```bash
# Create summary of exported resources
cat <<'EOF' > /root/cluster-a-export/create-summary.sh
#!/bin/bash
echo "=== Cluster A Export Summary ===" > summary.txt
echo "Generated: $(date)" >> summary.txt
echo "" >> summary.txt

for dir in namespaces deployments statefulsets services configmaps secrets ingress pvc networkpolicies; do
    count=$(find $dir -name "*.yaml" 2>/dev/null | wc -l)
    echo "$dir: $count resources" >> summary.txt
done

echo "" >> summary.txt
echo "=== Detailed List ===" >> summary.txt

for dir in namespaces deployments statefulsets services configmaps secrets ingress pvc networkpolicies; do
    if [ -d "$dir" ]; then
        echo "" >> summary.txt
        echo "--- $dir ---" >> summary.txt
        find $dir -name "*.yaml" | sort >> summary.txt
    fi
done

cat summary.txt
EOF

chmod +x create-summary.sh
./create-summary.sh
```

## Review Before Migration

Review exported resources for any issues:

```bash
# Check for hardcoded node names
grep -r "nodeName:" . | grep -v ".git"

# Check for hardcoded IPs
grep -r -E "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" . | grep -v ".git" | head -20

# Check for k3s-specific annotations
grep -r "k3s" . | grep -v ".git"

# Check for old cluster references
grep -r "cluster-a" . | grep -v ".git"
```

## Transfer to Cluster B

```bash
# Create archive
tar czvf cluster-a-export-$(date +%Y%m%d).tar.gz /root/cluster-a-export/

# Transfer to one of the Cluster B nodes
scp cluster-a-export-*.tar.gz root@10.1.1.4:/root/

# On Cluster B node
ssh root@node4
tar xzvf cluster-a-export-*.tar.gz -C /root/
```

## Manifest Modifications for RKE2

Some manifests may need adjustments:

```bash
# Check ingress class (k3s uses traefik, RKE2 may need adjustment)
grep -r "ingressClassName" ingress/

# Check storage class references
grep -r "storageClassName" pvc/

# These will need to match the new cluster's storage classes
# We'll configure storage in the next lesson
```

## Exported Resources Checklist

Verify you have exported:

- [ ] Namespaces
- [ ] Deployments
- [ ] StatefulSets
- [ ] Services
- [ ] ConfigMaps
- [ ] Secrets (stored securely)
- [ ] Ingress resources
- [ ] PersistentVolumeClaims
- [ ] Network Policies
- [ ] DaemonSets (non-system)
- [ ] CronJobs
- [ ] Custom ServiceAccounts
- [ ] RBAC resources

In the next lesson, we'll set up storage on Cluster B before deploying these workloads.
