---
layout: guide-lesson.liquid
title: Testing Control Plane High Availability

guide_component: lesson
guide_id: building-a-production-ready-kubernetes-cluster-from-scratch
guide_section_id: 5
guide_lesson_id: 16
guide_lesson_abstract: >
  Test and verify the high-availability configuration of your Kubernetes control plane.
guide_lesson_conclusion: >
  After successfully testing and verifying the high-availability setup of your control plane, your cluster is now
  resilient and capable of maintaining operation even during node failures
repo_file_path: guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-16.md
---

In this lesson, we will test and verify the high-availability configuration of your Kubernetes control plane. Ensuring
that your control plane is resilient to node failures is critical for maintaining cluster stability and continuous
operation. We will simulate node failures and observe the behavior of the control plane to confirm that the redundancy
and load balancing setup is functioning correctly.

{% include guide-overview-link.liquid.html %}

## Verify the Initial High Availability Setup

Before testing any failures, check the current state of the control plane to ensure that everything is operating as
expected:

Run the following command to list all nodes in your cluster:

```bash
$ kubectl get nodes
NAME                STATUS     ROLES           AGE    VERSION
kubernetes-node-1   Ready      control-plane   2d2h   v1.31.4
kubernetes-node-2   Ready      control-plane   2d2h   v1.31.4
kubernetes-node-3   Ready      control-plane   2d2h   v1.31.4
```

All control plane nodes should be listed with a status of "Ready," indicating they are healthy and participating in the
cluster.

Check the status of the `etcd` pods and other control plane components to ensure they are distributed across all control
plane nodes:

```bash
$ kubectl get pods -n kube-system -o wide
```

Verify that each control plane node is running its respective components (such as `etcd`, `kube-apiserver`,
`kube-scheduler`, and `kube-controller-manager`).

## Deploy a replicated sample application

To test the high-availability setup, we will deploy a replicated sample application that runs on multiple nodes. This
will help us observe how the control plane handles failures and maintains the application's availability.

Create a sample deployment with multiple replicas using the following YAML manifest:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
spec:
  # Define the same amount of replicas as nodes
  replicas: 3
  # The selector is used to match the pods to the deployment
  selector:
    matchLabels:
      app: sample-app
  template:
    # Define the labels used by the selector
    metadata:
      labels:
        app: sample-app
    spec:
      containers:
        - name: sample-app
          image: nginx:latest
          ports:
            - containerPort: 80
      # Define pod anti-affinity to spread the pods across nodes
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: app
                      operator: In
                      values:
                        - sample-app
                topologyKey: "kubernetes.io/hostname"
      # Add tolerations with a short duration to allow rescheduling
      tolerations:
        - key: "node.kubernetes.io/unreachable"
          operator: "Exists"
          effect: "NoExecute"
          tolerationSeconds: 30
        - key: "node.kubernetes.io/not-ready"
          operator: "Exists"
          effect: "NoExecute"
          tolerationSeconds: 30
