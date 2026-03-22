---
layout: guide-lesson.liquid
title: Configuring Access Control and OIDC Authentication

guide_component: lesson
guide_id: migrating-k3s-to-rke2
guide_section_id: 2
guide_lesson_id: 9
guide_lesson_abstract: >
  Configure authentication and RBAC on Cluster B using Structured Authentication Configuration for GitHub OIDC and client certificates for admin access.
  This establishes identity and permissions before workloads arrive, ensuring CI/CD pipelines can deploy from day one.
guide_lesson_conclusion: >
  Cluster B accepts GitHub OIDC tokens for CI/CD automation and uses group-based RBAC for authorization, with client certificates reserved for admin break-glass access.
repo_file_path: guides/migrating-k3s-to-rke2/lesson-9.md
---

Before migrating workloads to Cluster B, CI/CD pipelines need the ability to deploy to it and permissions must be in place before any workloads arrive.
This lesson configures authentication — who can connect to the cluster — and authorization — what they are allowed to do once connected.

{% include guide-overview-link.liquid.html %}

## Understanding Kubernetes Access Control

Every request to the Kubernetes API server passes through three stages before it reaches the resource it targets.
First, authentication validates the caller's identity using certificates, tokens, or other credentials.
Second, authorization evaluates RBAC rules to determine whether the authenticated identity is allowed to perform the requested action.
Third, admission controllers enforce policies like Pod Security Standards and resource quotas.

This lesson focuses on the first two stages.
Admission control is handled by the Pod Security Standards configured in [Lesson 5](/guides/migrating-k3s-to-rke2/lesson-5).

### Authentication Methods

Three authentication methods are relevant for our cluster:

| Method                  | Use Case          | Credential Lifetime               |
| ----------------------- | ----------------- | --------------------------------- |
| Client certificates     | Break-glass only  | Long-lived (kubeconfig from RKE2) |
| `ServiceAccount` tokens | Admin access, IaC | Long-lived (explicit secret)      |
| OIDC tokens             | CI/CD pipelines   | Short-lived (per-workflow)        |

Client certificates are embedded in the kubeconfig that RKE2 generates at `/etc/rancher/rke2/rke2.yaml`.
They grant full `cluster-admin` access and are tied to the `kubernetes-admin` user — a shared identity with no way to distinguish who performed an action.
This makes them unsuitable for day-to-day administration.
They should be reserved as a break-glass credential when SSH'd into the control plane node itself.

`ServiceAccount` tokens provide named identities for both human administrators and automation.
Each admin gets their own ServiceAccount with an explicit token secret, creating a clear audit trail in the API server logs.

OIDC tokens are the best fit for CI/CD pipelines where short-lived, per-workflow credentials are preferred over stored secrets.

## Creating Admin Credentials

### Restricting the Default Kubeconfig

The RKE2-generated kubeconfig at `/etc/rancher/rke2/rke2.yaml` authenticates as `kubernetes-admin` with full `cluster-admin` privileges.
RKE2 defaults to mode `0600` for the kubeconfig, making it readable only by root.
Verify this is the case:

```bash
$ stat /etc/rancher/rke2/rke2.yaml
  File: /etc/rancher/rke2/rke2.yaml
  Size: 2945            Blocks: 8          IO Block: 4096   regular file
Device: 9,1     Inode: 12060119    Links: 1
Access: (0600/-rw-------)  Uid: (    0/    root)   Gid: (    0/    root)
Context: system_u:object_r:etc_t:s0
Access: 2026-02-15 18:17:51.811031115 +0200
Modify: 2026-02-15 18:28:19.277113776 +0200
Change: 2026-02-15 18:28:19.277113776 +0200
 Birth: 2026-02-15 01:04:10.320015075 +0200
```

The `Access` line should show `0600/-rw-------`, confirming that only root can read the file.
From this point on, use personal admin tokens for all cluster operations instead of the default kubeconfig.

### Bootstrapping the RBAC Repository

