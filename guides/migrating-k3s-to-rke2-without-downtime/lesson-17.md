---
layout: guide-lesson.liquid
title: Setting Up Storage (Longhorn + local-path)

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 4
guide_lesson_id: 17
guide_lesson_abstract: >
  Plan storage requirements and configure Longhorn for replicated storage and local-path-provisioner for fast local storage.
guide_lesson_conclusion: >
  Both Longhorn and local-path storage classes are configured and ready for workload deployment.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-17.md
---

Before deploying workloads, we need to set up persistent storage.
We'll configure two storage classes: Longhorn for replicated storage and local-path-provisioner for fast local storage.

{% include guide-overview-link.liquid.html %}

## Storage Planning

### Disk Space Requirements

Longhorn stores volume replicas on each node's local disk.
With the default replica count of 2, a 10GB volume consumes 20GB of total cluster storage.
Plan your disk space accordingly:

| Component        | Minimum | Recommended | Notes                                 |
| ---------------- | ------- | ----------- | ------------------------------------- |
| OS and RKE2      | 20GB    | 40GB        | Container images, logs, etcd data     |
| Longhorn storage | 50GB    | 100GB+      | Per-node, depends on workload volumes |
| local-path       | 10GB    | 20GB        | Fast local storage for caching        |

For simple partition layouts (`/boot` + `/`), all storage shares the root partition.
If you have large storage requirements, consider a dedicated partition or disk for `/var/lib/longhorn`.

### Backup Target

Longhorn supports backup to S3 or NFS.
If you plan to use backups (recommended for production), ensure you have:

- S3-compatible storage (AWS S3, MinIO, Hetzner Object Storage)
- Or an NFS server accessible from all nodes

## Storage Strategy

| Storage Class | Use Case                 | Replication        | Performance |
| ------------- | ------------------------ | ------------------ | ----------- |
| Longhorn      | Databases, stateful apps | Yes (configurable) | Good        |
| local-path    | Caching, temp storage    | No                 | Excellent   |

## Prepare Nodes for Longhorn

Longhorn requires iSCSI support on all nodes. Run on each node:

```bash
# Install iSCSI initiator
dnf install -y iscsi-initiator-utils

# Enable and start iscsid
systemctl enable --now iscsid

# Install NFSv4 client (for backup support)
dnf install -y nfs-utils

# Verify
systemctl status iscsid
```

### Create a Script to Run on All Nodes

```bash
# From your workstation or Node 4
for node in node2 node3 node4; do
    echo "=== Configuring $node ==="
    ssh root@$node "dnf install -y iscsi-initiator-utils nfs-utils && systemctl enable --now iscsid"
done
```

## Install Longhorn

### Add Longhorn Helm Repository

```bash
# On any control plane node
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

# Add Helm repo
helm repo add longhorn https://charts.longhorn.io
helm repo update

# Search for available versions
helm search repo longhorn/longhorn --versions | head -5
```

### Create Longhorn Configuration

```bash
cat <<'EOF' > /root/longhorn-values.yaml
# Longhorn Configuration

# Default settings
defaultSettings:
  # Number of replicas for new volumes
  defaultReplicaCount: 2

  # Storage reserved for other pods
  storageMinimalAvailablePercentage: 15

  # Default data locality
  defaultDataLocality: "best-effort"

  # Backup target (optional - configure if you have S3/NFS backup)
  # backupTarget: "s3://backups@us-east-1/"
  # backupTargetCredentialSecret: longhorn-backup-secret

  # Node drain policy
  nodeDrainPolicy: "block-if-contains-last-replica"

  # Guaranteed engine manager CPU
  guaranteedEngineManagerCPU: 12

  # Guaranteed replica manager CPU
  guaranteedReplicaManagerCPU: 12

# Persistence settings
persistence:
  defaultClass: true
  defaultClassReplicaCount: 2
  reclaimPolicy: Delete

# UI configuration
ingress:
  enabled: false  # We'll set up ingress separately if needed

# Resource requests
longhornManager:
  priorityClass: ~
  tolerations: []

longhornDriver:
  priorityClass: ~
  tolerations: []

# Enable default storage class
defaultClass: true
EOF
```

### Install Longhorn

```bash
# Create namespace
kubectl create namespace longhorn-system

# Install Longhorn
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --values /root/longhorn-values.yaml \
  --wait

# Watch installation progress
kubectl get pods -n longhorn-system -w
```

Wait for all pods to be running:

```
NAME                                        READY   STATUS    RESTARTS   AGE
longhorn-manager-xxxxx                      1/1     Running   0          2m
longhorn-driver-deployer-xxxxx              1/1     Running   0          2m
longhorn-ui-xxxxx                           1/1     Running   0          2m
csi-attacher-xxxxx                          1/1     Running   0          2m
csi-provisioner-xxxxx                       1/1     Running   0          2m
csi-snapshotter-xxxxx                       1/1     Running   0          2m
engine-image-ei-xxxxx                       1/1     Running   0          2m
instance-manager-xxxxx                      1/1     Running   0          2m
```

