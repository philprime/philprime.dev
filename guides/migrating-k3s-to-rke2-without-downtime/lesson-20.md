---
layout: guide-lesson.liquid
title: Deploying Workloads to Cluster B

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 4
guide_lesson_id: 20
guide_lesson_abstract: >
  Deploy application workloads to Cluster B using the exported manifests.
guide_lesson_conclusion: >
  All workloads are deployed and running on Cluster B, ready for traffic cutover.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-20.md
---

With storage configured and data migrated, deploy your workloads to Cluster B using the manifests exported in [Lesson 16](/guides/migrating-k3s-to-rke2-without-downtime/lesson-16).

{% include guide-overview-link.liquid.html %}

## Deployment Order

Deploy resources in dependency order:

| Order | Resource            | Why                                               |
| ----- | ------------------- | ------------------------------------------------- |
| 1     | Namespaces          | Container for all other resources                 |
| 2     | Secrets, ConfigMaps | Configuration needed by pods                      |
| 3     | PVCs                | Storage must exist before pods reference it       |
| 4     | Services            | DNS entries available before pods start           |
| 5     | StatefulSets        | Databases before applications that depend on them |
| 6     | Deployments         | Application workloads                             |
| 7     | Ingress             | External access after services exist              |
| 8     | NetworkPolicies     | Security rules last                               |

## Applying Manifests

Connect to Cluster B and apply your exported manifests:

```bash
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
cd /root/cluster-a-export
```

Apply resources using `kubectl apply -f` in the order above.
Wait for each resource type to be ready before proceeding to the next.

{% include alert.liquid.html type='info' title='Application-Specific' content='
The exact deployment process depends on your applications.
Some may have dependencies requiring specific ordering.
Others may need configuration updates for the new environment.
' %}

## Common Adjustments

Before applying manifests, review and update:

| Resource    | Check For                      |
| ----------- | ------------------------------ |
| PVCs        | Storage class names may differ |
| Ingress     | Ingress class annotations      |
| Services    | NodePort conflicts             |
| Deployments | Node selectors or affinities   |

## Verification

After deploying each namespace:

```bash
# Check pod status
kubectl get pods -n <namespace>

# Check for issues
kubectl describe pod -n <namespace> <pod-name>

# Check logs
kubectl logs -n <namespace> <pod-name>
```

All pods should reach Running state.
Services should have endpoints.
Ingress resources should be recognized by Traefik.

## Troubleshooting

### Pods in Pending

Check events with `kubectl describe pod`.
Common causes: insufficient resources, PVC not bound, node selector issues.

### Pods in CrashLoopBackOff

Check logs with `kubectl logs`.
Common causes: missing secrets/configmaps, database connection failures, configuration errors.

### Services Have No Endpoints

Verify pod labels match service selector.
Ensure pods are in Running state.

## Verification Checklist

- [ ] All namespaces created
- [ ] Secrets and ConfigMaps deployed
- [ ] PVCs bound
- [ ] StatefulSets running
- [ ] Deployments running
- [ ] Services have endpoints
- [ ] Ingress resources created
- [ ] All pods in Running state

In the next lesson, we'll perform the DNS cutover to switch traffic from Cluster A to Cluster B.
