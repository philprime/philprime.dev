---
layout: guide-lesson.liquid
title: Migrating Persistent Volumes

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 4
guide_lesson_id: 19
guide_lesson_abstract: >
  Migrate persistent data from Cluster A to Cluster B using various strategies based on workload requirements.
guide_lesson_conclusion: >
  Persistent data has been successfully migrated to Cluster B, ready for workload deployment.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-19.md
---

Migrating persistent data requires careful planning. This lesson covers various strategies for moving data from
Cluster A to Cluster B based on your workload requirements.

{% include guide-overview-link.liquid.html %}

## Data Migration Strategies

| Strategy                      | Best For                      | Downtime   | Complexity |
| ----------------------------- | ----------------------------- | ---------- | ---------- |
| Application-level replication | Databases (PostgreSQL, MySQL) | None       | Medium     |
| Backup and restore            | Any stateful app              | Brief      | Low        |
| Direct volume copy            | Small-medium volumes          | Brief      | Low        |
| Velero migration              | Complex workloads             | Minimal    | Medium     |
| Sync tools (rsync)            | File-based storage            | None/Brief | Low        |

## Strategy 1: Application-Level Replication (Databases)

For databases like PostgreSQL, MySQL, or MongoDB, use native replication:

### PostgreSQL Example

```bash
# 1. On Cluster B, deploy a replica PostgreSQL
# 2. Configure streaming replication from Cluster A

# On Cluster A (primary)
# Edit postgresql.conf:
# wal_level = replica
# max_wal_senders = 3

# Create replication user:
kubectl exec -it -n <namespace> <postgres-pod> -- psql -c "CREATE USER replicator REPLICATION LOGIN ENCRYPTED PASSWORD 'secret';"

# On Cluster B (replica)
# Configure as standby pointing to Cluster A

# Once in sync, promote Cluster B to primary during cutover
kubectl exec -it -n <namespace> <postgres-pod> -- pg_ctl promote
```

### MySQL Example

```bash
# Use MySQL replication
# Configure Cluster A as source, Cluster B as replica
# Switch primary during cutover
```

## Strategy 2: Backup and Restore

For most applications, backup and restore is the simplest approach.

### Using kubectl exec

```bash
# 1. Create backup from source pod
kubectl exec -n <namespace> <pod-name> -- tar czf - /data > backup.tar.gz

# 2. Transfer to Cluster B
scp backup.tar.gz root@node4:/root/

# 3. Create target PVC and pod on Cluster B
kubectl apply -f /root/cluster-a-export/pvc/<namespace>/<pvc>.yaml

# 4. Create a temporary pod to restore data
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: restore-pod
  namespace: <namespace>
spec:
  containers:
  - name: restore
    image: busybox
    command: ['sleep', '3600']
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: <pvc-name>
EOF

# 5. Restore data
kubectl cp backup.tar.gz <namespace>/restore-pod:/tmp/
kubectl exec -n <namespace> restore-pod -- tar xzf /tmp/backup.tar.gz -C /

# 6. Cleanup
kubectl delete pod restore-pod -n <namespace>
```

### Database Backup/Restore

```bash
# PostgreSQL
kubectl exec -n <ns> <pod> -- pg_dump -U postgres <dbname> > backup.sql
# Restore on Cluster B
kubectl exec -i -n <ns> <pod> -- psql -U postgres <dbname> < backup.sql

# MySQL
kubectl exec -n <ns> <pod> -- mysqldump -u root -p<password> <dbname> > backup.sql
# Restore on Cluster B
kubectl exec -i -n <ns> <pod> -- mysql -u root -p<password> <dbname> < backup.sql

# MongoDB
kubectl exec -n <ns> <pod> -- mongodump --out=/tmp/backup
kubectl cp <ns>/<pod>:/tmp/backup ./mongodb-backup/
# Restore on Cluster B
kubectl cp ./mongodb-backup/ <ns>/<pod>:/tmp/backup
kubectl exec -n <ns> <pod> -- mongorestore /tmp/backup
```

## Strategy 3: Direct Volume Copy

For direct volume-to-volume migration:

### Using rsync Between Pods

```bash
# 1. Create source pod on Cluster A with PVC mounted
# 2. Create destination pod on Cluster B with new PVC
# 3. Use rsync or kubectl cp to transfer

# Create rsync pod on Cluster A
cat <<'EOF' | kubectl apply -f - --context=cluster-a
apiVersion: v1
kind: Pod
metadata:
  name: rsync-source
  namespace: <namespace>
spec:
  containers:
  - name: rsync
    image: alpine
    command: ['sh', '-c', 'apk add rsync openssh && sleep 3600']
    volumeMounts:
    - name: data
      mountPath: /source
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: <source-pvc>
EOF

# Create rsync pod on Cluster B
cat <<'EOF' | kubectl apply -f - --context=cluster-b
apiVersion: v1
kind: Pod
metadata:
  name: rsync-dest
  namespace: <namespace>
spec:
  containers:
  - name: rsync
    image: alpine
    command: ['sh', '-c', 'apk add rsync openssh && sleep 3600']
    volumeMounts:
    - name: data
      mountPath: /dest
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: <dest-pvc>
EOF

# Port-forward and rsync
# This requires network connectivity between the pods or intermediate storage
```

### Using Intermediate Storage

