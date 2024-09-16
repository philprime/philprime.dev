---
layout: post
title: Testing and Optimizing Longhorn Performance (L19)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-19
---

In this lesson, we will test and optimize the performance of your Longhorn
storage setup to ensure that it meets the needs of your applications running in
the Kubernetes cluster. By understanding how your storage performs under
different conditions and applying optimizations, you can ensure data
reliability, reduce latency, and improve overall cluster efficiency.

This is the nineteenth lesson in the series on building a production-ready
Kubernetes cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-18)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## Step 1: Benchmarking Longhorn Performance

Before optimizing, it is important to understand the current performance of your
Longhorn setup. You can use benchmarking tools like **fio** (Flexible I/O
Tester) to simulate different workloads and measure read/write speeds, latency,
and IOPS (Input/Output Operations Per Second).

1. **Install fio on a Test Pod:**

   Deploy a simple test pod with the `fio` benchmarking tool. Create a YAML file
   named `fio-test-pod.yaml`:

   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: fio-test
   spec:
     containers:
       - name: fio
         image: axboe/fio
         volumeMounts:
           - name: test-volume
             mountPath: /mnt/test
     volumes:
       - name: test-volume
         persistentVolumeClaim:
           claimName: test-claim
   ```

   Make sure the `test-claim` PVC is using the Longhorn storage class. Apply the
   YAML file:

   ```bash
   kubectl apply -f fio-test-pod.yaml
   ```

2. **Run the Benchmark Tests:**

   Once the pod is running, execute the `fio` test inside the pod to measure
   read and write performance:

   ```bash
   kubectl exec -it fio-test -- fio --name=readwrite --rw=randrw --bs=4k --size=1G --numjobs=4 --runtime=60 --group_reporting --directory=/mnt/test
   ```

   This command runs a random read/write test with a 4KB block size, simulating
   a mix of read and write operations over 1GB of data for 60 seconds.

3. **Analyze the Results:**

   Review the output of the `fio` test to see metrics such as IOPS, latency, and
   throughput. Use these results to identify any performance bottlenecks or
   areas for improvement.

## Step 2: Optimizing Longhorn Storage Performance

Based on your benchmarking results, apply the following optimizations to improve
storage performance:

1. **Adjust Replica Counts:**

   Lowering the number of replicas in the storage class can improve write
   performance, but at the cost of reduced fault tolerance. Adjust the
   `numberOfReplicas` parameter in your storage class YAML to find the right
   balance between performance and redundancy.

2. **Enable Data Locality:**

   Longhorn's data locality feature ensures that data is stored on the same node
   where the volume is attached, reducing network latency for read and write
   operations. To enable this feature, set `Data Locality` to `Best Effort` in
   the Longhorn UI or via the Longhorn API.

3. **Tune Block Size:**

   Experiment with different block sizes in your storage class and workload
   configurations. Smaller block sizes can improve IOPS, while larger block
   sizes may improve throughput for large sequential read/write operations.

4. **Use Fast Disks:**

   Ensure that you are using high-performance NVMe SSDs with low latency and
   high endurance, as these will provide the best performance for your Longhorn
   setup.

5. **Optimize Volume Scheduling:**

   Set volume scheduling policies to distribute volumes evenly across all nodes,
   preventing any single node from becoming a bottleneck. This can be configured
   in the Longhorn UI or by setting volume distribution policies in your storage
   class.

## Step 3: Retest and Validate

After applying optimizations, repeat the `fio` benchmark tests to validate the
improvements. Compare the new results with the initial benchmarks to measure the
impact of your changes.

- Continue to monitor storage performance regularly using Longhorn’s built-in
  monitoring tools or external monitoring solutions like Prometheus and Grafana.

## Lesson Conclusion

Congratulations! With performance testing and optimizations complete, your
Longhorn storage setup should now provide efficient and reliable storage for
your Kubernetes cluster. In the next section, we will focus on securing your
cluster by implementing role-based access control (RBAC) and other security
measures.

You have completed this lesson and you can now continue with
[the next section](/building-a-production-ready-kubernetes-cluster-from-scratch/section-7).
