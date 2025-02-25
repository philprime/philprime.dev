---
layout: guide-lesson.liquid
title: Creating Alerts and Dashboards

guide_component: lesson
guide_id: building-a-production-ready-kubernetes-cluster-from-scratch
guide_section_id: 8
guide_lesson_id: 25
guide_lesson_abstract: >
  Create alerts and dashboards in Grafana to monitor critical metrics and receive notifications of potential issues in
  your Kubernetes cluster.
---

In this lesson, we will create **alerts and dashboards** in Grafana to monitor critical metrics and receive
notifications of potential issues in your Kubernetes cluster. Effective monitoring and alerting are essential for
maintaining cluster health, ensuring performance, and quickly responding to any problems that arise.

This is the twenty-fifth lesson in the series on building a production-ready Kubernetes cluster from scratch. Make sure
you have completed the [previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-24) before
continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## Step 1: Create Custom Dashboards in Grafana

1. **Log in to Grafana:**

   Open your web browser and navigate to the Grafana dashboard using the NodePort or IP address you configured in
   Lesson 23. Log in using your credentials.

2. **Add a New Dashboard:**

   - Go to **Dashboards > New Dashboard**.
   - Click on **Add New Panel**. This will open the panel editor where you can define the visualizations.

3. **Configure Panels for Key Metrics:**

   Select **Prometheus** as your data source and use PromQL queries to visualize critical metrics. Here are some example
   queries:

   - **Node CPU Usage:**

     ```promql
     100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
     ```

   - **Node Memory Usage:**

     ```promql
     node_memory_Active_bytes / node_memory_MemTotal_bytes * 100
     ```

   - **Pod Status:**

     ```promql
     sum(kube_pod_status_ready{condition="true"}) by (namespace)
     ```

   - **Network Traffic:**
     ```promql
     rate(node_network_receive_bytes_total[5m])
     ```

   Adjust the visualizations (graphs, gauges, tables) as needed to fit your monitoring needs.

4. **Save and Organize the Dashboard:**

   - Click **Apply** to save each panel.
   - Organize the panels to create a cohesive dashboard view that provides a quick overview of cluster health and
     performance.

## Step 2: Set Up Alerts in Grafana

1. **Create Alerting Rules:**

   To create an alert, click on a panel where you want to set up monitoring and go to the **Alert** tab in the panel
   editor.

2. **Define Alert Conditions:**

   - Set the conditions for the alert based on the metric data. For example, to trigger an alert if node CPU usage
     exceeds 80%, use the following settings:
     - **WHEN**: `avg() of query (A, 5m, now) > 80`
     - **IF**: `A` is the query defined for node CPU usage.
   - Configure the evaluation interval (e.g., every 1 minute).

3. **Configure Notification Channels:**

   - Go to **Alerting > Notification Channels**.
   - Add a new notification channel (e.g., email, Slack, PagerDuty).
   - Provide the required settings (email addresses, Slack webhook URL, etc.).

4. **Assign Notification Channels to Alerts:**

   In the alert settings, choose the notification channel(s) to send alerts to when conditions are met.

5. **Test and Save Alerts:**

   - Test the alert by clicking **Test Rule** in the alert tab.
   - If the test is successful, click **Save** to finalize the alert configuration.

## Step 3: Monitor Alerts and Dashboards

1. **Review and Refine Dashboards:**

   Continuously monitor your Grafana dashboards to ensure they provide the necessary insights. Adjust queries,
   visualizations, and alert rules as needed to focus on the most critical aspects of your cluster.

2. **Respond to Alerts:**

   When an alert is triggered, Grafana sends notifications via the configured channels. Review the alert details and
   logs in Kibana or the Grafana dashboard to diagnose the issue and take appropriate action.

## Step 4: Create Multi-Cluster Dashboards (Optional)

If you manage multiple Kubernetes clusters, consider setting up multi-cluster dashboards in Grafana to visualize and
compare metrics across clusters:

- Use multiple data sources in Grafana, each representing a different Prometheus instance.
- Create custom dashboards that aggregate and display metrics from multiple clusters in a single view.

## Lesson Conclusion

Congratulations! By setting up alerts and dashboards in Grafana, you have established a robust monitoring system for
your Kubernetes cluster, allowing you to proactively identify and respond to potential issues. In the next section, we
will focus on testing and validating cluster resilience to ensure it meets your reliability and performance goals.

You have completed this lesson and you can now continue with
[the next section](/building-a-production-ready-kubernetes-cluster-from-scratch/section-9).