Rather than hand-crafting RoleBindings for every repository that deploys to the cluster, we delegate RBAC management to a dedicated repository.
This repository uses infrastructure-as-code to create Kubernetes resources — custom ClusterRoles, namespace-scoped RoleBindings, and per-repo permissions — all versioned in Git and applied through CI/CD.

The RBAC repository itself needs `cluster-admin` access to function.
This is a bootstrapping problem: the tool that manages permissions needs permissions before it can manage anything.
We solve it with a ServiceAccount and a static ClusterRoleBinding deployed through the RKE2 manifests directory.

Create the bootstrap manifest at `/var/lib/rancher/rke2/server/manifests/rbac-bootstrap.yaml`:

```yaml
# /var/lib/rancher/rke2/server/manifests/rbac-bootstrap.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: rbac-manager
  namespace: kube-system
  labels:
    app: rbac-manager
    managed-by: manual-bootstrap
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: rbac-manager-admin
  labels:
    app: rbac-manager
    managed-by: manual-bootstrap
subjects:
  - kind: ServiceAccount
    name: rbac-manager
    namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
---
apiVersion: v1
kind: Secret
metadata:
  name: rbac-manager-token
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: rbac-manager
  labels:
    app: rbac-manager
    managed-by: manual-bootstrap
type: kubernetes.io/service-account-token
```

Placing this file in `/var/lib/rancher/rke2/server/manifests/` makes RKE2 auto-deploy it — the same pattern used for Longhorn in [Lesson 7](/guides/migrating-k3s-to-rke2/lesson-7) and Traefik in [Lesson 8](/guides/migrating-k3s-to-rke2/lesson-8).

The manifest creates three resources.
The `ServiceAccount` is what the RBAC repository's pipeline authenticates as.
The `ClusterRoleBinding` grants it `cluster-admin` so it can create and modify RBAC resources across all namespaces.
The `Secret` of type `kubernetes.io/service-account-token` forces Kubernetes to generate a long-lived token for the ServiceAccount — since Kubernetes 1.24, tokens are no longer auto-created as secrets, so this explicit secret is needed for the infrastructure-as-code provider's kubeconfig.

The `managed-by: manual-bootstrap` label marks these as the only hand-managed RBAC resources in the cluster.
Everything else — custom ClusterRoles like `deployer` and `reader`, namespace-scoped RoleBindings for each application repository, and read-only access for pull requests — is created by the RBAC repository through infrastructure-as-code and is outside the scope of this lesson.

### Creating a Personal Admin Token

Each administrator gets their own `ServiceAccount` with `cluster-admin` privileges and a long-lived token.
This provides the same level of access as the RKE2 kubeconfig, but with a named identity that appears in the API server audit logs.

The following example creates an admin credential for a user named `philprime`.
Replace this with your own name or a descriptive identifier for the person who will use the credential.
Create the manifest at `/var/lib/rancher/rke2/server/manifests/rbac-admin-philprime.yaml`:

```yaml
# /var/lib/rancher/rke2/server/manifests/rbac-admin-philprime.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: philprime
  namespace: kube-system
  labels:
    app: admin-access
    managed-by: manual-bootstrap
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: philprime-admin
  labels:
    app: admin-access
    managed-by: manual-bootstrap
subjects:
  - kind: ServiceAccount
    name: philprime
    namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
---
apiVersion: v1
kind: Secret
metadata:
  name: philprime-token
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: philprime
  labels:
    app: admin-access
    managed-by: manual-bootstrap
type: kubernetes.io/service-account-token
```

The structure follows the same three-resource pattern as the RBAC bootstrap manifest above.
RKE2 auto-deploys it from the manifests directory within a few seconds.

Repeat this pattern for each administrator, using a separate file and ServiceAccount name per person.

Extract the token once the secret is created:

```bash
$ sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get secret philprime-token -n kube-system -o jsonpath='{.data.token}' | base64 -d
eyJhbGciOiJSUzI1NiIs...
```

