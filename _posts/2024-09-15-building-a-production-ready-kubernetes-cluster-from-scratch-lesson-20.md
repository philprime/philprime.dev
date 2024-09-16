---
layout: course-lesson
title: Implementing Role-Based Access Control (RBAC) (L20)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-20
---

In this lesson, we will implement **Role-Based Access Control (RBAC)** in your
Kubernetes cluster to manage and secure access to resources. RBAC is a powerful
mechanism that allows you to define who can access what resources and what
actions they can perform, ensuring that your cluster remains secure and
compliant with organizational policies.

This is the twentieth lesson in the series on building a production-ready
Kubernetes cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-19)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## What is Role-Based Access Control (RBAC)?

**Role-Based Access Control (RBAC)** is a method of regulating access to
resources based on the roles assigned to users or groups within an organization.
In Kubernetes, RBAC allows administrators to create granular policies that
define which users or service accounts can perform specific actions (like
reading, writing, or modifying resources) on different objects within the
cluster. By using RBAC, you can ensure that only authorized users have access to
sensitive operations and resources, thereby reducing the risk of accidental or
malicious changes.

## Step 1: Understand Kubernetes RBAC Components

Before implementing RBAC, it is important to understand its core components:

- **Roles and ClusterRoles:** A **Role** defines a set of permissions within a
  specific namespace, while a **ClusterRole** defines permissions cluster-wide.
  Both are used to specify what actions (verbs) are allowed on which resources
  (like pods, services, etc.).

- **RoleBindings and ClusterRoleBindings:** A **RoleBinding** grants permissions
  defined in a Role to a user, group, or service account within a specific
  namespace. A **ClusterRoleBinding** grants cluster-wide permissions defined in
  a ClusterRole.

## Step 2: Create a Role for Namespace Access

To create a Role that allows read-only access to all resources in a specific
namespace:

1. **Define the Role in a YAML file:** Create a file named
   `read-only-role.yaml`:

   ```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: Role
   metadata:
     namespace: default
     name: read-only-role
   rules:
     - apiGroups: ['']
       resources: ['pods', 'services', 'endpoints', 'configmaps']
       verbs: ['get', 'list', 'watch']
   ```

   This Role grants read-only access (`get`, `list`, `watch`) to pods, services,
   endpoints, and configmaps in the `default` namespace.

2. **Apply the Role to the Cluster:**

   Run the following command to create the Role in your Kubernetes cluster:

   ```bash
   kubectl apply -f read-only-role.yaml
   ```

## Step 3: Create a RoleBinding to Assign the Role

To assign the newly created Role to a user or service account:

1. **Define the RoleBinding in a YAML file:** Create a file named
   `read-only-binding.yaml`:

   ```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: RoleBinding
   metadata:
     name: read-only-binding
     namespace: default
   subjects:
     - kind: User
       name: jane-doe # Replace with the actual user
       apiGroup: rbac.authorization.k8s.io
   roleRef:
     kind: Role
     name: read-only-role
     apiGroup: rbac.authorization.k8s.io
   ```

   This RoleBinding grants the `read-only-role` permissions to the user
   `jane-doe` in the `default` namespace.

2. **Apply the RoleBinding to the Cluster:**

   Run the following command to create the RoleBinding in your Kubernetes
   cluster:

   ```bash
   kubectl apply -f read-only-binding.yaml
   ```

## Step 4: Verify RBAC Configuration

To verify that RBAC is configured correctly:

- Test access by logging in as the user `jane-doe` and attempting to list the
  resources:

  ```bash
  kubectl auth can-i list pods --namespace=default --as=jane-doe
  ```

  This command should return "yes," indicating that the user has the correct
  permissions. Attempting to perform any actions outside the defined permissions
  should result in an error.

## Step 5: Managing Cluster-Wide Permissions

For cluster-wide permissions, create a `ClusterRole` and `ClusterRoleBinding`
instead of a Role and RoleBinding. Use a similar YAML structure but replace
`Role` with `ClusterRole` and `RoleBinding` with `ClusterRoleBinding`.

## Lesson Conclusion

Congratulations! With RBAC implemented, you have taken an important step in
securing your Kubernetes cluster by controlling access to its resources. In the
next lesson, we will enable mutual TLS authentication to secure communication
between Kubernetes components further.

You have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-21).