```bash
# 1. Backup to S3/MinIO/NFS
kubectl exec -n <ns> <source-pod> -- tar czf - /data | aws s3 cp - s3://bucket/backup.tar.gz

# 2. Restore from S3 to Cluster B
kubectl exec -n <ns> <dest-pod> -- sh -c 'aws s3 cp s3://bucket/backup.tar.gz - | tar xzf - -C /'
```

## Strategy 4: Velero Migration

For complex workloads with multiple PVCs:

### Install Velero on Both Clusters

```bash
# Install Velero CLI
curl -L https://github.com/vmware-tanzu/velero/releases/latest/download/velero-linux-amd64.tar.gz | tar xz
mv velero*/velero /usr/local/bin/

# Install Velero on Cluster A
velero install \
  --provider aws \
  --bucket velero-backups \
  --secret-file ./credentials-velero \
  --backup-location-config region=us-east-1,s3ForcePathStyle=true,s3Url=https://s3.example.com \
  --use-volume-snapshots=false \
  --use-restic

# Create backup of namespace
velero backup create app-backup --include-namespaces=<namespace>

# Wait for backup
velero backup describe app-backup --details

# Install Velero on Cluster B with same configuration
# Restore backup
velero restore create --from-backup app-backup
```

## Migration Workflow Example

Here's a complete example for a typical web application:

```bash
# Application: WordPress with MySQL backend
# PVCs: wordpress-data, mysql-data

# 1. Scale down application on Cluster A (minimize changes)
kubectl scale deployment wordpress --replicas=0 -n wordpress --context=cluster-a
kubectl scale deployment mysql --replicas=0 -n wordpress --context=cluster-a

# 2. Backup MySQL
kubectl exec -n wordpress mysql-xxx --context=cluster-a -- mysqldump -u root -pPassword wordpress > wordpress-db.sql

# 3. Backup WordPress files
kubectl exec -n wordpress wordpress-xxx --context=cluster-a -- tar czf - /var/www/html > wordpress-files.tar.gz

# 4. Create namespace on Cluster B
kubectl create namespace wordpress --context=cluster-b

# 5. Apply secrets and configmaps
kubectl apply -f /root/cluster-a-export/secrets/wordpress/ --context=cluster-b
kubectl apply -f /root/cluster-a-export/configmaps/wordpress/ --context=cluster-b

# 6. Create PVCs on Cluster B
kubectl apply -f /root/cluster-a-export/pvc/wordpress/ --context=cluster-b

# 7. Deploy MySQL and restore data
kubectl apply -f /root/cluster-a-export/deployments/wordpress/mysql.yaml --context=cluster-b
kubectl wait --for=condition=Ready pod -l app=mysql -n wordpress --timeout=120s --context=cluster-b
kubectl exec -i -n wordpress mysql-xxx --context=cluster-b -- mysql -u root -pPassword wordpress < wordpress-db.sql

# 8. Deploy WordPress and restore files
kubectl apply -f /root/cluster-a-export/deployments/wordpress/wordpress.yaml --context=cluster-b
kubectl wait --for=condition=Ready pod -l app=wordpress -n wordpress --timeout=120s --context=cluster-b
kubectl cp wordpress-files.tar.gz wordpress/wordpress-xxx:/tmp/ --context=cluster-b
kubectl exec -n wordpress wordpress-xxx --context=cluster-b -- tar xzf /tmp/wordpress-files.tar.gz -C /

# 9. Apply services and ingress
kubectl apply -f /root/cluster-a-export/services/wordpress/ --context=cluster-b
kubectl apply -f /root/cluster-a-export/ingress/wordpress/ --context=cluster-b

# 10. Verify
kubectl get pods -n wordpress --context=cluster-b
```

## Verification Steps

After migrating each application:

```bash
# 1. Check pod status
kubectl get pods -n <namespace>

# 2. Check logs for errors
kubectl logs -n <namespace> <pod-name>

# 3. Check PVC status
kubectl get pvc -n <namespace>

# 4. Verify data integrity
# (Application-specific checks)

# 5. Test functionality
# (Application-specific tests)
```

## Create Migration Tracking

```bash
cat <<'EOF' > /root/migration-tracking.md
# Data Migration Tracking

| Application | Namespace | PVCs | Strategy | Status | Verified |
|-------------|-----------|------|----------|--------|----------|
| App1        | ns1       | pvc1 | backup   | [ ]    | [ ]      |
| App2        | ns2       | pvc2 | rsync    | [ ]    | [ ]      |
| Database    | db        | data | replica  | [ ]    | [ ]      |

## Notes
-
EOF
```

## Common Issues

### PVC Stuck in Pending

```bash
# Check events
kubectl describe pvc <pvc-name> -n <namespace>

# Common causes:
# - Storage class not found
# - Insufficient storage
# - Node selector issues

# Fix storage class if needed
kubectl patch pvc <pvc-name> -n <namespace> -p '{"spec":{"storageClassName":"longhorn"}}'
```

### Data Corruption

```bash
# Always verify checksums for critical data
# Source
kubectl exec -n <ns> <pod> -- md5sum /data/important-file

# Destination
kubectl exec -n <ns> <pod> -- md5sum /data/important-file
```

## Migration Checklist

For each application:

- [ ] Identify all PVCs
- [ ] Choose migration strategy
- [ ] Backup data on Cluster A
- [ ] Create namespace on Cluster B
- [ ] Apply secrets and configmaps
- [ ] Create PVCs
- [ ] Restore data
- [ ] Deploy application
- [ ] Verify data integrity
- [ ] Test functionality
- [ ] Document migration

In the next lesson, we'll deploy the remaining workloads to Cluster B.