### Configuring kubectl Locally

Rather than running multiple `kubectl config` commands on your local machine, generate a complete kubeconfig on the server that embeds the CA certificate and token.
Run this on the control plane node, replacing `cluster.yourdomain.com` with the public DNS name or IP from the `tls-san` list in [Lesson 5](/guides/migrating-k3s-to-rke2/lesson-5):

```bash
$ export SERVER="https://cluster.yourdomain.com:6443"
$ export CA_DATA=$(sudo base64 -w0 /var/lib/rancher/rke2/server/tls/server-ca.crt)
$ export TOKEN=$(sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get secret philprime-token -n kube-system -o jsonpath='{.data.token}' | base64 -d)

$ cat <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: ${CA_DATA}
    server: ${SERVER}
  name: prod-hel1-2
contexts:
- context:
    cluster: prod-hel1-2
    user: philprime
  name: prod-hel1-2
current-context: prod-hel1-2
users:
- name: philprime
  user:
    token: ${TOKEN}
EOF
```

Copy the output and save it to `~/.kube/config` on your local machine (or merge it into an existing kubeconfig with `KUBECONFIG=~/.kube/config:new-file kubectl config view --flatten`).

Verify the connection from your local machine:

```bash
$ kubectl get nodes
NAME    STATUS   ROLES                       AGE   VERSION
node4   Ready    control-plane,etcd,master   2d    v1.34.3+rke2r3
```

Repeat for each administrator who needs cluster access, using a different ServiceAccount name.
All subsequent commands in this guide assume we are using a personal admin context rather than the default RKE2 kubeconfig.

### Why OIDC for CI/CD

The traditional approach to CI/CD authentication stores a kubeconfig or service account token as a repository secret.
This works, but it creates a long-lived credential that must be manually rotated and grants the same permissions regardless of which workflow uses it.
The credential cannot be traced back to a specific deployment without additional logging and remains valid until explicitly revoked, even if the repository is compromised.

GitHub OIDC eliminates these problems.
Each workflow run requests a fresh token from GitHub's OIDC provider, and the Kubernetes API server validates it directly — no shared secrets involved.
The token is scoped to the repository and workflow that requested it, expires within minutes, and produces a clear audit trail linking every API call back to a specific commit and actor.

## Structured Authentication Configuration

Kubernetes 1.29 introduced Structured Authentication Configuration as a replacement for the legacy `--oidc-*` command-line flags on the API server.
Instead of passing issuer URL, client ID, and claim mappings as individual flags, we write a single configuration file that the API server reads at startup.

The API is available as `apiserver.config.k8s.io/v1beta1` in Kubernetes 1.30 and 1.31 and graduated to `v1` in Kubernetes 1.32.
Since RKE2 v1.34 ships Kubernetes 1.34, we use the stable `v1` version.

### Advantages Over Legacy Flags

The legacy `--oidc-*` flags support exactly one JWT issuer and require an API server restart to change any setting.
Structured Authentication Configuration supports multiple JWT issuers in a single configuration file, uses CEL-based expressions for claim mapping to transform claims into Kubernetes usernames and groups, and includes claim validation rules that reject tokens not matching specific criteria.
The API server reads the configuration file at startup without needing separate flags for each field.

### Key Fields

The configuration file defines a list of JWT authenticators under the `jwt` key.

| Field                    | Purpose                                                                 |
| ------------------------ | ----------------------------------------------------------------------- |
| `issuer.url`             | The OIDC issuer URL — must match the `iss` claim in the token           |
| `issuer.audiences`       | Accepted `aud` values — tokens with different audiences are rejected    |
| `claimMappings.username` | CEL expression that produces the Kubernetes username                    |
| `claimMappings.groups`   | CEL expression that produces a list of Kubernetes groups                |
| `claimValidationRules`   | CEL expressions that must evaluate to true for the token to be accepted |

## GitHub OIDC Claims

