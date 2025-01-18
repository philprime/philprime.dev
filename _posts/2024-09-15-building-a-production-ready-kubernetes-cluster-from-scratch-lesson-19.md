---
layout: course-lesson
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

## Benchmarking Longhorn Performance with fio

Before optimizing, it is important to understand the current performance of your
Longhorn setup. You can use benchmarking tools like **fio** (Flexible I/O
Tester) to simulate different workloads and measure read/write speeds, latency,
and IOPS (Input/Output Operations Per Second).

Deploy a simple test pod with the `fio` benchmarking tool. Create a YAML file
named `fio-test-pod.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: fio-test
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 20Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: fio-test
spec:
  containers:
    - name: fio
      image: alpine
      volumeMounts:
        - name: test-volume
          mountPath: /mnt/test
      command: ['sleep', '3600']
  volumes:
    - name: test-volume
      persistentVolumeClaim:
        claimName: fio-test
```

Apply the YAML file to create the test pod:

```bash
$ kubectl apply -f fio-test-pod.yaml
persistentvolumeclaim/fio-test created
pod/fio-test created
```

Once the pod is running, create an interactive shell session in the pod to
install `fio` and run the benchmark tests:

```bash
$ kubectl exec -it fio-test -- /bin/sh

/ $ apk add fio
fetch https://dl-cdn.alpinelinux.org/alpine/v3.21/main/aarch64/APKINDEX.tar.gz
fetch https://dl-cdn.alpinelinux.org/alpine/v3.21/community/aarch64/APKINDEX.tar.gz
(1/3) Installing libaio (0.3.113-r2)
(2/3) Installing numactl (2.0.18-r0)
(3/3) Installing fio (3.38-r0)
Executing busybox-1.37.0-r9.trigger
OK: 9 MiB in 18 packages

/ $ fio --name=readwrite --rw=randrw --bs=4k --size=1G --numjobs=4 --runtime=60 --group_reporting --directory=/mnt/test
```

This command runs a random read/write test with a 4KB block size, simulating a
mix of read and write operations over 1GB of data for 60 seconds.

After the test completes, review the output to see the read/write speeds, IOPS,
and latency. You can experiment with different test configurations to simulate
various workloads and measure the impact on storage performance.

Let's take a closer look at the output of the `fio` command:

