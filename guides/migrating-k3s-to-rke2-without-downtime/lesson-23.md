---
layout: guide-lesson.liquid
title: Decommissioning Cluster A (k3s)

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 5
guide_lesson_id: 23
guide_lesson_abstract: >
  Safely decommission the k3s cluster and prepare Node 1 for joining Cluster B as a worker node.
guide_lesson_conclusion: >
  Cluster A has been safely decommissioned and Node 1 is prepared for OS reinstallation.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-23.md
---

With Cluster B validated and stable, we can safely decommission Cluster A.
This is the point of no return for the k3s cluster.

{% include guide-overview-link.liquid.html %}

## Current State

```mermaid!
flowchart LR
  subgraph A["Cluster A · k3s"]
    A1["🧠 Node 1<br/><small>to decommission</small>"]
  end

  subgraph B["Cluster B · RKE2"]
    B2["🧠 Node 2"]
    B3["🧠 Node 3"]
    B4["🧠 Node 4"]
  end

  A1 -.->|"decommission"| B

  classDef clusterA fill:#9ca3af,color:#fff,stroke:#6b7280
  classDef clusterB fill:#16a34a,color:#fff,stroke:#166534

  class A clusterA
  class B clusterB
```

## Pre-Decommissioning Checklist

Before proceeding, confirm:

- [ ] Cluster B validation passed
- [ ] At least 24-48 hours since DNS cutover
- [ ] No traffic going to Cluster A
- [ ] All stakeholders notified

## Final Backup

Create a final backup of the k3s data:

```bash
ssh root@node1

# Create final etcd snapshot
sudo k3s etcd-snapshot save --name final-backup-$(date +%Y%m%d-%H%M%S)

# Copy backups to safe location
scp -r /var/lib/rancher/k3s/server/db/snapshots/* root@node4:/root/k3s-final-backups/
```

## Verify No Active Traffic

Confirm Cluster A is not receiving traffic:

```bash
sudo journalctl -u k3s --since "1 hour ago" | grep -c "HTTP"
```

Should show zero or minimal activity.

## Stop k3s

```bash
sudo systemctl stop k3s
sudo systemctl disable k3s
```

## Remove k3s Installation

The k3s uninstall script removes all components:

```bash
sudo /usr/local/bin/k3s-uninstall.sh
```

This removes:

- k3s binaries and systemd services
- Configuration in `/etc/rancher/k3s/`
- Data in `/var/lib/rancher/k3s/`
- CNI configurations and iptables rules
- Container images via containerd

## Clean Up Remaining Files

```bash
rm -rf ~/.kube
rm -rf /var/lib/kubelet
rm -rf /etc/kubernetes
```

## Verify Clean State

```bash
# No k3s processes
ps aux | grep k3s

# No kubernetes ports
ss -tlnp | grep -E "6443|10250|2379|2380"

# No k3s files
ls /var/lib/rancher/ 2>/dev/null
ls /etc/rancher/ 2>/dev/null
```

{% include alert.liquid.html type='warning' title='Point of No Return' content='
With k3s uninstalled, there is no rollback to Cluster A.
Ensure Cluster B is fully operational before proceeding to the next lesson.
' %}

## Summary

| Component    | Status                 |
| ------------ | ---------------------- |
| k3s service  | Stopped and removed    |
| k3s binaries | Removed                |
| k3s data     | Backed up and removed  |
| Node 1       | Ready for OS reinstall |

In the next lesson, we'll install Rocky Linux 10 on Node 1 and add it to Cluster B as a worker node.