### Verify Longhorn Installation

```bash
# Check storage class
kubectl get storageclass

# Expected:
# NAME                 PROVISIONER          RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
# longhorn (default)   driver.longhorn.io   Delete          Immediate           true                   1m

# Check Longhorn nodes
kubectl get nodes.longhorn.io -n longhorn-system

# Check Longhorn volumes (should be empty)
kubectl get volumes.longhorn.io -n longhorn-system
```

### Test Longhorn Storage

```bash
# Create a test PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: longhorn-test-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 1Gi
EOF

# Create a test pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: longhorn-test-pod
  namespace: default
spec:
  containers:
  - name: test
    image: busybox
    command: ['sh', '-c', 'echo "Hello from Longhorn" > /data/test.txt && cat /data/test.txt && sleep 3600']
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: longhorn-test-pvc
EOF

# Wait for pod
kubectl wait --for=condition=Ready pod/longhorn-test-pod --timeout=120s

# Verify data was written
kubectl logs longhorn-test-pod

# Check volume status
kubectl get pvc longhorn-test-pvc
kubectl get pv

# Cleanup
kubectl delete pod longhorn-test-pod
kubectl delete pvc longhorn-test-pvc
```

## Install local-path-provisioner

For workloads that need fast local storage without replication:

```bash
# Install local-path-provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

# Wait for deployment
kubectl wait --for=condition=Available deployment/local-path-provisioner -n local-path-storage --timeout=60s

# Check storage class
kubectl get storageclass

# Expected:
# NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
# longhorn (default)   driver.longhorn.io      Delete          Immediate              true                   10m
# local-path           rancher.io/local-path   Delete          WaitForFirstConsumer   false                  1m
```

### Configure local-path-provisioner (Optional)

```bash
# The default configuration uses /opt/local-path-provisioner
# To customize, edit the configmap:
kubectl get configmap local-path-config -n local-path-storage -o yaml

# You can change the storage path or add node-specific paths
```

### Test local-path Storage

```bash
# Create test PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: local-path-test-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
EOF

# Create test pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: local-path-test-pod
  namespace: default
spec:
  containers:
  - name: test
    image: busybox
    command: ['sh', '-c', 'echo "Hello from local-path" > /data/test.txt && cat /data/test.txt && sleep 3600']
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: local-path-test-pvc
EOF

# Wait for pod
kubectl wait --for=condition=Ready pod/local-path-test-pod --timeout=60s

# Verify
kubectl logs local-path-test-pod

# Cleanup
kubectl delete pod local-path-test-pod
kubectl delete pvc local-path-test-pvc
```

## Storage Class Summary

```bash
# View all storage classes
kubectl get storageclass

# NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
# longhorn (default)   driver.longhorn.io      Delete          Immediate              true                   15m
# local-path           rancher.io/local-path   Delete          WaitForFirstConsumer   false                  5m
```

## Update Exported Manifests

If your k3s cluster used a different storage class name, update the exported PVC manifests:

```bash
# Check what storage classes were used in Cluster A
grep -r "storageClassName" /root/cluster-a-export/pvc/

# Common replacements:
# - local-path (k3s default) -> local-path (same name, no change needed)
# - Any other -> longhorn or local-path as appropriate

# Example: Replace a storage class name
# sed -i 's/storageClassName: old-class/storageClassName: longhorn/' /root/cluster-a-export/pvc/namespace/pvc.yaml
```

## Storage Migration Considerations

For persistent data migration:

| Scenario             | Approach                                   |
| -------------------- | ------------------------------------------ |
| Stateless apps       | Just redeploy, no data migration needed    |
| Replicated databases | Use database-native replication            |
| File storage         | Backup and restore, or sync tools          |
| Small PVCs           | kubectl cp or rsync                        |
| Large datasets       | Consider Velero or direct volume migration |

## Access Longhorn UI (Optional)

For troubleshooting and management:

```bash
# Port-forward to access UI locally
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80

# Access at http://localhost:8080
```

Or set up ingress (we'll configure Traefik in the next lesson).

## Storage Verification Checklist

- [ ] Longhorn installed and running
- [ ] Longhorn storage class created (default)
- [ ] Longhorn test volume works
- [ ] local-path-provisioner installed
- [ ] local-path storage class created
- [ ] local-path test volume works
- [ ] Exported PVC manifests reviewed for storage class compatibility

In the next lesson, we'll set up HA ingress with Traefik and Hetzner Cloud Load Balancer.
