---
layout: guide-lesson.liquid
title: Applying Network Policies

guide_component: lesson
guide_id: building-a-production-ready-kubernetes-cluster-from-scratch
guide_section_id: 7
guide_lesson_id: 22
guide_lesson_abstract: >
  Implement **Network Policies** in your Kubernetes cluster to control and secure traffic between pods and other network
  entities.
---

In this lesson, we will implement **Network Policies** in your Kubernetes cluster to control and secure traffic between
pods and other network entities. Network Policies allow you to define rules that determine which pods can communicate
with each other and with external services, providing an additional layer of security and compliance for your cluster.

This is the twenty-second lesson in the series on building a production-ready Kubernetes cluster from scratch. Make sure
you have completed the [previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-21) before
continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## What are Network Policies?

**Network Policies** are a Kubernetes resource that defines rules for controlling the ingress (incoming) and egress
(outgoing) traffic to and from pods. By default, Kubernetes allows unrestricted traffic between all pods in the cluster.
Network Policies enable administrators to enforce security boundaries by restricting traffic to only what is necessary
for the application’s operation. This can help prevent unauthorized access, mitigate potential attacks, and improve the
overall security posture of your cluster.

## Step 1: Understand the Components of a Network Policy

A Network Policy consists of the following components:

- **Pod Selector**: Specifies the pods to which the policy applies, based on labels.
- **Ingress Rules**: Defines the rules for incoming traffic, such as which pods or IP blocks can communicate with the
  selected pods.
- **Egress Rules**: Defines the rules for outgoing traffic, specifying allowed destinations.
- **Policy Types**: Specifies whether the policy applies to `Ingress`, `Egress`, or both.

## Step 2: Create a Basic Network Policy

To create a Network Policy that restricts traffic between pods:

1. **Define a Network Policy YAML File:**

   Create a file named `deny-all-traffic.yaml` to define a basic policy that denies all ingress and egress traffic to
   and from a specific set of pods:

   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: deny-all-traffic
     namespace: default
   spec:
     podSelector: {} # Selects all pods in the namespace
     policyTypes:
       - Ingress
       - Egress
   ```

   This policy denies all traffic to and from all pods in the `default` namespace.

2. **Apply the Network Policy:**

   Run the following command to apply the policy to your Kubernetes cluster:

   ```bash
   kubectl apply -f deny-all-traffic.yaml
   ```

   This policy will block all communication to and from the selected pods, effectively isolating them.

## Step 3: Create a Network Policy to Allow Specific Traffic

Next, create a more granular policy that allows specific traffic. For example, create a policy that allows only incoming
traffic from a specific app:

1. **Define the Network Policy YAML File:**

   Create a file named `allow-app-traffic.yaml`:

   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: allow-app-traffic
     namespace: default
   spec:
     podSelector:
       matchLabels:
         app: my-app # Applies to pods with label 'app: my-app'
     policyTypes:
       - Ingress
     ingress:
       - from:
           - podSelector:
               matchLabels:
                 app: frontend # Allows traffic only from pods with label 'app: frontend'
   ```

   This policy allows only incoming traffic from pods with the label `app: frontend` to pods with the label
   `app: my-app`.

2. **Apply the Network Policy:**

   Run the following command to apply the policy:

   ```bash
   kubectl apply -f allow-app-traffic.yaml
   ```

   This policy will allow incoming traffic only from the designated pods, while all other traffic remains restricted.

## Step 4: Verify Network Policy Configuration

To verify that the Network Policies are applied correctly:

- Use the following command to list all network policies in the `default` namespace:

  ```bash
  kubectl get networkpolicy -n default
  ```

  Ensure that your newly created policies are listed.

- Test the network connectivity by running test pods and attempting to communicate between them. You can use tools like
  `curl` or `ping` to confirm that the traffic is allowed or denied as expected based on the policies.

## Step 5: Extend and Refine Network Policies

As you become more familiar with your application’s traffic patterns and security needs, extend and refine your Network
Policies:

- **Allow traffic to specific ports** to restrict communication to certain services or applications.
- **Use IP blocks** to control traffic between your cluster and external networks.
- **Apply multiple policies** to cover different scenarios and ensure comprehensive network security.

## Lesson Conclusion

Congratulations! By applying Network Policies, you have enhanced the security of your Kubernetes cluster by controlling
and restricting traffic between pods and external networks. In the next section, we will focus on monitoring and logging
to gain better visibility into your cluster's performance and health.

You have completed this lesson and you can now continue with
[the next section](/building-a-production-ready-kubernetes-cluster-from-scratch/section-8).
