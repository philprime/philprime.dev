---
layout: post
title: Setting Up the EFK Stack (Elasticsearch, Fluentd, Kibana) (L24)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-24
---

In this lesson, we will set up the **EFK stack**—comprising **Elasticsearch**,
**Fluentd**, and **Kibana**—in your Kubernetes cluster to enable centralized
logging and log analysis. The EFK stack allows you to aggregate logs from all
your cluster nodes and applications, providing powerful search and visualization
capabilities for monitoring and troubleshooting.

This is the twenty-fourth lesson in the series on building a production-ready
Kubernetes cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-23)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## What is the EFK Stack?

The **EFK stack** is a popular solution for centralized logging in Kubernetes
environments:

- **Elasticsearch** is a distributed search and analytics engine that stores log
  data and allows you to search, analyze, and visualize logs in near real-time.
- **Fluentd** is an open-source data collector that gathers logs from various
  sources, processes them, and forwards them to destinations like Elasticsearch.
- **Kibana** is a web-based data visualization tool that provides a user
  interface to search, analyze, and visualize log data stored in Elasticsearch.

## Step 1: Deploy Elasticsearch in Your Kubernetes Cluster

1. **Create a Namespace for Logging:**

   Create a dedicated namespace for the EFK stack components:

   ```bash
   kubectl create namespace logging
   ```

2. **Install Elasticsearch Using Helm:**

   Use Helm to install Elasticsearch:

   - Add the Elastic Helm repository:

     ```bash
     helm repo add elastic https://helm.elastic.co
     helm repo update
     ```

   - Install Elasticsearch:

     ```bash
     helm install elasticsearch elastic/elasticsearch -n logging
     ```

   This command installs Elasticsearch in the `logging` namespace with the
   default configuration.

3. **Verify Elasticsearch Installation:**

   Check the status of the Elasticsearch pods to ensure they are running:

   ```bash
   kubectl get pods -n logging
   ```

   You should see the `elasticsearch-master` pods in a "Running" state.

## Step 2: Deploy Fluentd in Your Kubernetes Cluster

1. **Install Fluentd Using Helm:**

   Use Helm to deploy Fluentd, configured to forward logs to Elasticsearch:

   - Add the Fluentd Helm repository:

     ```bash
     helm repo add fluent https://fluent.github.io/helm-charts
     helm repo update
     ```

   - Install Fluentd:

     ```bash
     helm install fluentd fluent/fluentd -n logging --set aggregator.enabled=true --set backend.type=es --set backend.es.host=elasticsearch-master.logging.svc.cluster.local
     ```

   This command installs Fluentd in the `logging` namespace and configures it to
   forward logs to the Elasticsearch service.

2. **Verify Fluentd Installation:**

   Check the status of the Fluentd pods:

   ```bash
   kubectl get pods -n logging
   ```

   Ensure that the Fluentd pods are in a "Running" state.

## Step 3: Deploy Kibana in Your Kubernetes Cluster

1. **Install Kibana Using Helm:**

   Use Helm to install Kibana:

   ```bash
   helm install kibana elastic/kibana -n logging --set service.type=NodePort
   ```

   This command deploys Kibana in the `logging` namespace and exposes it via a
   NodePort service.

2. **Expose the Kibana Service:**

   Find the NodePort assigned to Kibana by running:

   ```bash
   kubectl get svc -n logging
   ```

   Note the `NodePort` assigned to the Kibana service.

3. **Access the Kibana Dashboard:**

   Open a web browser and navigate to `http://<node-ip>:<node-port>`, replacing
   `<node-ip>` with the IP address of any cluster node and `<node-port>` with
   the assigned NodePort. You should see the Kibana login screen.

## Step 4: Configure Kibana to Use Elasticsearch

1. **Connect Kibana to Elasticsearch:**

   In the Kibana dashboard, go to **Management > Stack Management > Index
   Patterns** and create a new index pattern that matches the log indices (e.g.,
   `fluentd-*`).

2. **Visualize and Search Logs:**

   Use Kibana’s tools to search, filter, and visualize log data collected from
   your Kubernetes cluster. You can create dashboards, set up alerts, and
   monitor your cluster's log data in real time.

## Step 5: Verify Centralized Logging

To verify that the EFK stack is correctly set up:

- Generate some logs in your cluster by deploying sample applications or
  generating traffic.
- Check the Fluentd logs to ensure it is collecting logs from your nodes and
  forwarding them to Elasticsearch:

  ```bash
  kubectl logs <fluentd-pod-name> -n logging
  ```

- In Kibana, check that log data from your cluster is indexed and available for
  search and visualization.

## Lesson Conclusion

Congratulations! With the EFK stack installed and configured, you now have a
centralized logging solution for your Kubernetes cluster, providing powerful
insights and troubleshooting capabilities. In the next lesson, we will create
alerts and dashboards in Grafana to monitor critical metrics and receive
notifications of potential issues.

You have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-25).
