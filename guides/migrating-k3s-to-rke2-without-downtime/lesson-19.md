---
layout: guide-lesson.liquid
title: Migrating Persistent Data

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 4
guide_lesson_id: 19
guide_lesson_abstract: >
  Understand strategies for migrating persistent data from Cluster A to Cluster B.
guide_lesson_conclusion: >
  You understand the available data migration strategies and can choose the appropriate approach for your workloads.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-19.md
---

Persistent volumes contain application state that can't be recreated from manifests alone.
This lesson covers strategies for moving data between clusters.

{% include guide-overview-link.liquid.html %}

## Understanding Data Migration

Unlike deployments or services, PVC data must be explicitly transferred.
The right strategy depends on your workload characteristics.

### Migration Challenges

| Challenge                 | Impact                                   | Mitigation                    |
| ------------------------- | ---------------------------------------- | ----------------------------- |
| Data consistency          | Writes during transfer cause divergence  | Scale down or use replication |
| Transfer time             | Large volumes delay migration            | Use incremental sync          |
| Storage class differences | PVC may not bind                         | Update storageClassName       |
| Access modes              | ReadWriteOnce blocks simultaneous access | Coordinate pod scheduling     |

## Choosing a Strategy

| Strategy                      | Downtime | Best For                          |
| ----------------------------- | -------- | --------------------------------- |
| Application-level replication | None     | Databases with native replication |
| Backup and restore            | Brief    | Most stateful applications        |
| Direct volume copy            | Brief    | Small to medium volumes           |
| Velero                        | Minimal  | Multiple related PVCs             |

### Decision Guide

```mermaid!
flowchart TD
  Start[Need to migrate PVC]
  DB{Is it a database?}
  Native{Native replication?}
  Size{Volume size?}

  Replication[Application Replication]
  Backup[Backup/Restore]
  Direct[Direct Copy]

  Start --> DB
  DB -->|Yes| Native
  DB -->|No| Size
  Native -->|Yes| Replication
  Native -->|No| Backup
  Size -->|Small| Direct
  Size -->|Large| Backup

  classDef strategy fill:#10b981,color:#fff
  class Replication,Backup,Direct strategy
```

## Strategy 1: Application-Level Replication

For databases with built-in replication (PostgreSQL, MySQL, MongoDB), configure the Cluster B instance as a replica of Cluster A.

1. Deploy database on Cluster B as standby/replica
2. Configure streaming replication from Cluster A
3. Wait for synchronization
4. Promote replica to primary during cutover

This provides zero-downtime migration with continuous synchronization.

## Strategy 2: Backup and Restore

The simplest approach for most applications.

1. Scale down the application on Cluster A
2. Create a backup (database dump, tar archive, etc.)
3. Transfer backup to Cluster B
4. Create PVC on Cluster B
5. Restore data into the new PVC
6. Deploy the application

Works well for databases (`pg_dump`, `mysqldump`) and file-based storage (`tar`).

## Strategy 3: Direct Volume Copy

For direct transfer using intermediate storage or rsync:

1. Backup to S3/MinIO/NFS from Cluster A
2. Restore from intermediate storage on Cluster B

Useful when you have shared storage accessible from both clusters.

## Strategy 4: Velero

For complex applications with multiple interdependent PVCs:

1. Install Velero on both clusters with shared backup location
2. Create backup on Cluster A
3. Restore on Cluster B

Velero handles PVCs, secrets, configmaps, and deployments together, maintaining relationships.

## General Workflow

For each stateful application:

1. **Analyze** what data needs migration and choose a strategy
2. **Scale down** on Cluster A to prevent writes during transfer
3. **Export** data using your chosen method
4. **Create** namespace, secrets, configmaps, and PVCs on Cluster B
5. **Restore** data to the new PVCs
6. **Deploy** the application on Cluster B
7. **Verify** data integrity and functionality

## Verification

After migrating each application:

- Check PVC is bound
- Verify pod starts successfully
- Test data integrity (checksums, record counts, application tests)
- Confirm functionality works as expected

In the next lesson, we'll deploy workloads to Cluster B.