```
readwrite: (g=0): rw=randrw, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=psync, iodepth=1
...
fio-3.38
Starting 4 processes
readwrite: Laying out IO file (1 file / 1024MiB)
readwrite: Laying out IO file (1 file / 1024MiB)
readwrite: Laying out IO file (1 file / 1024MiB)
readwrite: Laying out IO file (1 file / 1024MiB)
Jobs: 4 (f=4): [m(4)][100.0%][r=2170KiB/s,w=2058KiB/s][r=542,w=514 IOPS][eta 00m:00s]
readwrite: (groupid=0, jobs=4): err= 0: pid=22: Fri Jan 17 22:13:28 2025
  read: IOPS=2706, BW=10.6MiB/s (11.1MB/s)(634MiB/60012msec)
    clat (nsec): min=1019, max=720913k, avg=1413672.51, stdev=5020973.65
     lat (nsec): min=1093, max=720913k, avg=1414785.09, stdev=5021442.18
    clat percentiles (usec):
     |  1.00th=[    3],  5.00th=[    4], 10.00th=[    4], 20.00th=[    6],
     | 30.00th=[  676], 40.00th=[  832], 50.00th=[  914], 60.00th=[ 1004],
     | 70.00th=[ 1106], 80.00th=[ 1270], 90.00th=[ 1958], 95.00th=[ 5932],
     | 99.00th=[13042], 99.50th=[17433], 99.90th=[31851], 99.95th=[41681],
     | 99.99th=[74974]
   bw (  KiB/s): min=  684, max=20824, per=100.00%, avg=10990.21, stdev=1742.71, samples=472
   iops        : min=  168, max= 5206, avg=2746.96, stdev=435.79, samples=472
  write: IOPS=2706, BW=10.6MiB/s (11.1MB/s)(635MiB/60012msec); 0 zone resets
    clat (nsec): min=1871, max=203685k, avg=39727.56, stdev=946457.86
     lat (nsec): min=1963, max=203686k, avg=40775.38, stdev=947053.30
    clat percentiles (usec):
     |  1.00th=[    4],  5.00th=[    4], 10.00th=[    4], 20.00th=[    5],
     | 30.00th=[    6], 40.00th=[    7], 50.00th=[   10], 60.00th=[   13],
     | 70.00th=[   17], 80.00th=[   22], 90.00th=[   39], 95.00th=[  108],
     | 99.00th=[  494], 99.50th=[  881], 99.90th=[ 2671], 99.95th=[ 3752],
     | 99.99th=[ 7111]
   bw (  KiB/s): min=  620, max=22312, per=100.00%, avg=10994.48, stdev=1752.71, samples=472
   iops        : min=  152, max= 5578, avg=2747.96, stdev=438.30, samples=472
  lat (usec)   : 2=0.02%, 4=13.72%, 10=22.96%, 20=13.83%, 50=6.99%
  lat (usec)   : 100=1.66%, 250=1.69%, 500=1.00%, 750=4.59%, 1000=13.26%
  lat (msec)   : 2=15.29%, 4=1.74%, 10=2.22%, 20=0.83%, 50=0.17%
  lat (msec)   : 100=0.01%, 250=0.01%, 500=0.01%, 750=0.01%
  cpu          : usr=0.77%, sys=3.01%, ctx=322540, majf=0, minf=32
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=162418,162446,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
   READ: bw=10.6MiB/s (11.1MB/s), 10.6MiB/s-10.6MiB/s (11.1MB/s-11.1MB/s), io=634MiB (665MB), run=60012-60012msec
  WRITE: bw=10.6MiB/s (11.1MB/s), 10.6MiB/s-10.6MiB/s (11.1MB/s-11.1MB/s), io=635MiB (665MB), run=60012-60012msec

Disk stats (read/write):
  sda: ios=170308/151619, sectors=3677488/1649968, merge=4687/40, ticks=235184/5547016, in_queue=5782199, util=99.97%
```

The output provides detailed information about read and write performance, but
here are some key metrics to focus on:

- The read speed (BW) averaged `10.6MiB/s` with `2706 IOPS` and an average
  latency of 1.41ms at 90% of the time.
- The write speed (BW) averaged `10.6MiB/s` with `2706 IOPS` and an average
  latency of 39.7ms at 90% of the time.

## Benchmarking Longhorn Performance with sysbench

Another benchmarking tool you can use to test Longhorn storage performance is
**sysbench**. Sysbench is a versatile benchmarking tool that can simulate
different workloads, including CPU, memory, file I/O, and database operations.

To run a file I/O benchmark with sysbench, create a test pod with the following
YAML file named `sysbench-test-pod.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sysbench-test
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 20Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: sysbench-test
spec:
  containers:
    - name: sysbench
      image: alpine
      volumeMounts:
        - name: test-volume
          mountPath: /mnt/test
      command: ['sleep', '3600']
  volumes:
    - name: test-volume
      persistentVolumeClaim:
        claimName: sysbench-test
```

Apply the YAML file to create the test pod:

```bash
$ kubectl apply -f sysbench-test-pod.yaml
persistentvolumeclaim/sysbench-test created
pod/sysbench-test created
```

Once the pod is running, create an interactive shell session in the pod to
install `sysbench` and run the benchmark tests:

```sh
$ kubectl exec -it sysbench-test -- /bin/sh
/ $ apk add sysbench
/ $ sysbench fileio --file-total-size=1G --file-test-mode=rndrw --time=60 --max-requests=0 --file-num=64 prepare
/ $ sysbench fileio --file-total-size=1G --file-test-mode=rndrw --time=60 --max-requests=0 --file-num=64 run
```

