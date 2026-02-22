---
layout: guide-lesson.liquid
title: Setting Up cert-manager for TLS Certificates

guide_component: lesson
guide_id: migrating-k3s-to-rke2
guide_section_id: 2
guide_lesson_id: 10
guide_lesson_abstract: >
  Install cert-manager as a default RKE2 manifest and configure Let's Encrypt ClusterIssuers for automatic TLS certificate provisioning.
  cert-manager handles the full certificate lifecycle — requesting, storing, and renewing — so that every Ingress resource can obtain trusted TLS certificates without manual intervention.
guide_lesson_conclusion: >
  cert-manager is running as a default cluster service with both staging and production Let's Encrypt issuers ready for use.
repo_file_path: guides/migrating-k3s-to-rke2/lesson-10.md
---

Nearly every service exposed through an ingress controller needs a TLS certificate.
Rather than managing certificates manually, we install cert-manager as a foundational cluster service that automatically issues and renews them through Let's Encrypt.

{% include guide-overview-link.liquid.html %}

## Understanding cert-manager

[cert-manager](https://cert-manager.io/) is a Kubernetes-native certificate management controller.
It watches for `Certificate` resources and `Ingress` annotations, then handles the entire lifecycle — requesting certificates from an issuer, storing them as Kubernetes Secrets, and renewing them before they expire.
This makes TLS certificate management fully declarative, matching the way we manage every other resource in Kubernetes.

cert-manager supports multiple issuers, but the most common setup for public-facing services uses the ACME protocol with [Let's Encrypt](https://letsencrypt.org/).
ACME proves domain ownership through a challenge — in our case, the HTTP-01 challenge, where cert-manager temporarily creates an ingress route that responds to a validation request from Let's Encrypt.
Once validation succeeds, Let's Encrypt issues a certificate and cert-manager stores it in a Secret that Traefik (configured in Lesson 8) can use to terminate TLS.

### Why Install It as a Default Manifest

cert-manager sits at the infrastructure layer — it must be running before any workload that needs TLS can be deployed.
Placing it in `/var/lib/rancher/rke2/server/manifests/` ensures it is installed automatically when the cluster starts, following the same pattern used for Longhorn in Lesson 7 and Traefik in Lesson 8.
This eliminates ordering problems where a deployment arrives before its certificate issuer is available.

### Staging vs. Production Issuers

Let's Encrypt provides two ACME endpoints:

| Endpoint   | URL                                                      | Rate Limits              | Certificate Trust       |
| ---------- | -------------------------------------------------------- | ------------------------ | ----------------------- |
| Staging    | `https://acme-staging-v02.api.letsencrypt.org/directory` | Generous (for testing)   | Not trusted by browsers |
| Production | `https://acme-v02.api.letsencrypt.org/directory`         | 50 certificates per week | Trusted by all browsers |

Always test with the staging issuer first.
Production rate limits are strict — if we hit them during debugging, the account may be locked out for a week.
Once certificates issue correctly with staging, we switch the annotation on the Ingress to the production issuer.

## Installing cert-manager

Create the manifest at `/var/lib/rancher/rke2/server/manifests/cert-manager.yaml`:

```yaml
# /var/lib/rancher/rke2/server/manifests/cert-manager.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: cert-manager
  namespace: kube-system
spec:
  repo: https://charts.jetstack.io
  chart: cert-manager
  version: "v1.19.3"
  targetNamespace: cert-manager
  createNamespace: true
  valuesContent: |-
    crds:
      enabled: true
    extraArgs:
      - "--feature-gates=ACMEHTTP01IngressPathTypeExact=false"
    resources:
      requests:
        cpu: 10m
        memory: 64Mi
      limits:
        cpu: 200m
        memory: 512Mi
    webhook:
      resources:
        requests:
          cpu: 10m
          memory: 64Mi
        limits:
          cpu: 200m
          memory: 512Mi
    cainjector:
      resources:
        requests:
          cpu: 10m
          memory: 64Mi
        limits:
          cpu: 200m
          memory: 512Mi
```

The chart installs three components:

| Component  | Purpose                                                                |
| ---------- | ---------------------------------------------------------------------- |
| controller | Watches `Certificate` and `Ingress` resources, issues and renews certs |
| webhook    | Validates and mutates cert-manager custom resources on admission       |
| cainjector | Injects CA bundles into webhook configurations and CRDs                |

The `crds.enabled: true` setting installs cert-manager's Custom Resource Definitions — `Certificate`, `Issuer`, `ClusterIssuer`, and others — as part of the Helm release.
This keeps the CRD lifecycle tied to the chart version, so upgrades handle schema changes automatically.

The `ACMEHTTP01IngressPathTypeExact=false` feature gate disables a [breaking change introduced in cert-manager v1.18.0](https://cert-manager.io/docs/releases/release-notes/release-notes-1.18/#option-1-disable-the-acmehttp01ingresspathtypeexact-feature-in-cert-manager) that sets the ingress path type to `Exact` for HTTP-01 challenge solvers.
With Traefik, the default `Prefix` path type works correctly and the `Exact` type can cause challenge failures depending on the Traefik configuration.
Disabling this gate preserves the behavior that cert-manager used before v1.18.0.

RKE2 detects the new manifest and installs the chart automatically.
We can watch the pods come up in the `cert-manager` namespace:

```bash
$ kubectl get pods -n cert-manager -w
NAME                                       READY   STATUS    RESTARTS   AGE
cert-manager-648d5cd64b-jcfdm              1/1     Running   0          22s
cert-manager-cainjector-7c8f95fb68-nrpfw   1/1     Running   0          22s
cert-manager-webhook-7c98c76c9c-rf687      1/1     Running   0          22s
```

All three pods should reach `Running` state within a minute or two.

## Creating ClusterIssuers

A `ClusterIssuer` is a cluster-wide resource that tells cert-manager how to obtain certificates.
Unlike a namespace-scoped `Issuer`, a `ClusterIssuer` can serve certificates for Ingress resources in any namespace — the right choice for a shared infrastructure service.
We create two of them: one for staging and one for production.

The ClusterIssuer resources depend on cert-manager's CRDs, which only exist after the Helm chart finishes installing.
RKE2's deploy controller retries failed manifests, so we can place the ClusterIssuers in the same manifests directory.
They will fail initially while cert-manager is still starting, then succeed automatically once the CRDs are registered.

Create the manifest at `/var/lib/rancher/rke2/server/manifests/cert-manager-issuers.yaml`:

```yaml
# /var/lib/rancher/rke2/server/manifests/cert-manager-issuers.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    # Replace with your email address
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
      - http01:
          ingress:
            ingressClassName: traefik
            serviceType: ClusterIP
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    # Replace with your email address
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-production
    solvers:
      - http01:
          ingress:
            ingressClassName: traefik
            serviceType: ClusterIP
```

Both issuers use the HTTP-01 challenge solver with Traefik as the ingress class.
When cert-manager needs to prove domain ownership, it creates a temporary `Ingress` resource that routes the ACME challenge path (`/.well-known/acme-challenge/...`) through Traefik to a solver pod.
The `serviceType: ClusterIP` setting keeps the solver pod's service as a ClusterIP rather than a LoadBalancer, since Traefik already handles external traffic routing.

The `privateKeySecretRef` specifies where cert-manager stores the ACME account private key.
This key is generated automatically on first use and reused for subsequent certificate requests.
Each issuer gets its own key to keep staging and production accounts separate.

## Verification

### Check cert-manager Components

We verify that all cert-manager pods are running and the webhook is ready:

```bash
$ kubectl get pods -n cert-manager
NAME                                       READY   STATUS    RESTARTS   AGE
cert-manager-648d5cd64b-jcfdm              1/1     Running   0          3m26s
cert-manager-cainjector-7c8f95fb68-nrpfw   1/1     Running   0          3m26s
cert-manager-webhook-7c98c76c9c-rf687      1/1     Running   0          3m26s
```

All three pods should show `1/1` in the `READY` column and `Running` as the status.

### Check ClusterIssuers

Both issuers should show `Ready: True` once they have successfully registered with the ACME server:

```bash
$ kubectl get clusterissuer
NAME                     READY   AGE
letsencrypt-production   True    57s
letsencrypt-staging      True    57s
```

If an issuer shows `Ready: False`, inspect it for details:

```bash
$ kubectl describe clusterissuer letsencrypt-staging
```

The `Events` section at the bottom shows the ACME registration status.
A successful registration produces an event like `The ACME account was registered with the ACME server`.
If registration failed, the events will contain the error message from the ACME server.

### Test Certificate Issuance

To verify the full chain works — from certificate request through ACME challenge to signed certificate — we create a test `Certificate` resource.
This requires a domain name that resolves to the cluster's ingress IP (the Hetzner Load Balancer configured in Lesson 8):

```bash
$ cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-cert
  namespace: default
spec:
  secretName: test-cert-tls
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
  dnsNames:
    - test.yourdomain.com
EOF
```

We watch the certificate progress:

```bash
$ kubectl get certificate test-cert -w
NAME        READY   SECRET          AGE
test-cert   False   test-cert-tls   5s
test-cert   True    test-cert-tls   45s
```

The certificate transitions from `False` to `True` once Let's Encrypt validates the domain and issues the certificate.
If it stays `False`, check the `CertificateRequest` and `Order` resources for error details:

```bash
$ kubectl describe certificaterequest -l cert-manager.io/certificate-name=test-cert
$ kubectl describe order -l cert-manager.io/certificate-name=test-cert
```

Remove the test resources once verified:

```bash
$ kubectl delete certificate test-cert
$ kubectl delete secret test-cert-tls
```

## Using Certificates with Ingress

With cert-manager and the ClusterIssuers in place, any Ingress resource can request automatic TLS by adding a single annotation.
The following example shows the pattern — we do not need to apply this now, but it demonstrates how workloads will use cert-manager going forward:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-production
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - app.yourdomain.com
      secretName: my-app-tls
  rules:
    - host: app.yourdomain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

The `cert-manager.io/cluster-issuer` annotation tells cert-manager which issuer to use.
cert-manager automatically creates a `Certificate` resource, completes the ACME challenge, and stores the resulting certificate in the Secret referenced by `secretName`.
Traefik picks up the Secret and terminates TLS for the specified host.
