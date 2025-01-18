---
layout: course-lesson
title: Setting Up NVMe SSDs for Persistent Storage] (L6)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-6
---

In this lesson, we’ll set up the NVMe SSDs for each Raspberry Pi device to
provide persistent storage for your Kubernetes cluster. This storage will be
used for container images, data volumes, and other persistent needs within the
cluster, ensuring data durability and reliability.

This is the sixth lesson in the series on building a production-ready Kubernetes
cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-5)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## Configuring the NVMe SSDs for Use

Once the SSDs are physically installed, the next step is to configure them for
use with the Raspberry Pi after connecting to them via SSH:

1. Use SSH to connect to the Raspberry Pi device with the NVMe SSD installed.
   Replace `10.1.1.X` with the IP address of the Raspberry Pi device:

   ```bash
   ssh -i ~/.ssh/k8s_cluster_id_ed25519 pi@10.1.1.X
   ```

2. Use the `lsblk` or `fdisk -l` command to check if the NVMe SSD is recognized
   by the system:

   ```bash
   $ lsblk
   NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
   mmcblk0     179:0    0  58.2G  0 disk
   ├─mmcblk0p1 179:1    0   512M  0 part /boot/firmware
   └─mmcblk0p2 179:2    0  57.7G  0 part /
   nvme0n1     259:0    0 465.8G  0 disk

   $ fdisk -l
   Disk /dev/nvme0n1: 465.76 GiB, 500107862016 bytes, 976773168 sectors
   Disk model: KINGSTON SNV3S500G
   Units: sectors of 1 * 512 = 512 bytes
   Sector size (logical/physical): 512 bytes / 512 bytes
   I/O size (minimum/optimal): 512 bytes / 512 bytes
   ```

   You should see the NVMe SSD listed as `/dev/nvme0n1` or similar. If not,
   double-check the physical connections and reboot the device.

3. **Partition the SSD**: If the SSD is recognized, use `fdisk` to create a new
   partition on it:

   ```bash
   $ sudo fdisk /dev/nvme0n1
   ```

   Follow these steps in the interactive `fdisk` prompt:

   - Type `n` to create a new partition.
   - Select `p` for a primary partition.
   - Press `Enter` to accept the default partition number.
   - Press `Enter` to accept the default first sector.
   - Press `Enter` again to accept the default last sector, which will use the
     entire disk.
   - Type `w` to write the changes and exit `fdisk`.

   The output should look similar to this:

   ```bash
   $ sudo fdisk /dev/nvme0n1

   Welcome to fdisk (util-linux 2.38.1).
   Changes will remain in memory only, until you decide to write them.
   Be careful before using the write command.

   Device does not contain a recognized partition table.
   Created a new DOS (MBR) disklabel with disk identifier 0x681ca427.

   Command (m for help): n
   Partition type
     p   primary (0 primary, 0 extended, 4 free)
     e   extended (container for logical partitions)
   Select (default p): p
   Partition number (1-4, default 1):
   First sector (2048-976773167, default 2048):
   Last sector, +/-sectors or +/-size{K,M,G,T,P} (2048-976773167, default 976773167):

   Created a new partition 1 of type 'Linux' and of size 465.8 GiB.

   Command (m for help): w
   The partition table has been altered.
   Calling ioctl() to re-read partition table.
   Syncing disks.
   ```

   After completing these steps, the new partition will be created and ready for
   formatting. You can verify the partition by running `lsblk` or `fdisk -l`
   again:

   ```bash
   $ lsblk
   NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
   mmcblk0     179:0    0  58.2G  0 disk
   ├─mmcblk0p1 179:1    0   512M  0 part /boot/firmware
   └─mmcblk0p2 179:2    0  57.7G  0 part /
   nvme0n1     259:0    0 465.8G  0 disk
   └─nvme0n1p1 259:1    0 465.8G  0 part
   ```

   The new partition should be listed as `/dev/nvme0n1p1` or similar.

4. Next step is to **format the partition** with the `ext4` filesystem. There
   are other filesystems you can use, but `ext4` is a common choice for Linux
   systems:

   ```bash
   $ sudo mkfs.ext4 /dev/nvme0n1p1
   ```

   This process may take a few moments depending on the size of the SSD.

5. To **mount the SSD** to a directory, create a new directory as the mount
   location, then mount the SSD to that directory:

   ```bash
   $ sudo mkdir -p /mnt/nvme
   ```

6. We want the SSD to be mounted automatically on boot of the system. We can
   achieve this by adding an entry to the `/etc/fstab` file:

   ```bash
   $ echo '/dev/nvme0n1p1 /mnt/nvme ext4 defaults 0 0' | sudo tee -a /etc/fstab
   ```

   Verify the entry by running:

   ```bash
   $ sudo mount -a
   ```

## Verifying the SSD Setup

To confirm that the SSD setup is complete:

- Run the `df -h` command to check that the SSD is mounted correctly and the
  available storage matches the size of your SSD:

```bash
$ df -h
Filesystem      Size  Used Avail Use% Mounted on
udev            3.8G     0  3.8G   0% /dev
tmpfs           805M  5.5M  800M   1% /run
/dev/mmcblk0p2   57G  2.2G   52G   5% /
tmpfs           4.0G     0  4.0G   0% /dev/shm
tmpfs           5.0M   48K  5.0M   1% /run/lock
/dev/mmcblk0p1  510M   66M  445M  13% /boot/firmware
tmpfs           805M     0  805M   0% /run/user/1000
/dev/nvme0n1p1  458G   28K  435G   1% /mnt/nvme
```

- Reboot the Raspberry Pi devices with `sudo reboot` and verify that the SSDs
  are automatically mounted at startup.

If everything is set up correctly, your NVMe SSDs are now ready to provide
persistent storage for your Kubernetes cluster.

## Lesson Conclusion

Congratulations! With your NVMe SSDs installed and configured, you have
successfully prepared your persistent storage solution. Next, we will configure
the network settings to ensure all Raspberry Pi devices are properly connected
and can communicate within the cluster.

You have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-7).