```

Save this manifest to a file, such as `sample-app.yaml`, and apply it to your cluster:

```bash
$ kubectl apply -f sample-app.yaml
```

This deployment will create three replicas of an Nginx web server and will try to schedule them on different nodes using
pod anti-affinity.

To confirm that the application is running and the pods are distributed across the nodes, run:

```bash
$ kubectl get pods -o wide
NAME                          READY   STATUS    RESTARTS   AGE   IP            NODE
sample-app-6bcd6fdf5b-ks72p   1/1     Running   0          69s   10.244.0.18   kubernetes-node-1
sample-app-6bcd6fdf5b-nnbvq   1/1     Running   0          16s   10.244.1.12   kubernetes-node-2
sample-app-6bcd6fdf5b-tltkt   1/1     Running   0          66s   10.244.2.21   kubernetes-node-3
```

As you can see the three pods are scheduled on different nodes.

## Simulate a Control Plane Node Failure

To test the high-availability configuration, we will simulate a failure by shutting down or disconnecting one of the
control plane nodes:

SSH into one of the control plane nodes and simulate a failure by stopping the `kubelet` service:

```bash
$ sudo systemctl stop kubelet
```

Alternatively, you can simulate a network failure by disconnecting the network cable or using a firewall rule to block
traffic.

After simulating the failure, check the status of the nodes. The failed node should eventually be marked as "NotReady",
but the cluster should continue to operate normally with the remaining control plane nodes:

```bash
$ kubectl get nodes
NAME                STATUS     ROLES           AGE    VERSION
kubernetes-node-1   Ready      control-plane   2d2h   v1.31.4
kubernetes-node-2   NotReady   control-plane   2d2h   v1.31.4
kubernetes-node-3   Ready      control-plane   2d2h   v1.31.4
```

The failed node is now tainted with `node.kubernetes.io/unreachable:NoSchedule` and
`node.kubernetes.io/not-ready:NoExecute` taints, preventing new pods from being scheduled on it. Due to the toleration
timeouts in the sample application deployment, the pods will be rescheduled on the remaining nodes after the 30 seconds
have passed.

```bash
$ kubectl get pods -o wide
NAME                          READY   STATUS        RESTARTS   AGE     IP            NODE                NOMINATED
sample-app-789ff789c4-7x9f5   1/1     Running       0          3m41s   10.244.0.20   kubernetes-node-1
sample-app-789ff789c4-f7n7m   1/1     Running       0          2m11s   10.244.0.21   kubernetes-node-1
sample-app-789ff789c4-qjkkp   1/1     Running       0          3m43s   10.244.2.22   kubernetes-node-3
```

As you can see now, multiple nodes have been scheduled on the remaining nodes, to match the desired number of replicas.

## Restore the Failed Control Plane Node

Restart the stopped control plane node by starting the `kubelet` service:

```bash
$ sudo systemctl start kubelet
```

Alternatively, if you disconnected the network cable or blocked traffic, reconnect or unblock the node.

Check the status of the nodes again to ensure that the restored node rejoins the cluster and becomes "Ready":

```bash
$ kubectl get nodes
NAME                STATUS   ROLES           AGE    VERSION
kubernetes-node-1   Ready    control-plane   2d2h   v1.31.4
kubernetes-node-2   Ready    control-plane   2d2h   v1.31.4
kubernetes-node-3   Ready    control-plane   2d2h   v1.31.4
```

Looking at the pods, you might notice that the pods are not rescheduled back to the restored node. This is because the
tolerations have expired, and the pods will not be rescheduled unless they are deleted and recreated.

```bash
$ kubectl get pods -o wide
NAME                          READY   STATUS    RESTARTS   AGE     IP            NODE                NOMINATED NODE
sample-app-789ff789c4-7x9f5   1/1     Running   0          8m5s    10.244.0.20   kubernetes-node-1
sample-app-789ff789c4-f7n7m   1/1     Running   0          6m35s   10.244.0.21   kubernetes-node-1
sample-app-789ff789c4-qjkkp   1/1     Running   0          8m7s    10.244.2.22   kubernetes-node-3
```

To reschedule the pods on the restored node, you can delete one of the pods running on a node with multiple pods:

```bash
$ kubectl delete pod sample-app-789ff789c4-7x9f5
```

Wait a couple of seconds and the pod is rescheduled on the restored node:

```bash
 $ kubectl get pods -o wide
NAME                          READY   STATUS    RESTARTS   AGE     IP            NODE                NOMINATED NODE   READINESS GATES
sample-app-789ff789c4-f7n7m   1/1     Running   0          7m36s   10.244.0.21   kubernetes-node-1
sample-app-789ff789c4-qjkkp   1/1     Running   0          9m8s    10.244.2.22   kubernetes-node-3
sample-app-789ff789c4-rh7nk   1/1     Running   0          5s      10.244.1.14   kubernetes-node-2
```

# (Optional) Test Availability of the Kubernetes API Server

To test the availability of the Kubernetes API server during a control plane node failure, you can run the following
command on every node at the same time:

````bash
## Cleaning up

After testing the high-availability setup, you can clean up the sample
application deployment by deleting it:

```bash
$ while true; do kubectl get nodes -v=6; sleep 1; done
I0201 18:54:34.844034   14063 loader.go:395] Config loaded from file:  /home/pi/.kube/config
I0201 18:54:34.867009   14063 round_trippers.go:553] GET https://10.1.233.1:6443/api/v1/nodes?limit=500 200 OK in 16 milliseconds
NAME                STATUS     ROLES           AGE   VERSION
kubernetes-node-1   Ready      control-plane   18h   v1.31.5
kubernetes-node-2   Ready      control-plane   49m   v1.31.5
kubernetes-node-3   Ready      control-plane   29m   v1.31.5
...
````

As you can see all nodes are listed with a status of "Ready". Now to test the high-availability setup, we will simulate
a failure by stopping the `kubelet` service on the current HAProxy `MASTER` node, which should be `kubernetes-node-1`:

```bash
$ sudo systemctl stop kubelet
```

You will notice that the output changes to show that the `kubernetes-node-1` is no longer "Ready" and the other nodes
are still operational:

```bash
...
I0201 18:55:38.705804    7675 loader.go:395] Config loaded from file:  /home/pi/.kube/config
I0201 18:55:38.726537    7675 round_trippers.go:553] GET https://10.1.233.1:6443/api/v1/nodes?limit=500 200 OK in 15 milliseconds
NAME                STATUS     ROLES           AGE   VERSION
kubernetes-node-1   NotReady   control-plane   18h   v1.31.5
kubernetes-node-2   Ready      control-plane   50m   v1.31.5
kubernetes-node-3   Ready      control-plane   30m   v1.31.5
...
```

The failed node is now marked as "NotReady" and the other nodes are still operational. This demonstrates that the
control plane is resilient to node failures and can continue to operate with the remaining nodes.

Counter-Theory: If the high-availability would not work, it would not be possible to access the Kubernetes API server on
the other nodes. This would result in an error message like `The connection to the server could not be established` when
running the `kubectl get nodes` command.

{% include alert.liquid.html type='warning' title='Warning:' content='
Do not forget to restart the `kubelet` service on the failed node to restore the high-availability setup.
' %}
