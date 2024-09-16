---
layout: post
title: Testing Control Plane High Availability (L16)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-16
---

In this lesson, we will test and verify the high-availability configuration of
your Kubernetes control plane. Ensuring that your control plane is resilient to
node failures is critical for maintaining cluster stability and continuous
operation. We will simulate node failures and observe the behavior of the
control plane to confirm that the redundancy and load balancing setup is
functioning correctly.

This is the sixteenth lesson in the series on building a production-ready
Kubernetes cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-16)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## Step 1: Verify the Initial High Availability Setup

Before testing any failures, check the current state of the control plane to
ensure that everything is operating as expected:

- Run the following command to list all nodes in your cluster:

  ```bash
  kubectl get nodes
  ```

  All control plane nodes should be listed with a status of "Ready," indicating
  they are healthy and participating in the cluster.

- Check the status of the `etcd` pods and other control plane components to
  ensure they are distributed across all control plane nodes:
  ```bash
  kubectl get pods -n kube-system -o wide
  ```
  Verify that each control plane node is running its respective components (such
  as `etcd`, `kube-apiserver`, `kube-scheduler`, and `kube-controller-manager`).

## Step 2: Simulate a Control Plane Node Failure

To test the high-availability configuration, we will simulate a failure by
shutting down or disconnecting one of the control plane nodes:

- SSH into one of the control plane nodes and simulate a failure by stopping the
  `kubelet` service:

  ```bash
  sudo systemctl stop kubelet
  ```

  Alternatively, you can simulate a network failure by disconnecting the network
  cable or using a firewall rule to block traffic.

- After simulating the failure, check the status of the nodes:
  ```bash
  kubectl get nodes
  ```
  The failed node should eventually be marked as "NotReady," but the cluster
  should continue to operate normally with the remaining control plane nodes.

## Step 3: Verify Failover and Load Balancing

- Check if the virtual IP (VIP) has been moved to another active control plane
  node by running:

  ```bash
  ip addr show
  ```

  The VIP should be present on one of the remaining active nodes.

- Verify that the HAProxy load balancer is still distributing traffic correctly
  to the active control plane nodes. Run the following command from a client
  machine to ensure you can still access the Kubernetes API server:
  ```bash
  curl -k https://192.168.1.100:6443/version
  ```
  This command should return the Kubernetes API server version, confirming that
  traffic is being handled correctly by the remaining nodes.

## Step 4: Restore the Failed Control Plane Node

- Restart the stopped control plane node by starting the `kubelet` service:

  ```bash
  sudo systemctl start kubelet
  ```

  Alternatively, if you disconnected the network cable or blocked traffic,
  reconnect or unblock the node.

- Check the status of the nodes again to ensure that the restored node rejoins
  the cluster and becomes "Ready":
  ```bash
  kubectl get nodes
  ```
  All nodes should be listed as "Ready" once the restoration is complete.

## Step 5: Validate the Control Plane’s Resilience

- Monitor the logs and status of control plane components to ensure there are no
  errors or issues after the simulated failure and restoration. You can view the
  logs of a specific component, such as the API server, using:

  ```bash
  kubectl logs -n kube-system <pod-name>
  ```

  Replace `<pod-name>` with the name of the component pod you want to check.

- Repeat the failure simulation for each control plane node to validate that
  your high-availability configuration is robust and correctly handles different
  failure scenarios.

## Lesson Conclusion

Congratulations! After successfully testing and verifying the high-availability
setup of your control plane, your cluster is now resilient and capable of
maintaining operation even during node failures. In the next section, we will
move on to deploying persistent storage with Longhorn to manage your cluster’s
storage needs effectively.

You have completed this lesson and you can now continue with
[the next section](/building-a-production-ready-kubernetes-cluster-from-scratch/section-7).
