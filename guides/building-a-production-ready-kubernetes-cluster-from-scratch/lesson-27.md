---
layout: guide-lesson.liquid
title: Simulating Node Failures and Recovery

guide_component: lesson
guide_id: building-a-production-ready-kubernetes-cluster-from-scratch
guide_section_id: 9
guide_lesson_id: 27
guide_lesson_abstract: >
  Simulate node failures and practice recovery procedures to validate the resilience of your Kubernetes cluster.
---

In this lesson, we will simulate node failures and practice recovery procedures to validate the resilience of your
Kubernetes cluster. Testing how your cluster handles node failures is crucial to ensure high availability and fault
tolerance, allowing you to identify and address any weaknesses in your setup.

This is the twenty-seventh lesson in the series on building a production-ready Kubernetes cluster from scratch. Make
sure you have completed the [previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-26)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## Step 1: Simulate a Worker Node Failure

1. **Identify a Worker Node to Simulate Failure:**

   List all nodes in your cluster and identify a worker node to simulate the failure:

   ```bash
   kubectl get nodes
   ```

   Choose a worker node that you want to test for failure.

2. **Simulate a Node Failure:**

   To simulate a node failure, SSH into the worker node and stop the `kubelet` service:

   ```bash
   sudo systemctl stop kubelet
   ```

   Alternatively, you can simulate a network failure by disconnecting the network cable or blocking traffic using a
   firewall rule.

3. **Observe Cluster Behavior:**

   Monitor the status of the nodes and pods in the cluster to observe how Kubernetes handles the node failure:

   ```bash
   kubectl get nodes
   kubectl get pods -o wide
   ```

   The failed node should eventually be marked as "NotReady," and Kubernetes should automatically reschedule the
   affected pods to other healthy nodes if possible.

## Step 2: Test Control Plane Node Failure

1. **Simulate a Control Plane Node Failure:**

   To simulate a failure of a control plane node, SSH into one of the control plane nodes and stop the `kube-apiserver`:

   ```bash
   sudo systemctl stop kube-apiserver
   ```

   Alternatively, you can shut down the control plane node or disconnect it from the network.

2. **Verify Control Plane High Availability:**

   Check if the Kubernetes API server is still accessible from other control plane nodes:

   ```bash
   kubectl get nodes
   ```

   You should still be able to manage the cluster using `kubectl` commands, indicating that the remaining control plane
   nodes are functioning correctly.

3. **Test Load Balancing and Failover:**

   Verify that the load balancer (such as HAProxy) is correctly handling traffic by ensuring that the virtual IP (VIP)
   is active on another control plane node:

   ```bash
   ip addr show
   ```

   The VIP should be present on one of the remaining active nodes. Test access to the Kubernetes API server using the
   VIP:

   ```bash
   curl -k https://<vip>:6443/version
   ```

   This should return the Kubernetes API server version, confirming that traffic is properly routed to the active nodes.

## Step 3: Restore Failed Nodes

1. **Restore the Worker Node:**

   Restart the `kubelet` service on the failed worker node:

   ```bash
   sudo systemctl start kubelet
   ```

   Alternatively, reconnect the network cable or unblock the node if you simulated a network failure. Check the status
   of the nodes:

   ```bash
   kubectl get nodes
   ```

   The restored node should transition back to the "Ready" state, and any pods that were rescheduled should be
   redistributed.

2. **Restore the Control Plane Node:**

   Restart the `kube-apiserver` on the failed control plane node:

   ```bash
   sudo systemctl start kube-apiserver
   ```

   Alternatively, restart the node or reconnect it to the network. Verify that the restored node rejoins the cluster and
   its components become "Ready":

   ```bash
   kubectl get nodes
   kubectl get pods -n kube-system -o wide
   ```

## Step 4: Validate Cluster Resilience

1. **Check Cluster Health and Logs:**

   Review the logs of the control plane components (`kube-apiserver`, `etcd`, `kube-controller-manager`,
   `kube-scheduler`) to ensure there are no errors or issues:

   ```bash
   kubectl logs -n kube-system <pod-name>
   ```

   Replace `<pod-name>` with the name of the component pod you want to check.

2. **Monitor Alerts and Notifications:**

   Verify that the alerts configured in Grafana are triggered correctly during the simulated failures and that
   notifications are sent to the appropriate channels.

## Step 5: Repeat Failures for All Nodes

To comprehensively test your cluster's resilience, repeat the failure simulations for all control plane and worker
nodes, one at a time. Document any issues or weaknesses you identify during the tests and make necessary adjustments to
your configuration.

## Lesson Conclusion

Congratulations! By simulating node failures and recovery, you have validated your cluster's high availability and fault
tolerance. In the next lesson, we will verify that your security measures and monitoring configurations are working
correctly to protect and maintain your cluster.

You have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-28).
