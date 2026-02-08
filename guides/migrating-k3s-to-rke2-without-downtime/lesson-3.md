---
layout: guide-lesson.liquid
title: Migration Strategy and Planning

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 1
guide_lesson_id: 3
guide_lesson_abstract: >
  Develop a comprehensive migration strategy with phased execution, risk mitigation, and rollback procedures.
guide_lesson_conclusion: >
  You now have a detailed migration strategy with clear phases, identified risks, and mitigation plans for each
  critical step.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-3.md
---

A successful zero-downtime migration requires meticulous planning. In this lesson, we'll develop our complete
migration strategy, identify risks, and establish mitigation procedures.

{% include guide-overview-link.liquid.html %}

## Migration Phases Overview

Our migration consists of five distinct phases, each with specific objectives and success criteria:

```
┌────────────────────────────────────────────────────────────────────────────┐
│                         MIGRATION TIMELINE                                  │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  Phase 1         Phase 2         Phase 3         Phase 4         Phase 5  │
│  Bootstrap       First Node      Second Node     Workload         Cleanup │
│  Cluster B       Migration       Migration       Migration                │
│                                                                            │
│  [A: 1,2,3]      [A: 1,2]        [A: 1]          [A: 1]          []       │
│  [B: 4]          [B: 3,4]        [B: 2,3,4]      [B: 2,3,4]      [B:1,2,3,4] │
│                                                                            │
│  ────────────────────────────────────────────────────────────────────────  │
│  LOW RISK        CRITICAL        MODERATE        LOW RISK       LOW RISK  │
└────────────────────────────────────────────────────────────────────────────┘
```

## Phase 1: Bootstrap Cluster B

**Objective**: Create initial RKE2 cluster on Node 4

**Starting State**:

- Cluster A: Nodes 1 (CP), 2 (Worker), 3 (Worker)
- Cluster B: None
- Node 4: Unassigned

**Actions**:

1. Install Rocky Linux 9 on Node 4
2. Configure Hetzner vSwitch networking
3. Install RKE2 as first control plane
4. Deploy Cilium CNI
5. Verify cluster functionality

**End State**:

- Cluster A: Unchanged (fully operational)
- Cluster B: Node 4 (single CP)

**Risk Level**: LOW

- Cluster A is not affected
- Can abandon Node 4 setup if issues arise

**Success Criteria**:

- [ ] Node 4 running Rocky Linux 9
- [ ] RKE2 control plane operational
- [ ] Cilium pods running
- [ ] Can deploy test workload

## Phase 2: First Node Migration (CRITICAL)

**Objective**: Migrate Node 3 from Cluster A to Cluster B

**Starting State**:

- Cluster A: Nodes 1 (CP), 2 (Worker), 3 (Worker)
- Cluster B: Node 4 (CP)

**Actions**:

1. Drain Node 3 from Cluster A
2. Remove Node 3 from k3s cluster
3. Reinstall with Rocky Linux 9
4. Join as RKE2 control plane
5. Verify etcd cluster health

**End State**:

- Cluster A: Nodes 1 (CP), 2 (Worker)
- Cluster B: Nodes 3 (CP), 4 (CP)

**Risk Level**: CRITICAL

This is the highest-risk phase because:

- Cluster A loses one worker (reduced capacity)
- Cluster B has 2 control planes (not yet HA - no quorum tolerance)
- Both clusters are at minimum viable capacity

**Mitigation Strategies**:

```bash
# Before starting Phase 2, ensure:

# 1. Cluster A workloads can run on remaining capacity
kubectl get pods -A -o wide | grep node-3  # List all pods on Node 3
kubectl get pdb -A  # Check Pod Disruption Budgets

# 2. Backup k3s etcd data
sudo k3s etcd-snapshot save --name pre-migration-backup

# 3. Have k3s reinstall script ready for rollback
# (save this for emergency)
curl -sfL https://get.k3s.io > /tmp/k3s-install.sh
```

**Rollback Procedure**:
If Node 3 fails to join Cluster B:

1. Reinstall original OS
2. Rejoin as k3s worker
3. Uncordon and restore workloads

**Success Criteria**:

- [ ] Node 3 removed cleanly from Cluster A
- [ ] Node 3 joined as RKE2 control plane
- [ ] etcd shows 2 members
- [ ] Cluster A workloads redistributed to Nodes 1 and 2

## Phase 3: Second Node Migration

**Objective**: Migrate Node 2 from Cluster A to Cluster B

**Starting State**:

- Cluster A: Nodes 1 (CP), 2 (Worker)
- Cluster B: Nodes 3 (CP), 4 (CP)

**Actions**:

1. Drain Node 2 from Cluster A
2. Remove Node 2 from k3s cluster
3. Reinstall with Rocky Linux 9
4. Join as RKE2 control plane
5. Verify 3-node etcd quorum

**End State**:

- Cluster A: Node 1 (CP only)
- Cluster B: Nodes 2 (CP), 3 (CP), 4 (CP) - FULL HA

