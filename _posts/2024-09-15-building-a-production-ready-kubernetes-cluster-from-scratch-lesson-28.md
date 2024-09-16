---
layout: course-lesson
title: Verifying Security and Monitoring Configurations (L28)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-28
---

In this lesson, we will verify that the security measures and monitoring
configurations you have implemented are working correctly. Ensuring that your
cluster's security and monitoring setups are robust is crucial for maintaining a
secure, stable, and well-functioning Kubernetes environment.

This is the second lesson in the series on building a production-ready
Kubernetes cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-27)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## Step 1: Verify Role-Based Access Control (RBAC) Settings

1. **Review RBAC Roles and Bindings:**

   List all roles and role bindings in your cluster to ensure they are correctly
   configured:

   ```bash
   kubectl get roles --all-namespaces
   kubectl get rolebindings --all-namespaces
   kubectl get clusterroles
   kubectl get clusterrolebindings
   ```

   Verify that each role and binding aligns with your security policies. Check
   that users and service accounts have the appropriate permissions and that no
   unnecessary privileges are granted.

2. **Test RBAC Restrictions:**

   Test the RBAC configurations by attempting to perform actions with different
   user roles:

   - Use the following command to simulate a user trying to list pods in a
     namespace:

     ```bash
     kubectl auth can-i list pods --namespace=<namespace> --as=<username>
     ```

   - Replace `<namespace>` with the namespace to check and `<username>` with the
     user you want to test. This should return "yes" or "no" depending on the
     user's permissions.

3. **Review and Adjust RBAC Policies:**

   If you find any discrepancies or over-permissive roles, adjust your RBAC
   policies to align with the principle of least privilege:

   ```bash
   kubectl edit role <role-name> -n <namespace>
   kubectl edit clusterrole <clusterrole-name>
   ```

## Step 2: Validate Network Policies

1. **List and Review Network Policies:**

   List all network policies in each namespace to ensure they are correctly
   defined:

   ```bash
   kubectl get networkpolicy --all-namespaces
   ```

   Review each policy to confirm that they enforce the desired traffic rules and
   that unnecessary communication is restricted.

2. **Test Network Policy Effectiveness:**

   Use test pods to validate that network policies are functioning as intended:

   - Deploy a test pod in a namespace and attempt to access another pod in the
     same or different namespace:

     ```bash
     kubectl run test-pod --image=busybox --rm -it -- /bin/sh
     ```

   - Inside the test pod, try to `curl` or `ping` other pods or services. Ensure
     that traffic is allowed or denied according to the network policies.

## Step 3: Confirm Mutual TLS (mTLS) Configuration

1. **Check mTLS Status:**

   Verify that mutual TLS is correctly configured between all Kubernetes
   components:

   - Check the configuration files of the Kubernetes API server, `etcd`, and
     `kubelet` to ensure they use valid certificates:

     ```bash
     sudo cat /etc/kubernetes/pki/apiserver.crt
     sudo cat /etc/kubernetes/pki/etcd/etcd-server.crt
     sudo cat /etc/kubernetes/pki/kubelet/kubelet-client.crt
     ```

   - Verify that the certificates are not expired and match the intended
     configurations.

2. **Monitor Component Logs for mTLS Errors:**

   Use `kubectl logs` or `journalctl` to check for any errors or warnings
   related to TLS communication between Kubernetes components:

   ```bash
   kubectl logs -n kube-system <component-pod-name>
   ```

   Replace `<component-pod-name>` with the relevant pod name (e.g.,
   `kube-apiserver`, `etcd`). Look for any errors related to certificate
   validation or failed secure connections.

## Step 4: Validate Monitoring and Alerts

1. **Review Grafana Dashboards:**

   Access your Grafana dashboards and verify that all critical metrics (such as
   CPU usage, memory usage, network traffic, etc.) are being monitored
   correctly.

   - Ensure that the dashboards are up-to-date and display real-time data.
   - Check for any missing data points or gaps that could indicate monitoring
     issues.

2. **Test Alerting Mechanisms:**

   Trigger test alerts in Grafana to ensure your alerting rules and notification
   channels are correctly configured:

   - Go to **Alerting > Notification Channels** in Grafana and use the **Send
     Test** feature to verify that notifications are sent to the right channels
     (e.g., email, Slack).

   - Simulate conditions that should trigger alerts (e.g., high CPU usage or
     network latency) and ensure that alerts are generated and notifications are
     sent.

## Step 5: Verify Centralized Logging with the EFK Stack

1. **Check Fluentd Logs:**

   Ensure Fluentd is correctly collecting logs from your nodes and forwarding
   them to Elasticsearch:

   ```bash
   kubectl logs -n logging <fluentd-pod-name>
   ```

   Look for any errors or issues that indicate problems with log collection or
   forwarding.

2. **Search Logs in Kibana:**

   Access the Kibana dashboard and search for logs from different applications
   and nodes:

   - Verify that logs are indexed correctly and are searchable in Kibana.
   - Test different filters and queries to ensure all expected logs are present.

## Lesson Conclusion

Congratulations! By verifying your security measures and monitoring
configurations, you have ensured that your cluster is secure, observable, and
well-monitored. In the next section, we will focus on regular maintenance and
updates to keep your Kubernetes cluster secure and up-to-date.

You have completed this lesson and you can now continue with
[the next section](/building-a-production-ready-kubernetes-cluster-from-scratch/section-10).