## Optimizing Longhorn Storage Performance

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

4. **Optimize Volume Scheduling:**

   Set volume scheduling policies to distribute volumes evenly across all nodes,
   preventing any single node from becoming a bottleneck. This can be configured
   in the Longhorn UI or by setting volume distribution policies in your storage
   class.

5. **Dedicated Longhorn Nodes:**

   Consider dedicating specific nodes in your Kubernetes cluster for Longhorn
   storage to isolate storage workloads from other applications. This can help
   improve performance by reducing resource contention and network overhead.

You can find more information on Longhorn storage optimizations in the
[best practices guide](https://longhorn.io/docs/1.7.2/best-practices/).

## Retest and Validate

After applying optimizations, repeat the `fio` benchmark tests to validate the
improvements. Compare the new results with the initial benchmarks to measure the
impact of your changes.

This is an iterative process, and you may need to experiment with different
configurations to find the optimal settings for your Longhorn storage setup.

The following is the output of the `fio` command after applying the data
locality `Best Effort` optimization:

```
readwrite: (g=0): rw=randrw, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=psync, iodepth=1
...
fio-3.38
Starting 4 processes
readwrite: Laying out IO file (1 file / 1024MiB)
readwrite: Laying out IO file (1 file / 1024MiB)
readwrite: Laying out IO file (1 file / 1024MiB)
readwrite: Laying out IO file (1 file / 1024MiB)
Jobs: 4 (f=4): [m(4)][100.0%][r=18.2MiB/s,w=18.0MiB/s][r=4670,w=4618 IOPS][eta 00m:00s]
readwrite: (groupid=0, jobs=4): err= 0: pid=22: Fri Jan 17 22:37:12 2025
  read: IOPS=3163, BW=12.4MiB/s (13.0MB/s)(742MiB/60002msec)
    clat (nsec): min=852, max=1081.1M, avg=1182097.50, stdev=4981045.35
     lat (nsec): min=908, max=1081.1M, avg=1182960.03, stdev=4981454.07
    clat percentiles (usec):
     |  1.00th=[    3],  5.00th=[    3], 10.00th=[    4], 20.00th=[    5],
     | 30.00th=[  553], 40.00th=[  750], 50.00th=[  840], 60.00th=[  914],
     | 70.00th=[  996], 80.00th=[ 1123], 90.00th=[ 1582], 95.00th=[ 4752],
     | 99.00th=[10683], 99.50th=[14091], 99.90th=[29754], 99.95th=[34866],
     | 99.99th=[51119]
   bw (  KiB/s): min=  245, max=25072, per=100.00%, avg=12852.14, stdev=1952.12, samples=467
   iops        : min=   59, max= 6268, avg=3212.60, stdev=488.11, samples=467
  write: IOPS=3163, BW=12.4MiB/s (13.0MB/s)(741MiB/60002msec); 0 zone resets
    clat (nsec): min=1389, max=1067.0M, avg=61127.87, stdev=4990871.63
     lat (nsec): min=1463, max=1067.1M, avg=61997.36, stdev=4991320.76
    clat percentiles (usec):
     |  1.00th=[    3],  5.00th=[    4], 10.00th=[    4], 20.00th=[    5],
     | 30.00th=[    5], 40.00th=[    7], 50.00th=[    9], 60.00th=[   12],
     | 70.00th=[   15], 80.00th=[   19], 90.00th=[   34], 95.00th=[   92],
     | 99.00th=[  412], 99.50th=[  783], 99.90th=[ 2376], 99.95th=[ 3589],
     | 99.99th=[ 8356]
   bw (  KiB/s): min=  390, max=25384, per=100.00%, avg=12873.59, stdev=1951.37, samples=466
   iops        : min=   96, max= 6346, avg=3217.98, stdev=487.93, samples=466
  lat (nsec)   : 1000=0.01%
  lat (usec)   : 2=0.05%, 4=17.93%, 10=21.97%, 20=13.93%, 50=5.54%
  lat (usec)   : 100=1.65%, 250=1.59%, 500=1.07%, 750=5.96%, 1000=15.29%
  lat (msec)   : 2=10.84%, 4=1.38%, 10=2.21%, 20=0.46%, 50=0.12%
  lat (msec)   : 100=0.01%, 250=0.01%, 750=0.01%, 1000=0.01%, 2000=0.01%
  cpu          : usr=0.85%, sys=3.09%, ctx=369061, majf=0, minf=35
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=189846,189790,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
   READ: bw=12.4MiB/s (13.0MB/s), 12.4MiB/s-12.4MiB/s (13.0MB/s-13.0MB/s), io=742MiB (778MB), run=60002-60002msec
  WRITE: bw=12.4MiB/s (13.0MB/s), 12.4MiB/s-12.4MiB/s (13.0MB/s-13.0MB/s), io=741MiB (777MB), run=60002-60002msec

Disk stats (read/write):
  sda: ios=196644/167454, sectors=4075168/1805632, merge=5321/31, ticks=239332/5257747, in_queue=5497079, util=100.00%
```

Changing the data locality setting to `Best Effort` in the default storage class
`longhorn` improved the read/write speed to `12.4MiB/s` with `3163 IOPS` and an
average latency of 1.18ms at 90% of the time.

## Benchmarking on the Host System

To compare the disk speed of the Longhorn storage setup with the host system
itself, we can run the same `fio` benchmark tests directly on the host system
for the microSD card and the mounted NVMe SSD.

To compare our performance results with the microSD card, we can run the same
`fio` benchmark tests on the microSD card directly on the host system.

First, install `fio` on the host system, create a working directory, and run the
benchmark tests:

```bash
$ sudo apt-get install fio

# Create a working directory on the microSD card
$ mkdir -p /media/pi/longhorn

# Run the fio benchmark tests on the microSD card
$ fio --name=readwrite --rw=randrw --bs=4k --size=1G --numjobs=4 --runtime=60 --group_reporting --directory=/media/pi/longhorn
```

```
readwrite: (g=0): rw=randrw, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=psync, iodepth=1
...
fio-3.33
Starting 4 processes
readwrite: Laying out IO file (1 file / 1024MiB)
readwrite: Laying out IO file (1 file / 1024MiB)
readwrite: Laying out IO file (1 file / 1024MiB)
readwrite: Laying out IO file (1 file / 1024MiB)
Jobs: 4 (f=4): [m(4)][100.0%][r=644KiB/s,w=672KiB/s][r=161,w=168 IOPS][eta 00m:00s]
readwrite: (groupid=0, jobs=4): err= 0: pid=416783: Fri Jan 17 23:49:36 2025
  read: IOPS=523, BW=2094KiB/s (2144kB/s)(123MiB/60005msec)
    clat (nsec): min=1407, max=393891k, avg=6401746.71, stdev=15268720.32
     lat (nsec): min=1481, max=393892k, avg=6401924.21, stdev=15268729.89
    clat percentiles (usec):
     |  1.00th=[     3],  5.00th=[     5], 10.00th=[  1663], 20.00th=[  2147],
     | 30.00th=[  2147], 40.00th=[  2180], 50.00th=[  2180], 60.00th=[  2245],
     | 70.00th=[  2671], 80.00th=[  3982], 90.00th=[ 19006], 95.00th=[ 20317],
     | 99.00th=[ 79168], 99.50th=[126354], 99.90th=[143655], 99.95th=[210764],
     | 99.99th=[392168]
   bw (  KiB/s): min=   48, max= 7936, per=100.00%, avg=2280.44, stdev=638.48, samples=440
   iops        : min=   12, max= 1984, avg=570.11, stdev=159.62, samples=440
  write: IOPS=528, BW=2115KiB/s (2166kB/s)(124MiB/60005msec); 0 zone resets
    clat (nsec): min=1500, max=2230.6M, avg=1223322.23, stdev=39174125.43
     lat (nsec): min=1593, max=2230.6M, avg=1223630.37, stdev=39174134.66
    clat percentiles (usec):
     |  1.00th=[      3],  5.00th=[      4], 10.00th=[      4],
     | 20.00th=[      4], 30.00th=[      5], 40.00th=[      5],
     | 50.00th=[      7], 60.00th=[      9], 70.00th=[     12],
     | 80.00th=[     15], 90.00th=[     24], 95.00th=[     42],
     | 99.00th=[   4424], 99.50th=[   9110], 99.90th=[ 108528],
     | 99.95th=[ 868221], 99.99th=[2164261]
   bw (  KiB/s): min=   48, max= 8360, per=100.00%, avg=2335.40, stdev=652.33, samples=434
   iops        : min=   12, max= 2090, avg=583.85, stdev=163.08, samples=434
  lat (usec)   : 2=0.05%, 4=14.52%, 10=21.09%, 20=11.10%, 50=3.90%
  lat (usec)   : 100=0.28%, 250=0.14%, 500=0.01%, 750=0.06%, 1000=0.02%
  lat (msec)   : 2=3.45%, 4=34.90%, 10=2.63%, 20=4.69%, 50=2.31%
  lat (msec)   : 100=0.47%, 250=0.31%, 500=0.03%, 750=0.01%, 1000=0.01%
  lat (msec)   : 2000=0.01%, >=2000=0.01%
  cpu          : usr=0.10%, sys=0.36%, ctx=39690, majf=0, minf=41
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=31406,31726,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
   READ: bw=2094KiB/s (2144kB/s), 2094KiB/s-2094KiB/s (2144kB/s-2144kB/s), io=123MiB (129MB), run=60005-60005msec
  WRITE: bw=2115KiB/s (2166kB/s), 2115KiB/s-2115KiB/s (2166kB/s-2166kB/s), io=124MiB (130MB), run=60005-60005msec

Disk stats (read/write):
  mmcblk0: ios=30525/25845, merge=2268/1933, ticks=190961/5015289, in_queue=5206251, util=96.00%
```

In our case the result shows a read/write speed of `2.09MiB/s` with `523 IOPS`,
which is much slower than the Longhorn storage setup.

Next, we can run the same `fio` benchmark tests on the mounted NVMe SSD directly
on the host system.

First, create a working directory on the NVMe SSD, and run the benchmark tests:

```bash
# Create a working directory on the NVMe SSD
$ mkdir -p /mnt/nvme/workdir

# Run the fio benchmark tests on the NVMe SSD
$ fio --name=readwrite --rw=randrw --bs=4k --size=1G --numjobs=4 --runtime=60 --group_reporting --directory=/mnt/nvme/workdir
```

```
readwrite: (g=0): rw=randrw, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=psync, iodepth=1
...
fio-3.33
Starting 4 processes
readwrite: Laying out IO file (1 file / 1024MiB)
readwrite: Laying out IO file (1 file / 1024MiB)
readwrite: Laying out IO file (1 file / 1024MiB)
readwrite: Laying out IO file (1 file / 1024MiB)
Jobs: 3 (f=3): [m(1),_(1),m(2)][100.0%][r=157MiB/s,w=160MiB/s][r=40.3k,w=40.9k IOPS][eta 00m:00s]
readwrite: (groupid=0, jobs=4): err= 0: pid=419796: Fri Jan 17 23:51:00 2025
  read: IOPS=32.5k, BW=127MiB/s (133MB/s)(2046MiB/16101msec)
    clat (nsec): min=666, max=11090k, avg=115524.93, stdev=336012.19
     lat (nsec): min=703, max=11090k, avg=115614.75, stdev=336019.77
    clat percentiles (nsec):
     |  1.00th=[   1704],  5.00th=[   1960], 10.00th=[   2096],
     | 20.00th=[   2384], 30.00th=[   2672], 40.00th=[   3888],
     | 50.00th=[ 104960], 60.00th=[ 120320], 70.00th=[ 132096],
     | 80.00th=[ 140288], 90.00th=[ 156672], 95.00th=[ 177152],
     | 99.00th=[2637824], 99.50th=[2899968], 99.90th=[3260416],
     | 99.95th=[3489792], 99.99th=[6520832]
   bw (  KiB/s): min=24912, max=206296, per=100.00%, avg=130215.60, stdev=10117.74, samples=127
   iops        : min= 6228, max=51574, avg=32553.90, stdev=2529.43, samples=127
  write: IOPS=32.6k, BW=127MiB/s (134MB/s)(2050MiB/16101msec); 0 zone resets
    clat (nsec): min=963, max=8553.2k, avg=4585.35, stdev=18416.66
     lat (nsec): min=1037, max=8553.3k, avg=4709.78, stdev=18437.61
    clat percentiles (usec):
     |  1.00th=[    3],  5.00th=[    3], 10.00th=[    3], 20.00th=[    3],
     | 30.00th=[    4], 40.00th=[    4], 50.00th=[    4], 60.00th=[    5],
     | 70.00th=[    5], 80.00th=[    6], 90.00th=[    7], 95.00th=[    8],
     | 99.00th=[   15], 99.50th=[   26], 99.90th=[   66], 99.95th=[   88],
     | 99.99th=[  219]
   bw (  KiB/s): min=24424, max=207904, per=100.00%, avg=130503.77, stdev=10224.22, samples=127
   iops        : min= 6106, max=51976, avg=32625.94, stdev=2556.06, samples=127
  lat (nsec)   : 750=0.01%, 1000=0.02%
  lat (usec)   : 2=3.14%, 4=45.24%, 10=21.46%, 20=0.93%, 50=0.25%
  lat (usec)   : 100=2.57%, 250=25.29%, 500=0.38%, 750=0.03%, 1000=0.01%
  lat (msec)   : 2=0.04%, 4=0.62%, 10=0.02%, 20=0.01%
  cpu          : usr=2.16%, sys=9.10%, ctx=305925, majf=0, minf=33
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=523742,524834,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
   READ: bw=127MiB/s (133MB/s), 127MiB/s-127MiB/s (133MB/s-133MB/s), io=2046MiB (2145MB), run=16101-16101msec
  WRITE: bw=127MiB/s (134MB/s), 127MiB/s-127MiB/s (134MB/s-134MB/s), io=2050MiB (2150MB), run=16101-16101msec

Disk stats (read/write):
  nvme0n1: ios=482124/422393, merge=0/19, ticks=87283/1248417, in_queue=1335705, util=81.11%
```

The result shows a read/write speed of `127MiB/s` with `32.5k IOPS`, which is
much faster than the Longhorn storage setup.

## Benchmarking Summary

After running the `fio` benchmark tests on the Longhorn storage setup, microSD
card, and NVMe SSD, we can compare the results to evaluate the performance of
the Longhorn storage setup.

It clearly shows that using the Longhorn storage setup is slower than the NVMe
SSD but faster than the microSD card. This is a performance trade-off between
reliability and speed. Longhorn provides a reliable storage solution for
Kubernetes clusters, but it may not be as fast as local storage solutions.

Keep in mind that Longhorn is designed to provide persistend storage across
multiple nodes in a Kubernetes cluster, and it offers features like snapshots,
backups, and data locality that are required to reschedule workloads on
different nodes.

## Lesson Conclusion

Congratulations! With performance testing and optimizations complete, your
Longhorn storage setup should now provide efficient and reliable storage for
your Kubernetes cluster. In the next section, we will focus on securing your
cluster by implementing role-based access control (RBAC) and other security
measures.

You have completed this lesson and you can now continue with
[the next section](/building-a-production-ready-kubernetes-cluster-from-scratch/section-7).