GitHub Actions can request an OIDC token from `https://token.actions.githubusercontent.com` during any workflow run.
The token contains claims that describe the context of the workflow — which repository triggered it, who initiated it, and what branch is being built.

### Useful Claims

| Claim              | Example Value                                  | Purpose              |
| ------------------ | ---------------------------------------------- | -------------------- |
| `sub`              | `repo:kula-app/my-project:ref:refs/heads/main` | Full identity string |
| `repository`       | `kula-app/my-project`                          | Repository name      |
| `repository_owner` | `kula-app`                                     | Organization         |
| `actor`            | `philprime`                                    | User who triggered   |
| `ref`              | `refs/heads/main`                              | Branch or tag        |

### Mapping Claims to Kubernetes Identity

We map the `repository` claim to a Kubernetes username of the form `github-actions:repo:<repository>`, giving each repository its own identity for audit trails.
For groups, each token receives membership in two groups: `github-actions` as a broad group for all GitHub Actions and `github-actions:<repository_owner>` as an organization-level group for RBAC bindings.

A deployment from `kula-app/my-project` authenticates as user `github-actions:repo:kula-app/my-project` in groups `github-actions` and `github-actions:kula-app`.
The URN-like format (`github-actions:repo:org/name`) makes the identity self-describing and consistent with GitHub's own `sub` claim structure.
RBAC bindings target the organization group, so adding a new repository to the organization automatically grants it the same permissions without touching any cluster configuration.

## Configuring the Authentication

The authentication configuration lives in two files: one that describes the OIDC provider and one that tells RKE2 to load it.

Unlike the RBAC manifests created earlier in this lesson, the `AuthenticationConfiguration` is not a Kubernetes resource.
It is a local file that the kube-apiserver reads at startup — it never enters the Kubernetes API and is not applied with `kubectl`.
This is why we place it in `/etc/rancher/rke2/` alongside the other RKE2 configuration files rather than in `/var/lib/rancher/rke2/server/manifests/`, which is reserved for Kubernetes resources that the Helm controller auto-deploys into the cluster.

We use `/etc/rancher/rke2/auth-config.yaml` to keep it next to `config.yaml.d/` and `rke2.yaml`, but any location works as long as the RKE2 config references the same path.

### AuthenticationConfiguration

Create the file at `/etc/rancher/rke2/auth-config.yaml`:

```yaml
# /etc/rancher/rke2/auth-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
jwt:
  - issuer:
      url: https://token.actions.githubusercontent.com
      audiences:
        - api://prod-hel1-2.k8s.kula.app
    claimMappings:
      username:
        expression: "'github-actions:repo:' + claims.repository"
      groups:
        expression: "['github-actions', 'github-actions:' + claims.repository_owner]"
    claimValidationRules:
      # Replace <your-github-org> with your actual GitHub organization name
      - expression: "claims.repository_owner == '<your-github-org>'"
        message: "token must come from your GitHub organization"
```

Replace `<your-github-org>` with your actual GitHub organization name (for example, `kula-app`).

The `issuer.url` must exactly match the `iss` claim in GitHub's OIDC tokens.
The `audiences` list defines what value the workflow must request as the token's `aud` claim — we use `api://prod-hel1-2.k8s.kula.app` as a custom audience that identifies this specific cluster.
The `api://` scheme follows the convention for non-web API audiences, distinguishing it from the cluster's HTTPS endpoint.

The `claimMappings` section uses CEL expressions to transform token claims into Kubernetes identity.
The `username` expression concatenates the string `github-actions:` with the repository claim, producing identities like `github-actions:repo:kula-app/my-project`.
The `groups` expression builds a list of two groups — one for all GitHub Actions and one scoped to the organization.

The `claimValidationRules` section acts as a gatekeeper.
The expression `claims.repository_owner == '<your-github-org>'` ensures that only tokens from our organization are accepted.
A token from a forked repository in a different organization would be rejected with the message "token must come from your GitHub organization".

### Wiring It into RKE2

