---
layout: post
title: Enabling Mutual TLS Authentication (L21)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-21
---

In this lesson, we will enable **Mutual TLS (mTLS) Authentication** in your
Kubernetes cluster to secure communication between its components. Mutual TLS
ensures that both the client and server authenticate each other, providing an
additional layer of security for internal communications within the cluster.

This is the twenty-first lesson in the series on building a production-ready
Kubernetes cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-20)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## What is Mutual TLS (mTLS) Authentication?

**Mutual TLS (mTLS) Authentication** is a security protocol where both parties
in a communication (client and server) authenticate each other using digital
certificates. In a Kubernetes cluster, mTLS is used to secure communication
between different components, such as the API server, `etcd`, and nodes. With
mTLS enabled, each component presents a valid certificate that is verified by
the other, ensuring that only trusted components can communicate. This prevents
man-in-the-middle attacks and unauthorized access, helping to protect sensitive
data and internal operations.

## Step 1: Understand Kubernetes Certificates

Kubernetes relies heavily on certificates for securing communication between its
components. The Kubernetes API server, `kubelet`, `etcd`, and other core
components use certificates to authenticate themselves to each other.

By default, Kubernetes uses self-signed certificates generated during cluster
initialization. However, to enable mTLS, you need to ensure that all components
use valid certificates and that certificate authorities (CAs) are trusted.

## Step 2: Generate Certificates for Kubernetes Components

To enable mTLS, you will need to generate certificates for all Kubernetes
components that require secure communication:

1. **Install CFSSL (Cloudflare's PKI Toolkit) on a Control Plane Node:**

   CFSSL is a popular tool for managing certificates. Install it by running the
   following commands:

   ```bash
   sudo apt-get install -y golang-cfssl
   ```

2. **Create a Certificate Authority (CA):**

   Generate a new CA certificate and private key that will be used to sign other
   certificates:

   ```bash
   cfssl gencert -initca csr-ca.json | cfssljson -bare ca
   ```

   The `csr-ca.json` file should contain the CA certificate request
   configuration. The above command will generate `ca.pem` and `ca-key.pem`
   files.

3. **Generate Certificates for Kubernetes Components:**

   For each Kubernetes component (API server, `kubelet`, `etcd`), generate
   certificates signed by the CA:

   ```bash
   cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes component-csr.json | cfssljson -bare component
   ```

   Replace `component-csr.json` with the configuration for each component (such
   as `kube-apiserver-csr.json` or `etcd-csr.json`). This command generates the
   certificate (`component.pem`) and private key (`component-key.pem`) for each
   component.

## Step 3: Distribute Certificates to Components

Once you have generated certificates for each Kubernetes component, distribute
them securely to the relevant nodes:

1. **Copy the Certificates to the Relevant Nodes:**

   Use `scp` or another secure method to copy the certificates and private keys
   to the appropriate directories on each node. For example, to copy the API
   server certificates:

   ```bash
   scp ca.pem kube-apiserver.pem kube-apiserver-key.pem user@node-ip:/etc/kubernetes/pki/
   ```

   Repeat this step for other components like `etcd` and `kubelet`.

2. **Update Component Configurations to Use the Certificates:**

   Modify the configuration files (such as the Kubernetes API server manifest)
   to use the new certificates:

   ```yaml
   - --tls-cert-file=/etc/kubernetes/pki/kube-apiserver.pem
   - --tls-private-key-file=/etc/kubernetes/pki/kube-apiserver-key.pem
   - --client-ca-file=/etc/kubernetes/pki/ca.pem
   ```

   Make similar changes for other components like `etcd` and `kubelet`.

## Step 4: Restart Kubernetes Components

After updating the configurations, restart the Kubernetes components to apply
the new certificates:

- For the API server, run:

  ```bash
  sudo systemctl restart kube-apiserver
  ```

- Repeat this step for other components like `etcd` and `kubelet`.

## Step 5: Verify Mutual TLS Authentication

To verify that mTLS is correctly enabled:

- Check the logs of the Kubernetes API server and other components to confirm
  that secure communication is established:

  ```bash
  sudo journalctl -u kube-apiserver | grep "certificate"
  ```

  Ensure that no errors are related to certificate validation.

- Use `kubectl` to test access and ensure that all components are working
  correctly with mTLS enabled:

  ```bash
  kubectl get nodes
  ```

  All nodes should show as "Ready," indicating that communication between
  components is secure and functional.

## Lesson Conclusion

Congratulations! By enabling Mutual TLS Authentication, you have significantly
enhanced the security of your Kubernetes cluster. In the next lesson, we will
apply network policies to control traffic between pods and further secure your
cluster.

You have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-22).