**Risk Level**: MODERATE

- Cluster A is at minimum (single node)
- Cluster B achieves HA (3 control planes)

**Critical Milestone**: After this phase, Cluster B is production-ready with full HA capability.

**Success Criteria**:

- [ ] Node 2 joined as RKE2 control plane
- [ ] etcd shows 3 healthy members
- [ ] Quorum tolerance verified (can lose 1 node)
- [ ] Cluster A still operational on Node 1

## Phase 4: Workload Migration

**Objective**: Move all workloads from Cluster A to Cluster B

**Starting State**:

- Cluster A: Node 1 (CP with workloads)
- Cluster B: Nodes 2, 3, 4 (3-node HA CP, no workloads)

**Actions**:

1. Set up storage on Cluster B (Longhorn + local-path)
2. Configure ingress (Traefik + Hetzner LB)
3. Export workload manifests from Cluster A
4. Migrate persistent data
5. Deploy workloads to Cluster B
6. Verify workload health
7. Switch DNS to Cluster B ingress
8. Monitor and validate

**End State**:

- Cluster A: Node 1 (CP, no workloads)
- Cluster B: Nodes 2, 3, 4 (serving all traffic)

**Risk Level**: LOW (with proper preparation)

- Both clusters operational during migration
- Can switch DNS back if issues arise

**Success Criteria**:

- [ ] All workloads deployed to Cluster B
- [ ] Persistent data migrated and verified
- [ ] Ingress serving traffic through Hetzner LB
- [ ] DNS pointing to Cluster B
- [ ] Monitoring confirms healthy services

## Phase 5: Cleanup and Consolidation

**Objective**: Decommission Cluster A and add Node 1 as worker

**Starting State**:

- Cluster A: Node 1 (idle)
- Cluster B: Nodes 2, 3, 4 (serving traffic)

**Actions**:

1. Verify Cluster B stability (24-48 hour soak)
2. Stop k3s on Node 1
3. Reinstall with Rocky Linux 9
4. Join as RKE2 agent (worker)
5. Final documentation

**End State**:

- Cluster A: Decommissioned
- Cluster B: Nodes 1 (Worker), 2 (CP), 3 (CP), 4 (CP)

**Risk Level**: LOW

- All workloads already on Cluster B
- Node 1 can be rolled back if needed

**Success Criteria**:

- [ ] k3s completely removed
- [ ] Node 1 joined as RKE2 worker
- [ ] Final cluster health verified
- [ ] Documentation updated

## Risk Matrix

| Risk                           | Probability | Impact   | Mitigation                             |
| ------------------------------ | ----------- | -------- | -------------------------------------- |
| Node fails during OS reinstall | Low         | High     | Have IPMI/KVM access ready             |
| etcd quorum loss (Cluster B)   | Medium      | High     | Don't proceed to Phase 4 until 3 nodes |
| Workload incompatibility       | Low         | Medium   | Test with non-critical services first  |
| DNS propagation delays         | Medium      | Low      | Use low TTL before cutover             |
| Persistent data corruption     | Low         | Critical | Backup all PVs before migration        |
| Network misconfiguration       | Medium      | High     | Verify Cilium before proceeding        |

## Rollback Points

At each phase, we have a clear rollback path:

| Phase | Rollback Action                               |
| ----- | --------------------------------------------- |
| 1     | Abandon Node 4 setup, continue with k3s       |
| 2     | Reinstall Node 3 with original OS, rejoin k3s |
| 3     | Reinstall Node 2 with original OS, rejoin k3s |
| 4     | Switch DNS back to Cluster A                  |
| 5     | (No rollback needed - migration complete)     |

## Pre-Migration Checklist

Before starting the migration:

```bash
# 1. Document current state
kubectl get nodes -o wide > cluster-a-nodes.txt
kubectl get pods -A > cluster-a-pods.txt
kubectl get pv,pvc -A > cluster-a-storage.txt
kubectl get ingress -A > cluster-a-ingress.txt

# 2. Backup k3s data
sudo k3s etcd-snapshot save --name final-pre-migration

# 3. Verify backup restore capability
# (test this on a separate system if possible)

# 4. Lower DNS TTL (at least 24h before migration)
# Change your DNS records from 3600s to 300s

# 5. Notify stakeholders
# Send maintenance notification

# 6. Prepare Node 4
# Ensure network connectivity, IPMI access, etc.
```

## Communication Plan

| Event                    | Audience         | Timing         |
| ------------------------ | ---------------- | -------------- |
| Migration announcement   | All stakeholders | 1 week before  |
| Phase 2 start (critical) | Ops team         | Real-time      |
| Workload migration start | All stakeholders | At start       |
| DNS cutover              | All stakeholders | At completion  |
| Migration complete       | All stakeholders | After 24h soak |

In the next lesson, we'll audit your existing infrastructure and verify all prerequisites are in place.