RKE2 runs the kube-apiserver as a static pod, which normally cannot see files on the host filesystem.
When a `kube-apiserver-arg` references a file path under `/etc/rancher/rke2/`, RKE2 automatically bind-mounts that file into the static pod — the same mechanism it uses for `rke2-pss.yaml` and other configuration files.
This means we only need to pass the argument and no explicit `kube-apiserver-extra-mount` is required.

Create the RKE2 config file at `/etc/rancher/rke2/config.yaml.d/40-authentication.yaml`:

```yaml
# /etc/rancher/rke2/config.yaml.d/40-authentication.yaml
kube-apiserver-arg:
  - "authentication-config=/etc/rancher/rke2/auth-config.yaml"
```

The `authentication-config` argument tells the API server to load the Structured Authentication Configuration from that file.

This follows the same numbered-file pattern used for network (`10-network.yaml`), external access (`20-external-access.yaml`), and security (`30-security.yaml`) in [Lesson 5](/guides/migrating-k3s-to-rke2/lesson-5).

Restart RKE2 to apply the new configuration:

```bash
$ sudo systemctl restart rke2-server
```

The API server will re-read all configuration files and initialize the OIDC authenticator during startup.

## Verification

### Cluster Health After Restart

After restarting RKE2, verify that the cluster is healthy:

```bash
$ export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
$ kubectl get nodes
NAME    STATUS   ROLES                       AGE   VERSION
node4   Ready    control-plane,etcd,master   2d    v1.34.3+rke2r3

$ kubectl get pods -n kube-system
NAME                                                    READY   STATUS      RESTARTS       AGE
cloud-controller-manager-node4                          1/1     Running     0              102m
etcd-node4                                              1/1     Running     0              102m
helm-install-longhorn-7qmq4                             0/1     Completed   2              3h6m
helm-install-rke2-canal-hcw7r                           0/1     Completed   0              15h
helm-install-rke2-coredns-p7rr9                         0/1     Completed   1              14h
helm-install-rke2-metrics-server-vgqrn                  0/1     Completed   0              16h
helm-install-rke2-runtimeclasses-x6s6t                  0/1     Completed   0              16h
helm-install-rke2-snapshot-controller-2mcgw             0/1     Completed   2              16h
helm-install-rke2-snapshot-controller-crd-flrjh         0/1     Completed   0              16h
helm-install-traefik-qxlw4                              0/1     Completed   0              9m31s
kube-apiserver-node4                                    1/1     Running     0              102m
kube-controller-manager-node4                           1/1     Running     0              102m
kube-proxy-node4                                        1/1     Running     0              9m52s
kube-scheduler-node4                                    1/1     Running     0              102m
rke2-canal-gpwx8                                        2/2     Running     0              15h
rke2-coredns-rke2-coredns-5ccb49bfd9-nfbdz              1/1     Running     0              14h
rke2-coredns-rke2-coredns-autoscaler-84ff4dbbb4-xbkzk   1/1     Running     0              14h
rke2-metrics-server-7b59bd8854-blsqz                    1/1     Running     0              16h
rke2-snapshot-controller-9fccd4467-ht975                1/1     Running     8 (105m ago)   16h
traefik-628vd                                           1/1     Running     0              73m
```

All pods in `kube-system` should be in `Running` state (except for completed Helm install jobs).
If the API server fails to start, check the troubleshooting section below.

### Verify Authentication Configuration

Confirm that the kube-apiserver started with the `--authentication-config` flag:

```bash
$ ps aux | grep kube-apiserver | grep authentication-config
root     2174001 17.7  0.4 1823692 600736 ?      Ssl  18:17   0:32 kube-apiserver ... --authentication-config=/etc/rancher/rke2/auth-config.yaml --authorization-mode=Node,RBAC ...
```

The output should contain `--authentication-config=/etc/rancher/rke2/auth-config.yaml`.
If the flag is missing, the `40-authentication.yaml` config file may not have been picked up — verify it exists and restart RKE2.

