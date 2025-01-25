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

<div class="alert-warning" role="alert">
<strong>WARNING:</strong> All commands used in this lesson require <code>sudo</code> privileges.
Either prepend <code>sudo</code> to each command or switch to the root user using <code>sudo -i</code>.
</div>

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
  $ ssh -i ~/.ssh/k8s_cluster_id_ed25519 pi@10.1.1.1
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
$ apt install ufw
```

Next, configure the firewall rules to deny any incoming and outgoing traffic by
default but make exceptions for SSH access:

```bash
# Deny all incoming and outgoing traffic by default
$ ufw default deny incoming
$ ufw default deny outgoing

# Allow SSH access
$ ufw allow ssh
```

Finally, enable the firewall to apply the rules:

```bash
# Enable the firewall
$ ufw enable
Command may disrupt existing ssh connections. Proceed with operation (y|n)? y

# Verify the firewall status
$ ufw status verbose
Status: active
Logging: on (low)
Default: deny (incoming), deny (outgoing), deny (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
```

<div class="alert-warning" role="alert">
<strong>WARNING:</strong> When enabling <code>ufw</code>, you may be prompted to allow or deny certain services.
Ensure that you allow SSH access to prevent being locked out of your devices.
</div>

Next we will need to configure the firewall to allow traffic to system services
such as DNS and NTP. This will allow your Raspberry Pi devices to resolve domain
names and synchronize time with external servers:

```bash
# Allow  outcoming traffic for the DNS service (port 53)
$ ufw allow out domain
Rule added
Rule added (v6)

# Allow outcoming traffic for the NTP service (port 123)
$ ufw allow out ntp
Rule added
Rule added (v6)

# Allow outgoing HTTP and HTTPS traffic required to fetch external resources
$ ufw allow out http
Rule added
Rule added (v6)

$ ufw allow out https
Rule added
Rule added (v6)
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
$ ufw reload

# Verify the firewall status
$ ufw status verbose
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

Testing the NTP service will require additional setup, which is covered in the
[Lesson 10](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-10).

## Lesson Conclusion

Congratulations! With your network configuration complete, your Raspberry Pi
devices are now ready to communicate effectively within your Kubernetes cluster.
Next, we will prepare the environment for Kubernetes by installing essential
tools and setting up the container runtime.

You have completed this lesson and you can now continue with
[the next section](/building-a-production-ready-kubernetes-cluster-from-scratch/section-3).
