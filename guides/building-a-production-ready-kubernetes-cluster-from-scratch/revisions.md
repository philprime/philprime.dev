---
layout: guide-revisions.liquid

guide_component: revisions
guide_id: building-a-production-ready-kubernetes-cluster-from-scratch
---

## Revision History

This page tracks all changes and updates to this guide.

## Changes

- 2026-11-15 - Corrected [host versus forwarded UFW rules and pod-to-kubelet access](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-12), and [Longhorn networking guidance](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-17)

  [Lesson 10](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-10) keeps the existing kubelet rules
  for TCP port `10250`. The explicit localhost allowances for the obsolete
  scheduler and controller-manager ports `10251` and `10252` were removed. Their secure endpoints use `10259` and
  `10257` and bind to loopback in this kubeadm setup, where UFW already permits traffic. Removing those redundant
  allowances does not broaden access.

  [Lesson 12](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-12) adds access from local pods to
  their node's kubelet, needed by components such as metrics-server. The rule
  is limited to the node's assigned pod CIDR, the `cni0` interface, the node's IP address, and TCP port `10250`.

- 2026-11-15 - Added [kubelet resource reservations](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-11) and [cluster DNS availability checks](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-16)
- 2026-11-15 - Added [HAProxy readiness checks and Keepalived service tracking](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-15), and clarified [HA failure-test limits](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-16)

  [Lesson 15](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-15) configures the virtual IP only
  in Keepalived's `virtual_ipaddress` block. A `static_ipaddress` assignment is independent of the VRRP MASTER/BACKUP
  role and can leave the VIP assigned on multiple nodes. Letting the VRRP instance manage the address allows a BACKUP
  to acquire it when the MASTER fails.

  Keepalived also tracks the local HAProxy service through a `vrrp_script` referenced by each node's `track_script`.
  Without this check, a node can retain the VIP even when HAProxy has stopped, leaving clients with no working load
  balancer. The script checks service activity every two seconds. Two consecutive failures put the VRRP instance
  into FAULT, allowing a healthy BACKUP to take over, and two consecutive successes clear the script failure.
  This checks whether the service is active, not whether it is successfully handling requests.

  HAProxy checks each API server separately using HTTPS `GET /readyz` and requires HTTP `200`. A TCP connection alone
  does not establish that an API server is ready to serve requests. The `check-ssl` setting enables TLS for the
  health probe, while `verify none` skips certificate verification for that probe only. Client TLS connections still
  pass through unchanged. The lesson also notes that the cluster CA can be used to authenticate the probe's backend.

  The VRRP password explanation clarifies that all nodes must use the same value, only the first eight characters
  are used, and PASS authentication does not encrypt traffic or replace network access controls. The fictitious
  `password123` example remains in the configuration.

  Configuration-validation commands check HAProxy and Keepalived before reloading them.

  [Lesson 16](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-16) distinguishes a kubelet heartbeat
  interruption from a complete node failure. Stopping kubelet can mark a node `NotReady` while existing containers,
  including API server and etcd containers, continue running. HAProxy and Keepalived also remain active. The headings,
  instructions, and conclusions now describe what this test demonstrates without claiming full node-failure resilience.
  Network disconnection is no longer presented as an interchangeable step in the heartbeat test.

  The readiness and CoreDNS placement checks identify prerequisites and possible DNS availability risks; they do not
  test DNS failover. The precautions call for healthy control-plane and etcd members, a current etcd snapshot,
  recovery access, and testing one node at a time. A three-member etcd cluster needs two available members for quorum.

  A separate load-balancer test stops HAProxy on the actual VIP owner to exercise Keepalived's service tracking.
  API requests from another healthy node use the VIP, allowing the reader to check that a BACKUP acquires the address
  and requests recover. Services are restored and cluster health checked between tests so that failures remain isolated.
  This tests load-balancer service failover, not the loss of an entire control-plane node.

- 2025-02-25 - Initial release of the guide
- 2025-03-16 - Added warning about microSD cards and updated hardware recommendations
- 2025-03-22 - Changed container runtime setup to use NVMe drive for storage
- 2025-03-22 - Added comments to `ufw` rules to clarify the purpose of each rule
- 2025-03-22 - Added instructions to install `etcdctl` to recover from etcd cluster health issues

## Contributing

If you find errors or have suggestions for improvements:

1. Open an issue on the [GitHub repository](https://github.com/philprime/philprime.dev)
2. Submit a pull request with your proposed changes
3. Contact the author through the website

## Acknowledgments

Thanks to all contributors and reviewers who helped improve this guide.