### Verify RBAC

Confirm the bootstrap resources were auto-deployed:

```bash
$ kubectl get serviceaccount rbac-manager -n kube-system
NAME           SECRETS   AGE
rbac-manager   0         30s

$ kubectl get clusterrolebinding rbac-manager-admin
NAME                 ROLE                        AGE
rbac-manager-admin   ClusterRole/cluster-admin   30s

$ kubectl get secret rbac-manager-token -n kube-system
NAME                 TYPE                                  DATA   AGE
rbac-manager-token   kubernetes.io/service-account-token   3      30s
```

All three resources should exist and show a recent creation time.

### Testing OIDC from GitHub Actions

To use this authentication from a GitHub Actions workflow, the workflow requests an OIDC token with the configured audience and passes it as a bearer token in a kubeconfig.
The workflow needs `id-token: write` permission and uses `actions/github-script` or a direct API call to obtain the token:

```yaml
permissions:
  id-token: write

steps:
  - name: Get OIDC token
    id: token
    run: |
      TOKEN=$(curl -sLS "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://prod-hel1-2.k8s.kula.app" \
        -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}")
      echo "id_token=$(echo "$TOKEN" | jq -r '.value')" >> "$GITHUB_OUTPUT"
```

The token is then used as a bearer token in a kubeconfig that points to Cluster B's API server.
The full workflow integration depends on the deployment tooling — the key requirement is that the `audience` parameter matches the value configured in `auth-config.yaml`.

## Troubleshooting

### kube-apiserver Fails to Start

If RKE2 does not come back up after the restart, check the server logs:

```bash
$ sudo journalctl -xeu rke2-server | tail -50
```

If the journal shows no clear error, check the kubelet log — the apiserver runs as a static pod and the kubelet logs manifest validation failures:

```bash
$ sudo tail -200 /var/lib/rancher/rke2/agent/logs/kubelet.log | grep -iE "apiserver|error|fail|mount"
```

The most common causes are YAML syntax errors in `auth-config.yaml`, which can be validated with `python3 -c "import yaml; yaml.safe_load(open('/etc/rancher/rke2/auth-config.yaml'))"`.
Duplicate volume mounts also cause problems — do not add `kube-apiserver-extra-mount` for the auth config file because RKE2 auto-mounts files referenced by `kube-apiserver-arg` and a duplicate mount causes the static pod manifest to be rejected.
File permissions matter as well — the auth-config file must be readable by the rke2 process.

To recover quickly, remove or rename the `40-authentication.yaml` file and restart:

```bash
$ sudo mv /etc/rancher/rke2/config.yaml.d/40-authentication.yaml /tmp/
$ sudo systemctl restart rke2-server
```

Once the cluster is back, fix the configuration and re-apply.

### OIDC Token Rejected

If a GitHub Actions workflow receives a `401 Unauthorized` when authenticating, start by verifying the audience matches — the workflow must request `api://prod-hel1-2.k8s.kula.app` as the audience, matching the `audiences` list in `auth-config.yaml`.
The issuer URL must be exactly `https://token.actions.githubusercontent.com` with no trailing slash.
If the `repository_owner` in the token does not match the claim validation rule, the token is rejected with the configured error message.

Inspect the API server logs for detailed rejection reasons:

```bash
$ sudo journalctl -u rke2-server | grep -i oidc
```

### RBAC Permission Denied

If an authenticated request receives `403 Forbidden`, verify the bootstrap ClusterRoleBinding exists:

```bash
$ kubectl get clusterrolebinding rbac-manager-admin -o yaml
```

For application repositories, check that the RBAC pipeline has created the expected RoleBindings:

```bash
$ kubectl get rolebindings -A -l managed-by=rbac-manager
```

To test permissions for a specific identity, use `kubectl auth can-i`:

```bash
$ kubectl auth can-i create deployments --as="github-actions:repo:kula-app/my-repo" -n <namespace>
```
