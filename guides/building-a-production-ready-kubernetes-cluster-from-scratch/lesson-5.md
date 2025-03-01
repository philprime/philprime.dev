---
layout: guide-lesson.liquid
title: Flashing Raspberry Pi OS and Initial Configuration

guide_component: lesson
guide_id: building-a-production-ready-kubernetes-cluster-from-scratch
guide_section_id: 2
guide_lesson_id: 5
guide_lesson_abstract: >
  Follow a step-by-step guide to install Raspberry Pi OS on your devices, configure essential settings, and prepare them
  for networking.
guide_lesson_conclusion: >
  With the operating system flashed and the initial configuration complete, you are now ready to set up the NVMe SSDs
  for persistent storage.
repo_file_path: guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-5.md
---

In this lesson, you will follow a step-by-step guide to install Raspberry Pi OS on your devices, configure essential
settings, and prepare them for networking.

{% include guide-overview-link.liquid.html %}

Now that your Raspberry Pi devices are unboxed, assembled, and connected, it's time to install the operating system. In
this lesson, we’ll walk through the process of flashing Raspberry Pi OS onto your microSD cards and performing the
initial configuration needed to prepare your devices for the Kubernetes cluster.

## Preparing the MicroSD Cards

{% include alert.liquid.html type='tip' title='TIP:' content='
You will need to repeat the following steps for each microSD card, replacing <code>X</code> with the corresponding
number for each Raspberry Pi device (e.g., <code>1</code>, <code>2</code>, <code>3</code>, etc.).
' %}

To begin, you need to prepare the microSD cards that will host the Raspberry Pi OS using the
[Raspberry Pi Imager](https://www.raspberrypi.com/software/). In addition to the OS we will also set up the SSH access
for headless setup and a hostname for each Raspberry Pi.

- Insert each microSD card into your computer using a card reader.
- Download and install the [Raspberry Pi Imager](https://www.raspberrypi.com/software/) for your operating system (if
  you haven’t already).
- Open the Raspberry Pi Imager and select the **Raspberry Pi OS (other)** option.
- Choose the **Raspberry Pi OS Lite (64-bit)** version (or 32-bit for older models) for a minimal installation.
  ![OS Selection](/assets/guides/building-a-production-ready-kubernetes-cluster-from-scratch/raspberry-pi-imager-1.webp)
- Select the microSD card you want to flash the OS to (ensure you have the correct card selected), and click on
  **Next**.
  ![Selected settings](/assets/guides/building-a-production-ready-kubernetes-cluster-from-scratch/raspberry-pi-imager-2.webp)
- When prompted to **use OS customization**, click on **Edit Settings**.
  ![Customization Prompt](/assets/guides/building-a-production-ready-kubernetes-cluster-from-scratch/raspberry-pi-imager-3.webp)
- In the OS customisation settings window, configure the following settings in **General**:
  - **Hostname**: Set a unique hostname for each Raspberry Pi device `kubernetes-node-X` (replacing `X` with the number
    of the current node).
  - **Username**: Set the username to `pi` and configure a unique password. Ideally you configure a different password
    for each node, but for simplicity you can use the same password for all node for now.
  - **Timezone**: Set the timezone to your local timezone.
    ![General Settings](/assets/guides/building-a-production-ready-kubernetes-cluster-from-scratch/raspberry-pi-imager-4.webp)
- In the OS customisation settings window, switch to the tab **Services** and enable **SSH** to allow remote access to
  the Raspberry Pi devices.
  - Generate a new SSH key pair using `ssh-keygen` or use an existing one to secure the SSH connection. If you are
    creating a new key pair and write it to `~/.ssh/k8s_cluster_id_ed25519`.
    ![SSH Settings](/assets/guides/building-a-production-ready-kubernetes-cluster-from-scratch/raspberry-pi-imager-5.webp)
  - Open the public key `~/.ssh/k8s_cluster_id_ed25519.pub` and copy its content into the textfield. Click on **Save**
    to confirm the changes.
    ![SSH Settings](/assets/guides/building-a-production-ready-kubernetes-cluster-from-scratch/raspberry-pi-imager-6.webp)
- Back on the main screen, when prompted with "Would you like to apply OS customizations settings?", click on **Yes**.
- A warning will be shown, explaining that all data on the microSD card will be erased. Click on **Yes** to confirm and
  start the flashing process.
- Once the flashing process is complete, the microSD card will be ejected automatically. Remove the card from your
  computer and insert it again to edit the boot configuration for additional settings.

{% include alert.liquid.html type='tip' title='TIP:' content='
Add a label to your Raspberry Pi to identify the device by its hostname.
This will help you distinguish between the devices when connecting to them remotely.
'
img_src="/assets/guides/building-a-production-ready-kubernetes-cluster-from-scratch/raspberry-pi-with-labels.webp"
img_alt="Raspberry Pi with labels" %}

## Pre-Configure Static IP Addresses

Instead of using DHCP to assign IP addresses to the Raspberry Pi devices, you can configure static IP addresses to
ensure that each device has a consistent address on the network. This is particularly useful when setting up a
Kubernetes cluster, as it allows you to easily identify and connect to each node.

As we have disabled the DHCP service on the router, we need to configure the static IP addresses on the Raspberry Pi
devices directly. So that it is already configured on the first boot.

After you mounted the microSD card again, the boot partition should be mounted as `bootfs`. The Raspberry Pi Imager
should have created a file `firstrun.sh`, which is used to configure the Raspberry Pi on first boot.

Open `firstrun.sh` in your text editor of choice. Then right before the deletion of the script
`rm -f /boot/firstrun.sh`, add the following lines to configure a static IP address. Make sure to replace `X` with the
corresponding number for each Raspberry Pi device:

```bash
# START - Configure a static IP address for eth0
echo "Enabling and starting NetworkManager..."
systemctl enable NetworkManager
systemctl start NetworkManager

# IMPORTANT: Replace `X` with the number of the node
NODE_IP_ADDRESS="10.1.1.X/16"
echo "Configuring static IP $NODE_IP_ADDRESS for eth0..."
/usr/bin/nmcli connection modify "Wired connection 1" ipv4.method manual ipv4.addresses $NODE_IP_ADDRESS ipv4.gateway "10.1.0.1" ipv4.dns "10.1.0.1" autoconnect yes

echo "Bringing up the connection..."
nmcli connection up "Wired connection 1"

echo "Static IP configuration applied."
# END - Configure a static IP address for eth0
```

Save the changes and safely eject the microSD card from your computer.

## Verifying Connectivity

Insert the microSD card into the Raspberry Pi device and power it on. To verify that each Raspberry Pi is correctly
configured and accessible, ping each Raspberry Pi from your main computer or from one Raspberry Pi to another to ensure
network connectivity.

{% include alert.liquid.html type='warning' title='Warning:' content='
Remember to replace <code>X</code> with the corresponding number for each Raspberry Pi device.
' %}

```bash
$ ping 10.1.1.X
```

Connect to the Raspberry Pi devices using SSH to confirm that you can access them remotely:

```bash
$ ssh -i ~/.ssh/k8s_cluster_id_ed25519 pi@10.1.1.X
```

If all devices respond successfully, your network configuration is correct, and your Raspberry Pi devices are ready for
the next steps.

{% include alert.liquid.html type='tip' title='TIP:' content='You can also connect the Raspberry Pi devices to a monitor
and keyboard to verify that the devices boot correctly and that the network configuration is applied. You can see the IP
address assigned to the device at the login:

<pre>
Debian GNU/Linux 11 kubernetes-node-X tty1

My IP address is 10.1.1.X

kubernetes-node-X login:
</pre>

' %}
