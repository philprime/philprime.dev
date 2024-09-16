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

## Preparing the NVMe SSDs and HATs

To begin, make sure you have the following:

- 512GB NVMe SSDs, one for each Raspberry Pi device.
- Compatible NVMe HATs for each Raspberry Pi to connect the SSDs.

### Installing the NVMe SSDs

1. **Insert the NVMe SSDs into the HATs**: Carefully insert each NVMe SSD into
   the corresponding HAT (Hardware Attached on Top) for your Raspberry Pi.
   Ensure that the SSD is securely connected and correctly oriented according to
   the HAT’s instructions.

2. **Attach the HATs to the Raspberry Pi Devices**: Mount the NVMe HAT with the
   attached SSD onto the Raspberry Pi, making sure all connectors align
   properly. Secure the HAT in place using any screws or clips provided.

3. **Connect Power and Network**: Ensure that each Raspberry Pi device is
   connected to a power source and the network switch via Ethernet. This will
   allow us to access the devices remotely for the next steps.

## Configuring the NVMe SSDs for Use

Once the SSDs are physically installed, the next step is to configure them for
use with the Raspberry Pi:

1. **SSH into Each Raspberry Pi**: Open an SSH connection to each Raspberry Pi
   device using the assigned static IP addresses.

2. **Verify SSD Recognition**: Use the `lsblk` or `fdisk -l` command to check if
   the NVMe SSD is recognized by the system:
   ```bash
   lsblk
   ```

You should see the NVMe SSD listed as `/dev/nvme0n1` or similar. If not,
double-check the physical connections and reboot the device.

3. **Partition the SSD**: If the SSD is recognized, use `fdisk` to create a new
   partition on it:

   ```bash
   sudo fdisk /dev/nvme0n1
   ```

   Follow the interactive prompts to create a new primary partition. When
   prompted, use the default settings to utilize the entire disk.

4. **Format the SSD**: Format the new partition with the `ext4` file system:

   ```bash
   sudo mkfs.ext4 /dev/nvme0n1p1
   ```

   This process may take a few moments depending on the size of the SSD.

5. **Create a Mount Point and Mount the SSD**: Create a directory to mount the
   SSD:

   ```bash
   sudo mkdir -p /mnt/nvme
   ```

   Mount the SSD to the new directory:

   ```bash
   sudo mount /dev/nvme0n1p1 /mnt/nvme
   ```

6. **Configure Automatic Mounting on Boot**: To ensure the SSD mounts
   automatically after a reboot, add an entry to the `/etc/fstab` file:
   ```bash
   echo '/dev/nvme0n1p1 /mnt/nvme ext4 defaults 0 0' | sudo tee -a /etc/fstab
   ```
   Verify the entry by running:
   ```bash
   sudo mount -a
   ```

## Verifying the SSD Setup

To confirm that the SSD setup is complete:

- Run the `df -h` command to check that the SSD is mounted correctly and the
  available storage matches the size of your SSD.
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

```

```
