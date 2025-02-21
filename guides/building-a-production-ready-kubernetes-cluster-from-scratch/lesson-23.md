---
layout: guide-lesson.liquid
title: Installing Prometheus and Grafana

guide_component: lesson
guide_id: building-a-production-ready-kubernetes-cluster-from-scratch
guide_section_id: 8
guide_lesson_id: 23
guide_lesson_abstract: >
  Deploy Prometheus and Grafana for real-time monitoring and visualization of your Kubernetes cluster’s performance and
  health.
---

In this lesson, we will install **Prometheus** and **Grafana** in your Kubernetes cluster to monitor and visualize its
performance and health. Prometheus is a powerful open-source monitoring and alerting toolkit, while Grafana is a popular
analytics and visualization platform. Together, they provide comprehensive insights into your cluster's operations,
allowing you to monitor resource usage, detect issues, and optimize performance.

This is the twenty-third lesson in the series on building a production-ready Kubernetes cluster from scratch. Make sure
you have completed the [previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-22) before
continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## What is Prometheus?

**Prometheus** is a time-series database and monitoring system designed specifically for reliability and scalability. It
collects metrics from configured targets (like Kubernetes nodes, pods, and applications) at regular intervals, stores
them, and allows you to query them using PromQL, Prometheus’s query language. Prometheus also supports alerting rules to
notify administrators of potential issues based on metric thresholds.

## What is Grafana?

**Grafana** is an open-source platform for creating, managing, and sharing dashboards and visualizations. It connects to
various data sources, including Prometheus, to display real-time metrics and historical data. Grafana allows you to
create custom dashboards that provide a clear and actionable overview of your Kubernetes cluster's performance.

## Step 1: Deploy Prometheus in Your Kubernetes Cluster

1. **Create a Namespace for Monitoring:**

   First, create a dedicated namespace for Prometheus and Grafana:

   ```bash
   kubectl create namespace monitoring
   ```

2. **Install Prometheus Using Helm:**

   Helm is a package manager for Kubernetes that simplifies the installation of complex applications. Install Prometheus
   using the stable Helm chart:

   - Add the Prometheus Helm repository:

     ```bash
     helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
     helm repo update
     ```

   - Install Prometheus:

     ```bash
     helm install prometheus prometheus-community/prometheus -n monitoring
     ```

   This command installs Prometheus in the `monitoring` namespace with the default configuration.

3. **Verify Prometheus Installation:**

   Check that the Prometheus pods are running correctly:

   ```bash
   kubectl get pods -n monitoring
   ```

   You should see multiple Prometheus pods (such as `prometheus-server` and `prometheus-alertmanager`) in a "Running"
   state.

## Step 2: Deploy Grafana in Your Kubernetes Cluster

1. **Install Grafana Using Helm:**

   Use Helm to install Grafana:

   ```bash
   helm install grafana grafana/grafana -n monitoring
   ```

   This command deploys Grafana in the `monitoring` namespace with default settings.

2. **Expose the Grafana Service:**

   To access the Grafana dashboard, expose it as a NodePort service:

   ```bash
   kubectl patch svc grafana -n monitoring -p '{"spec": {"type": "NodePort"}}'
   ```

   Find the port number assigned to Grafana by running:

   ```bash
   kubectl get svc -n monitoring
   ```

   Note the `NodePort` assigned to the Grafana service.

3. **Access the Grafana Dashboard:**

   Open a web browser and navigate to `http://<node-ip>:<node-port>`, replacing `<node-ip>` with the IP address of any
   cluster node and `<node-port>` with the assigned NodePort. Log in using the default credentials (`admin`/`admin`) and
   change the password when prompted.

## Step 3: Configure Prometheus as a Data Source in Grafana

1. **Add Prometheus as a Data Source:**

   In the Grafana dashboard, go to **Configuration > Data Sources > Add data source**. Select **Prometheus** from the
   list of available data sources.

2. **Enter the Prometheus Server URL:**

   Enter the URL of the Prometheus server (e.g., `http://prometheus-server.monitoring.svc.cluster.local:9090`) and click
   **Save & Test** to verify the connection.

3. **Import Prebuilt Dashboards:**

   Grafana provides a library of prebuilt dashboards for Kubernetes and Prometheus. Go to **Dashboard > Import** and use
   the dashboard IDs (e.g., 315 for Kubernetes cluster monitoring) to import and visualize your cluster’s performance.

## Step 4: Set Up Alerts and Notifications

1. **Create Alerting Rules in Prometheus:**

   Define alerting rules in Prometheus to notify you of potential issues. For example, create a rule to alert when node
   CPU usage exceeds a certain threshold:

   ```yaml
   groups:
     - name: node_alerts
       rules:
         - alert: HighCPUUsage
           expr:
             sum(rate(node_cpu_seconds_total{mode!="idle"}[5m])) by (instance) / sum(rate(node_cpu_seconds_total[5m]))
             by (instance) > 0.8
           for: 5m
           labels:
             severity: warning
           annotations:
             summary: 'High CPU usage detected on {{ $labels.instance }}'
             description: 'Node {{ $labels.instance }} has high CPU usage for more than 5 minutes.'
   ```

   Save this configuration to a file named `prometheus-alert-rules.yaml` and apply it to your Prometheus deployment.

2. **Configure Notification Channels in Grafana:**

   In Grafana, go to **Alerting > Notification Channels** and set up a new notification channel (e.g., email, Slack, or
   PagerDuty) to receive alerts based on Prometheus rules.

## Step 5: Monitor and Visualize Your Cluster

- Use Grafana dashboards to monitor real-time metrics such as CPU usage, memory usage, disk I/O, and network traffic.
- Configure custom dashboards to focus on specific workloads or applications within your cluster.

## Lesson Conclusion

Congratulations! By installing Prometheus and Grafana, you have set up powerful tools to monitor and visualize your
Kubernetes cluster's performance and health. In the next lesson, we will set up the EFK stack (Elasticsearch, Fluentd,
Kibana) for centralized logging and log analysis.

You have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-24).
