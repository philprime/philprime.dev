---
layout: guide-lesson.liquid
title: Benchmark Networking

guide_component: lesson
guide_id: building-a-production-ready-kubernetes-cluster-from-scratch
guide_section_id: 4
guide_lesson_id: 14
guide_lesson_abstract: >
  Test and verify the high-availability configuration of your Kubernetes control plane.
guide_lesson_conclusion: >
  After successfully testing and verifying the high-availability setup of your control plane, your cluster is now
  resilient and capable of maintaining operation even during node failures
repo_file_path: guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-14.md
---

In this lesson, we will test and verify the high-availability configuration of your Kubernetes control plane. Ensuring
that your control plane is resilient to node failures is critical for maintaining cluster stability and continuous
operation. We will simulate node failures and observe the behavior of the control plane to confirm that the redundancy
and load balancing setup is functioning correctly.

{% include guide-overview-link.liquid.html %}

## Verify connection and network speed between pods

To test the network speed between pods, you can use the `iperf3` tool. This tool allows you to measure the network
bandwidth between two pods in your cluster.

To deploy the `iperf3` server pod on every node at the same time, we can use a Kubernetes `DaemonSet`. Connect to one of
your nodes and create a file named `iperf3-daemonset.yaml` with the following content (e.g. using `nano` or `vi`):

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: iperf3
spec:
  selector:
    matchLabels:
      app: iperf3
  template:
    metadata:
      labels:
        app: iperf3
    spec:
      containers:
        - name: iperf3
          image: networkstatic/iperf3
          ports:
            - containerPort: 5201
          command: ["iperf3"]
          args: ["-s"] # Run in server mode
```

Apply the DaemonSet configuration to deploy the `iperf3` server pods:

```bash
$ kubectl apply -f iperf3-daemonset.yaml
```

Get the list of pods to verify that the `iperf3` server pods are running:

```bash
$ kubectl get pods -l app=iperf3 -o wide
NAME           READY   STATUS    RESTARTS   AGE     IP           NODE                NOMINATED NODE   READINESS GATES
iperf3-b7tp5   1/1     Running   0          5m45s   10.244.0.6   kubernetes-node-1   <none>           <none>
iperf3-g4k2b   1/1     Running   0          5m45s   10.244.2.4   kubernetes-node-3   <none>           <none>
iperf3-zztwd   1/1     Running   0          5m45s   10.244.1.5   kubernetes-node-2   <none>           <none>
```

Create an interactive shell session in one of the `iperf3` server pods to check the network speed:

```bash
$ kubectl exec -it iperf3-b7tp5 -- /bin/bash
```

Run the following command to test the network speed to one of the other `iperf3` server pods:

```bash
root@iperf3-pgt7j:/# iperf3 -c 10.244.2.9
Connecting to host 10.244.2.9, port 5201
[  5] local 10.244.0.9 port 48980 connected to 10.244.2.9 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-1.00   sec   111 MBytes   933 Mbits/sec    0   3.87 MBytes
[  5]   1.00-2.00   sec   109 MBytes   912 Mbits/sec    0   3.87 MBytes
[  5]   2.00-3.00   sec   109 MBytes   912 Mbits/sec    0   3.87 MBytes
[  5]   3.00-4.00   sec   108 MBytes   902 Mbits/sec    0   3.87 MBytes
[  5]   4.00-5.00   sec   109 MBytes   912 Mbits/sec    0   3.87 MBytes
[  5]   5.00-6.00   sec   108 MBytes   902 Mbits/sec    0   3.87 MBytes
[  5]   6.00-7.00   sec   109 MBytes   912 Mbits/sec    0   3.87 MBytes
[  5]   7.00-8.00   sec   109 MBytes   912 Mbits/sec    0   3.87 MBytes
[  5]   8.00-9.00   sec   109 MBytes   912 Mbits/sec    0   3.87 MBytes
[  5]   9.00-10.00  sec   108 MBytes   902 Mbits/sec    0   3.87 MBytes
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-10.00  sec  1.06 GBytes   911 Mbits/sec    0             sender
[  5]   0.00-10.03  sec  1.06 GBytes   909 Mbits/sec                  receiver

iperf Done.
```

Cleanup the `iperf3` server pods after you are done testing:

```bash
$ kubectl delete -f iperf3-daemonset.yaml
$ rm iperf3-daemonset.yaml
```
