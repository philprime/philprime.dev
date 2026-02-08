---
layout: guide-revisions.liquid
title: Revision History

guide_component: revisions
guide_id: migrating-k3s-to-rke2-without-downtime
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/revisions.md
---

## Revision History

This page tracks all changes and updates to this guide.

### Version 1.0.0 (Initial Release)

**Date**: 2024-02

**Summary**: Initial publication of the migration guide.

**Contents**:

- **Section 1: Introduction and Migration Strategy** (Lessons 1-4)
  - Migration overview and objectives
  - k3s vs RKE2 comparison
  - Detailed migration strategy with risk assessment
  - Prerequisites and infrastructure audit checklist

- **Section 2: Preparing Rocky Linux and RKE2 Environment** (Lessons 5-10)
  - Rocky Linux 9 installation and configuration
  - Hetzner vSwitch networking setup
  - Firewalld configuration for Kubernetes
  - RKE2 server installation (first control plane)
  - Cilium CNI installation with eBPF
  - Initial cluster verification

- **Section 3: Migrating Nodes to the New Cluster** (Lessons 11-15)
  - Node preparation for migration
  - Critical 2-node transition handling
  - Adding nodes to RKE2 control plane
  - Achieving 3-node HA configuration
  - HA verification procedures

- **Section 4: Workload Migration and Cutover** (Lessons 16-21)
  - Exporting workload manifests
  - Longhorn and local-path storage setup
  - Traefik DaemonSet with Hetzner Load Balancer
  - Persistent volume migration strategies
  - Workload deployment to new cluster
  - DNS cutover procedures

- **Section 5: Cluster Consolidation and Cleanup** (Lessons 22-25)
  - Final validation before decommissioning
  - k3s cluster decommissioning
  - Adding final node as RKE2 worker
  - Post-migration cleanup and documentation

**Technical Stack**:

- Host OS: Rocky Linux 9
- Kubernetes: RKE2
- CNI: Cilium
- Storage: Longhorn + local-path-provisioner
- Ingress: Traefik (DaemonSet) + Hetzner Cloud Load Balancer

---

## Planned Updates

The following updates are planned for future revisions:

- [ ] Adding section on Velero backup integration
- [ ] cert-manager configuration for automatic TLS
- [ ] External secrets management
- [ ] GitOps workflow with Flux or ArgoCD
- [ ] Multi-cluster management with Rancher

---

## Contributing

If you find errors or have suggestions for improvements:

1. Open an issue on the [GitHub repository](https://github.com/philprime/philprime.dev)
2. Submit a pull request with your proposed changes
3. Contact the author through the website

---

## Acknowledgments

Thanks to all contributors and reviewers who helped improve this guide.
