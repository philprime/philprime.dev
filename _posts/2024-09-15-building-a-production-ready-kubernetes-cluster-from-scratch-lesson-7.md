---
layout: course-lesson
title: Networking Setup and Configuration (L7)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-7
---

In this lesson, we will set up the network configuration for your Raspberry Pi
Kubernetes cluster. Proper network setup is essential to ensure that all devices
can communicate effectively and reliably, allowing your Kubernetes cluster to
function as intended.

This is the seventh lesson in the series on building a production-ready
Kubernetes cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-6)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## Configuring the Network for Your Cluster

To ensure your Raspberry Pi devices are properly connected, follow these steps:

- Verify that all Raspberry Pi devices are connected to your gigabit Ethernet
  switch using CAT5e or higher Ethernet cables. The switch should be connected
  to your router to provide internet access to each Raspberry Pi.

- Double-check that each Raspberry Pi device has a unique static IP address
  within your local network range (e.g., `10.1.1.1`, `10.1.1.2`, etc.), as
  configured in Lesson 5. Ensure these IP addresses are also reserved in your
  router's DHCP settings to prevent IP conflicts.

- SSH into each Raspberry Pi and use the `ping` command to test communication
  with the other Raspberry Pi devices. For example:
  ```bash
  $ ping 10.1.1.1
  $ ssh pi@10.1.1.1
  ```

## Configuring Additional Network Security

To enhance the security of your Raspberry Pi devices, we will configure a
firewall to control incoming and outgoing traffic. This will help protect your
devices from unauthorized access and potential attacks.

As we desire to be as close to a production-ready environment as possible, we
will use the `ufw` (Uncomplicated Firewall) tool to manage the firewall rules on
each Raspberry Pi.

We will start with the most restrictive rules and then allow specific services
as needed. This will help prevent unauthorized access to your devices while
still allowing essential services like SSH.

Install and enable `ufw` (Uncomplicated Firewall) to control incoming and
outgoing traffic on each Raspberry Pi. It should be pre-installed on the
Raspberry Pi OS, but you can install it using the following command:

```bash
$ sudo apt install ufw
```

Next, configure the firewall rules to deny any incoming and outgoing traffic by
default but make exceptions for SSH access:

```bash
# Deny all incoming and outgoing traffic by default
$ sudo ufw default deny incoming
$ sudo ufw default deny outgoing

# Allow SSH access
$ sudo ufw allow ssh
```

Finally, enable the firewall to apply the rules:

```bash
# Enable the firewall
$ sudo ufw enable

# Verify the firewall status
$ sudo ufw status verbose
Status: active
Logging: on (low)
Default: deny (incoming), deny (outgoing), deny (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
```

> [!WARNING] When enabling `ufw`, you may be prompted to allow or deny certain
> services. Ensure that you allow SSH access to prevent being locked out of your
> devices.

Next we will need to configure the firewall to allow traffic to system services
such as DNS and NTP. This will allow your Raspberry Pi devices to resolve domain
names and synchronize time with external servers:

```bash
# Allow  outcoming traffic for the DNS service (port 53)
$ sudo ufw allow out domain

# Allow outcoming traffic for the NTP service (port 123)
$ sudo ufw allow out ntp

# Allow outgoing HTTP and HTTPS traffic required to fetch external resources
$ sudo ufw allow out http
$ sudo ufw allow out https
```

To support outgoing ICMP traffic, which is used for `ping` and other network
diagnostics, you can need to edit the `/etc/ufw/before.rules` file and add the
following section below the `# ok icmp codes for INPUT` section:

```bash
# ok icmp codes for OUTPUT
-A ufw-before-output -p icmp --icmp-type echo-request -j ACCEPT
```

Save the file and reload the firewall to apply the changes:

```bash
# Reload the firewall
$ sudo ufw reload

# Verify the firewall status
$ sudo ufw status verbose
Status: active
Logging: on (low)
Default: deny (incoming), deny (outgoing), deny (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)

53                         ALLOW OUT   Anywhere
80                         ALLOW OUT   Anywhere
123/udp                    ALLOW OUT   Anywhere
443                        ALLOW OUT   Anywhere
53 (v6)                    ALLOW OUT   Anywhere (v6)
80 (v6)                    ALLOW OUT   Anywhere (v6)
123/udp (v6)               ALLOW OUT   Anywhere (v6)
443 (v6)                   ALLOW OUT   Anywhere (v6)
```

To verify the outgoing ICMP traffic and DNS resolution, you can test the `ping`
command to an external IP address. For example:

```bash
$ ping -c 1 philprime.dev
PING philprime.dev (104.21.66.10) 56(84) bytes of data.
64 bytes from 104.21.66.10 (104.21.66.10): icmp_seq=1 ttl=57 time=3.87 ms
```

To test the NTP service, you can check the time synchronization with an external
NTP server using `chrony`:

```bash
# Trigger a time synchronization
$ sudo chronyc -a makestep
200 OK

# Check the synchronization status
$ chronyc sources
MS Name/IP address         Stratum Poll Reach LastRx Last sample
===============================================================================
^- 185.119.117.217               2   6     0  1095    -99us[  -99us] +/- 9024us
^- 91.206.8.70                   2   6     0  1095   +593us[ +708us] +/-   29ms
^- 185.144.161.170               2   6     0  1095  -1116ns[ +113us] +/- 5438us
^- 91.206.8.34                   2   6     1     0   +752us[ +752us] +/-   26ms
```

Looking at the output of `chronyc sources`, you should see a list of NTP servers
with their synchronization status. The `*` symbol indicates the selected source
for synchronization, while the `^` symbol indicates candidate sources.

If you see a `?` or `x` symbol, it means the source is unreachable.

> [!NOTE] The list of NTP servers may vary depending on your location and
> network configuration. Ensure that the selected sources are reachable and
> provide accurate time synchronization.

## Lesson Conclusion

Congratulations! With your network configuration complete, your Raspberry Pi
devices are now ready to communicate effectively within your Kubernetes cluster.
Next, we will prepare the environment for Kubernetes by installing essential
tools and setting up the container runtime.

You have completed this lesson and you can now continue with
[the next section](/building-a-production-ready-kubernetes-cluster-from-scratch/section-3).
