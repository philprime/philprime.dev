---
layout: post.liquid
title: 'K3s powered GitHub Actions Runner'
date: 2025-03-22 11:00:00 +0200
categories: blog
tags: Kubernetes GitHub Actions Runner
---

# Introduction

- We are using a dedicated root server at Hetzner.
- We are using k3s to spin up an easy Kubernetes cluster.
- Then we install the GitHub Actions Runner Controller in the cluster.
- We are doing this because it allows multiple parallel runners with access to a container runtime. We had issues in the
  past that runners using the docker runtime to build container images were blocking each other.

# Steps:

Link to documentation: https://docs.k3s.io/

## Check available hardware specs

To see the available hardware specs, we can use the `lscpu` command to see details about the CPU, `free -h` to check
memory usage and available RAM, and `lsblk` to see details about the storage.

```bash
$ lscpu
Architecture:            x86_64
  CPU op-mode(s):        32-bit, 64-bit
  Address sizes:         43 bits physical, 48 bits virtual
  Byte Order:            Little Endian
CPU(s):                  16
  On-line CPU(s) list:   0-15
Vendor ID:               AuthenticAMD
  BIOS Vendor ID:        Advanced Micro Devices, Inc.
  Model name:            AMD Ryzen 7 3700X 8-Core Processor
    BIOS Model name:     AMD Ryzen 7 3700X 8-Core Processor
    CPU family:          23
    Model:               113
    Thread(s) per core:  2
    Core(s) per socket:  8
    Socket(s):           1
    Stepping:            0
    Frequency boost:     enabled
    CPU(s) scaling MHz:  100%
    CPU max MHz:         3600.0000
    CPU min MHz:         2200.0000
...
Virtualization features:
  Virtualization:        AMD-V
...
```

The server has a mid-level AMD Ryzen 7 3700X processor with 8 physical cores and 16 total threads through
hyperthreading, capable of speeds between 2.2GHz and 3.6GHz. It supports hardware virtualization through AMD-V, making
it well-suited for running containerized workloads in Kubernetes.

The server has 64GB (62 GiB) of RAM and is currently configured to use 32GB (31 GiB) as swap.

```bash
$ free -h
               total        used        free      shared  buff/cache   available
Mem:            62Gi       2.3Gi        14Gi        97Mi        45Gi        59Gi
Swap:           31Gi       287Mi        31Gi
```

The storage consists of two NVMe drives, each with 1TB of storage, combined in a RAID 1 configuration for redundancy.

```bash
$ lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE  MOUNTPOINTS
nvme1n1     259:0    0 953.9G  0 disk
├─nvme1n1p1 259:2    0    32G  0 part
│ └─md0       9:0    0    32G  0 raid1 [SWAP]
├─nvme1n1p2 259:3    0     1G  0 part
│ └─md1       9:1    0  1022M  0 raid1 /boot
└─nvme1n1p3 259:4    0 920.9G  0 part
  └─md2       9:2    0 920.7G  0 raid1 /
nvme0n1     259:1    0 953.9G  0 disk
├─nvme0n1p1 259:5    0    32G  0 part
│ └─md0       9:0    0    32G  0 raid1 [SWAP]
├─nvme0n1p2 259:6    0     1G  0 part
│ └─md1       9:1    0  1022M  0 raid1 /boot
└─nvme0n1p3 259:7    0 920.9G  0 part
  └─md2       9:2    0 920.7G  0 raid1 /
```

For reference, we are paying roughly 32 EUR excl. VAT per month for this server.

## Defining the game plan

We want to set up a single node cluster, to get a quick working example. Eventually we will add additional nodes to the
cluster to scale up the number of parallel jobs.

Then we want to deploy the GitHub Actions Runner Controller in the cluster. We will create a repository to store all the
configuration files for the runners. To deploy the resources we are using self-hosted GitHub Actions runners and Pulumi
to deploy the resources to the cluster.

The goal is having a single node cluster with a single runner that is automatically started when a job is triggered in a
repository.

We will configure the workflow of the repository to use the runner and self-update using Dependabot.

## Install k3s

I went ahead and read through all of the relevant K3s documentation so that you don't have to.

Before blindly following any instructions, please make sure to read the official documentation and understand the
implications of your actions.

To setup k3s we use the can use the install script available at https://get.k3s.io. To better understand the
implications of the install script, let's break down the steps of the script:

- `verify_system` checks if the system offers `systemd` or `openrc` as a process supervisor.
- `setup_env` sets the environment variables for the install process.
- `download_and_verify` downloads the k3s binary and verifies the checksum.
- `setup_selinux` sets the SELinux policy for k3s.
- `create_symlinks` creates the symlinks for the k3s binary.
- `create_killall` creates the killall script used to kill all processes started by k3s.
- `create_uninstall` creates the uninstall script.
- `systemd_disable` disables the k3s systemd service if it is enabled.
- `create_env_file` creates the environment file for the k3s service.
- `create_service_file` creates the service file for the k3s service.
- `service_enable_and_start` enables and starts the k3s service.

Now that we understand the install script, we need to define which options we want to use. As we are running a CI
server, we don't need to enable the `servicelb` or `traefik` ingress controllers. Furthermore, we want to be able to add
additional nodes to the cluster later on, therefore we need to replace the default SQLite datastore with an etcd
datastore.

To summarize this, we will use the following options:

```bash
--cluster-init                # Initialize a new cluster using embedded Etcd
--node-name ci-kang           # Just for fun we name our nodes after Marvel supervillains, i.e. Kang the Conqueror
--disable servicelb,traefik   # Disable the packaged components that we don't need
```

Combine it with the install script and we are ready to go:

```bash
$ curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--cluster-init --node-name ci-kang --disable servicelb,traefik" sh -
```

After it's done, we can check the status of the cluster:

```bash
$ sudo systemctl status k3s
● k3s.service - Lightweight Kubernetes
     Loaded: loaded (/etc/systemd/system/k3s.service; enabled; preset: disabled)
     Active: active (running) since Sat 2025-03-22 12:09:32 CET; 31min ago
...
```

To access the cluster using `kubectl`, we need to copy the generated kubeconfig to the default location:

```bash
# Create the directory if it doesn't exist
$ mkdir -p ~/.kube

# Copy the kubeconfig to the default location
$ sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

# Set the correct ownership
$ sudo chown $(id -u):$(id -g) ~/.kube/config

# Add the KUBECONFIG environment variable to the bashrc
$ echo "export KUBECONFIG=~/.kube/config" >> ~/.bashrc

# Reload the shell or run the following command:
$ export KUBECONFIG=~/.kube/config
```

Now we can check that we can access the cluster:

```bash
$ kubectl get nodes
NAME      STATUS   ROLES                  AGE   VERSION
ci-kang   Ready    control-plane,etcd     31m   v1.27.4+k3s1
```

## Setting up Pulumi to manage the infrastructure

[Pulumi](https://www.pulumi.com/) is a tool for managing infrastructure as code. Essentially it allows us to write
infrastructure as code in our favorite language and deploy it to the cloud. During deployment, Pulumi will keep track of
the resources and their state, and only update the resources that have changed.

While Pulumi is a general purpose tool for managing infrastructure, we can also use it to deploy Kubernetes resources
using the Pulumi Kubernetes provider.

As I am quite comfortable with TypeScript, I will use it to write the Infrastructure as Code (IaC) for our project.

First, we need to install Pulumi using their install script. Make sure to take a look at the installation instructions
for your platform and **do not run any script from the internet without verifying it first**.

```bash
$ curl -fsSL https://get.pulumi.com | sh
```

### Preparing the project workspace

To get started create a new directory for our project:

```bash
$ mkdir -p /apps/ci-infra
$ cd /apps/ci-infra
$ echo "# CI Infrastructure" > README.md
```

As we always want to use version control and want to deploy our changes using GitHub Actions, we need to initialize the
local git repository and push it to GitHub:

```bash
$ git init
$ git add README.md
$ git commit -m "docs: add README"
$ git remote add origin git@github.com:kula-app/ci-infra.git
$ git branch -M main
$ git push -u origin main
```

In our case we are using Pulumi self-hosted with AWS S3 bucket as the backend, so I will have to login to the
self-hosted endpoint first. In case you are following along this guide, feel free to use the Pulumi Cloud backend or any
other backend that you want. After the login, it should not have differ.

```bash
# Login to the Pulumi self-hosted endpoint
$ tee ~/.aws/credentials <<EOF
[ci-infra]
aws_access_key_id = REPLACE ME
aws_secret_access_key = REPLACE ME
region = eu-north-1
EOF

# (Optional) Add the `AWS_PROFILE` to your `.env` file:
$ echo "AWS_PROFILE=ci-infra" >> .env
$ echo ".env" >> .gitignore
# To load the variables from the `.env` file, run the following command:
$ set -a; source .env; set +a

# Login to the Pulumi self-hosted endpoint
$ pulumi login s3://<BUCKET_NAME>
Logged in ...

# or use the Pulumi Cloud backend
$ pulumi login
```

Before we can initialize the Pulumi project, we need to define a passphrase for encrypting the state. This can be any
string, but it is recommended to use a random string. Make sure to save it in a secure location, as we need it to
decrypt the state later on.

For convenience, we can save it to a `.env` file, which we will add to the `.gitignore` file:

```bash
$ echo "PULUMI_CONFIG_PASSPHRASE=$(openssl rand -hex 32)" >> .env
$ set -a; source .env; set +a
```

Next we need to install Node.js and Yarn to compile and run the Pulumi program. I prefer to manage the Node.js version
using [`nvm`](https://github.com/nvm-sh/nvm), so we will install that first.

```bash
$ curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash
$ export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Install the latest LTS version of Node.js
$ nvm install --lts
Installing latest LTS version.
v22.14.0 is already installed.
Now using node v22.14.0 (npm v10.9.2)

# Install Yarn Berry
$ corepack enable
$ corepack use yarn@latest
Installing yarn@4.7.0 in the project...

➤ YN0000: · Yarn 4.7.0
➤ YN0000: ┌ Resolution step
➤ YN0000: └ Completed
➤ YN0000: ┌ Fetch step
➤ YN0000: └ Completed
➤ YN0000: ┌ Link step
➤ YN0000: └ Completed
➤ YN0000: · Done in 0s 29ms

# Pulumi requires a node_modules directory, so we need to configure the Yarn node linker:
$ yarn config set nodeLinker node-modules

# Add the `.yarn` directory to the `.gitignore` file:
$ echo ".yarn" >> .gitignore
```

At this point the directory structure should look like this:

```bash
$ tree -aI 'node_modules|.git'
.
├── .env
├── .gitignore
├── package.json
├── README.md
├── .yarn
│   └── install-state.gz
├── yarn.lock
└── .yarnrc.yml
```

Before continuing, we add the newly created files to the git repository:

```bash
$ git add .
$ git status
On branch main
Your branch is ahead of 'origin/main' by 1 commit.
  (use "git push" to publish your local commits)

Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        modified:   .gitignore
        new file:   .yarnrc.yml
        new file:   package.json
        new file:   yarn.lock

$ git commit -m "chore(deps): configure Yarn"
[main e334ecd] chore(deps): configure Yarn
 4 files changed, 17 insertions(+)
 create mode 100644 .yarnrc.yml
 create mode 100644 package.json
 create mode 100644 yarn.lock
```

## Creating the Pulumi project

Now we can create the Pulumi project. You can choose any of the available templates, but for this setup we are going to
do it manually from scratch.

Create the main project file `Pulumi.yaml`:

```bash
$ tee Pulumi.yaml <<EOF
name: ci-infra
description: Program to manage CI infrastructure
runtime:
  name: nodejs
  options:
    packagemanager: yarn
config: {}
EOF
```

Add the dependencies `@pulumi/pulumi` and `@pulumi/kubernetes`:

```bash
$ yarn init -n ci-infra
$ yarn add @pulumi/pulumi @pulumi/kubernetes
$ yarn add -D @types/node typescript
```

Create the `tsconfig.json` file:

```bash
$ tee tsconfig.json <<EOF
{
    "compilerOptions": {
        "strict": true,
        "outDir": "bin",
        "target": "es2020",
        "module": "commonjs",
        "moduleResolution": "node",
        "sourceMap": true,
        "experimentalDecorators": true,
        "pretty": true,
        "noFallthroughCasesInSwitch": true,
        "noImplicitReturns": true,
        "forceConsistentCasingInFileNames": true
    },
    "files": [
        "index.ts"
    ]
}
EOF
```

Create the `index.ts` with a basic Pulumi program:

```bash
$ tee index.ts <<EOF
import * as kubernetes from "@pulumi/kubernetes";

const namespace = new kubernetes.core.v1.Namespace("ci-infra", {
  metadata: {
    name: "ci-infra",
  },
});
EOF
```

Now we can initialize the Pulumi project:

```bash
$ pulumi stack init dev
```

This will create a new stack called `dev`. To deploy the infrastructure, we can use the following command:

```bash
$ pulumi up
Previewing update (dev):
     Type                             Name          Plan
 +   pulumi:pulumi:Stack              ci-infra-dev  create
 +   └─ kubernetes:core/v1:Namespace  ci-infra      create

Resources:
    + 2 to create

Do you want to perform this update? yes
Updating (dev):
     Type                             Name          Status
 +   pulumi:pulumi:Stack              ci-infra-dev  created (1s)
 +   └─ kubernetes:core/v1:Namespace  ci-infra      created (0.23s)

Resources:
    + 2 created

Duration: 3s
```

To verify that the namespace was created, we can use the following command:

```bash
$ kubectl get namespaces
NAME              STATUS   AGE
ci-infra          Active   31s
default           Active   108m
kube-node-lease   Active   108m
kube-public       Active   108m
kube-system       Active   108m
```

Add all files to the git repository and commit the changes.

## Installing the GitHub Actions Runner Controller

The GitHub Actions Runner Controller (ARC) is a Kubernetes controller that manages the lifecycle of GitHub Actions
runners. By using the controller, we can define runner scale sets with minimum and maximum replicas. The controller will
then automatically start and stop the runners to match the desired state, depending on the number of jobs in the queue.

To deploy the setup we need to deploy two Helm Charts:

- The `gha-runner-scale-set-controller` to deploy the controller.
- The `gha-runner-scale-set` to deploy the runner scale set.

For the `gha-runner-scale-set-controller` we need to create a GitHub App to authenticate the controller with GitHub. You
can follow the instructions
[in the documentation](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/authenticating-to-the-github-api#authenticating-arc-with-a-github-app).
Afterwards note down these values:

- The `App ID`
- The `Installation ID`
- The `Private Key` file downloaded from the GitHub App and saved as `private-key.pem`
- The URL to your organization or repository, e.g. `https://github.com/kula-app`

To use these values from the Pulumi program, we can configure it as stack configuration:

```bash
$ pulumi config set github_app_id 1177490
$ pulumi config set github_app_installation_id 62595682
$ pulumi config set github_app_url https://github.com/kula-app
$ cat private-key.pem | pulumi config set --secret github_app_private_key
```

Afterwards your `Pulumi.dev.yaml` should look like this:

```yaml
encryptionsalt: v1:vR3zZ/4OiG8=:v1:+BDIo58GwUvObFa7:Zuj1xa...
config:
  ci-infra:github_app_id: '1177490'
  ci-infra:github_app_installation_id: '62595682'
  ci-infra:github_app_private_key:
    secure: v1:Zi8fo393B3sR3LlW:pV...
  ci-infra:github_app_url: https://github.com/kula-app
```

Before we can create a runner scale set, we need to deploy the controller. Replace the `index.ts` with the following
code to deploy the GitHub Actions Runner Controller:

```typescript
import * as k8s from '@pulumi/kubernetes'
import * as pulumi from '@pulumi/pulumi'

// Create the namespace where the runner scale set will be deployed
const namespace = new k8s.core.v1.Namespace('github-arc', {
  metadata: {
    name: 'github-arc',
  },
})
// Deploy the arc scale set controller which watches all the namespaces
new k8s.helm.v4.Chart('github-arc-scale-set-controller', {
  chart: 'oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller',
  version: '0.10.1',
  namespace: namespace.metadata.name,
  values: {
    replicaCount: 1,
    rbac: {
      create: true,
      serviceAccount: {
        create: true,
        name: 'github-arc-scale-set-controller-gha-rs-controller',
      },
    },
    // Security settings
    securityContext: {
      runAsNonRoot: true,
      runAsUser: 1000,
      readOnlyRootFilesystem: true,
      capabilities: {
        drop: ['ALL'],
      },
    },
    podSecurityContext: {
      fsGroup: 1000,
    },
  },
})
```

Deploy it using the following command:

```bash
$ pulumi up
Previewing update (dev):
     Type                                                               Name
     pulumi:pulumi:Stack                                                ci-infra-dev
 +   ├─ kubernetes:core/v1:Namespace                                    github-arc
 +   ├─ kubernetes:helm.sh/v4:Chart                                     github-arc-scale-set-controller
 +   │  ├─ kubernetes:rbac.authorization.k8s.io/v1:RoleBinding          github-arc-scale-set-controller:github-arc/github-arc-scal
 +   │  ├─ kubernetes:rbac.authorization.k8s.io/v1:ClusterRoleBinding   github-arc-scale-set-controller:github-arc-scale-set-contr
 +   │  ├─ kubernetes:core/v1:ServiceAccount                            github-arc-scale-set-controller:github-arc/github-arc-scal
 +   │  ├─ kubernetes:rbac.authorization.k8s.io/v1:Role                 github-arc-scale-set-controller:github-arc/github-arc-scal
 +   │  ├─ kubernetes:rbac.authorization.k8s.io/v1:ClusterRole          github-arc-scale-set-controller:github-arc-scale-set-contr
 +   │  ├─ kubernetes:apps/v1:Deployment                                github-arc-scale-set-controller:github-arc/github-arc-scal
 +   │  ├─ kubernetes:apiextensions.k8s.io/v1:CustomResourceDefinition  github-arc-scale-set-controller:ephemeralrunnersets.action
 +   │  ├─ kubernetes:apiextensions.k8s.io/v1:CustomResourceDefinition  github-arc-scale-set-controller:autoscalinglisteners.actio
 +   │  ├─ kubernetes:apiextensions.k8s.io/v1:CustomResourceDefinition  github-arc-scale-set-controller:ephemeralrunners.actions.g
 +   │  └─ kubernetes:apiextensions.k8s.io/v1:CustomResourceDefinition  github-arc-scale-set-controller:autoscalingrunnersets.acti
 -   └─ kubernetes:core/v1:Namespace                                    ci-infra

Resources:
    + 12 to create
    - 1 to delete
    13 changes. 1 unchanged

Updating (dev):
     Type                                                               Name
     pulumi:pulumi:Stack                                                ci-infra-dev
 +   ├─ kubernetes:core/v1:Namespace                                    github-arc
 +   ├─ kubernetes:helm.sh/v4:Chart                                     github-arc-scale-set-controller
 +   │  ├─ kubernetes:rbac.authorization.k8s.io/v1:ClusterRoleBinding   github-arc-scale-set-controller:github-arc-scale-set-contr
 +   │  ├─ kubernetes:rbac.authorization.k8s.io/v1:ClusterRole          github-arc-scale-set-controller:github-arc-scale-set-contr
 +   │  ├─ kubernetes:apps/v1:Deployment                                github-arc-scale-set-controller:github-arc/github-arc-scal
 +   │  ├─ kubernetes:rbac.authorization.k8s.io/v1:RoleBinding          github-arc-scale-set-controller:github-arc/github-arc-scal
 +   │  ├─ kubernetes:rbac.authorization.k8s.io/v1:Role                 github-arc-scale-set-controller:github-arc/github-arc-scal
 +   │  ├─ kubernetes:core/v1:ServiceAccount                            github-arc-scale-set-controller:github-arc/github-arc-scal
 +   │  ├─ kubernetes:apiextensions.k8s.io/v1:CustomResourceDefinition  github-arc-scale-set-controller:ephemeralrunners.actions.g
 +   │  ├─ kubernetes:apiextensions.k8s.io/v1:CustomResourceDefinition  github-arc-scale-set-controller:autoscalinglisteners.actio
 +   │  ├─ kubernetes:apiextensions.k8s.io/v1:CustomResourceDefinition  github-arc-scale-set-controller:ephemeralrunnersets.action
 +   │  └─ kubernetes:apiextensions.k8s.io/v1:CustomResourceDefinition  github-arc-scale-set-controller:autoscalingrunnersets.acti
 -   └─ kubernetes:core/v1:Namespace                                    ci-infra

Resources:
    + 12 created
    - 1 deleted
    13 changes. 1 unchanged

Duration: 28s
```

Now we can create a runner scale set. Append the following code to the `index.ts` file:

```typescript
// Get the GitHub apps from the config
const config = new pulumi.Config()
const githubAppId = config.requireNumber('github_app_id')
const githubAppInstallationId = config.requireNumber('github_app_installation_id')
const githubAppPrivateKey = config.require('github_app_private_key')
const githubAppUrl = config.require('github_app_url')

// As the ARC controller supports multiple installations (i.e. multiple GitHub organizations), we need to create a new namespace for each installation
const installationNamespace = new k8s.core.v1.Namespace(`github-arc-${githubAppId}-${githubAppInstallationId}`, {
  metadata: {
    name: `github-arc-${githubAppId}-${githubAppInstallationId}`,
  },
})

// Create the runner scale set in the installation namespace
new k8s.helm.v4.Chart(`github-arc-scale-set-${githubAppId}-${githubAppInstallationId}`, {
  chart: 'oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set',
  version: '0.10.1',
  namespace: installationNamespace.metadata.name,
  values: {
    githubConfigUrl: githubAppUrl,
    githubConfigSecret: {
      github_app_id: githubAppId.toString(),
      github_app_installation_id: githubAppInstallationId.toString(),
      github_app_private_key: githubAppPrivateKey,
    },
    maxRunners: 5,
    minRunners: 1,

    runnerGroup: 'default',
    // The name of the runner scale set must be unique across all runner scale sets
    // You can also use a custom naming scheme.
    runnerScaleSetName: `github-arc-scale-set-${githubAppId}-${githubAppInstallationId}`,

    // Configure the runner container to use the Kubernetes mode
    containerMode: {
      type: 'kubernetes',
      kubernetesModeWorkVolumeClaim: {
        accessModes: ['ReadWriteOnce'],
        // We are deploying the runner in a single node cluster, so we can use the local-path storage class
        storageClassName: 'local-path',
        resources: {
          requests: {
            storage: '16Gi',
          },
        },
      },
    },
    template: {
      spec: {
        initContainers: [
          // Initialize the permissions for the runner working directory
          // This is needed to avoid permission issues when the runner is deployed in a Kubernetes cluster
          {
            name: 'init-permissions',
            image: 'busybox',
            command: ['sh', '-c', 'chown -Rv 1001:123 /home/runner/_work'],
            volumeMounts: [
              {
                name: 'work',
                mountPath: '/home/runner/_work',
              },
            ],
            securityContext: {
              runAsUser: 0,
            },
          },
        ],
        containers: [
          // Deploy the runner container
          {
            name: 'runner',
            image: 'ghcr.io/actions/actions-runner:latest',
            command: ['/home/runner/run.sh'],
            env: [
              {
                name: 'ACTIONS_RUNNER_CONTAINER_HOOKS',
                value: '/home/runner/k8s/index.js',
              },
              {
                name: 'ACTIONS_RUNNER_POD_NAME',
                valueFrom: {
                  fieldRef: {
                    fieldPath: 'metadata.name',
                  },
                },
              },
              {
                name: 'ACTIONS_RUNNER_REQUIRE_JOB_CONTAINER',
                value: 'true',
              },
            ],
            volumeMounts: [
              {
                name: 'work',
                mountPath: '/home/runner/_work',
              },
            ],
            // Runner container security context
            securityContext: {
              runAsNonRoot: true,
              runAsUser: 1001,
              capabilities: {
                drop: ['ALL'],
              },
            },
          },
        ],
        // Pod security context to set proper permissions
        securityContext: {
          fsGroup: 1001,
        },
      },
    },
    controllerServiceAccount: {
      namespace: namespace.metadata.name,
      name: 'github-arc-scale-set-controller-gha-rs-controller',
    },
    rbac: {
      create: true,
      serviceAccount: {
        create: true,
      },
    },
  },
})
```

Once again, deploy the changes using the following command:

```bash
$ pulumi up -y
Previewing update (dev):
     Type                                                               Name
     pulumi:pulumi:Stack                                                ci-infra-dev
 +   ├─ kubernetes:core/v1:Namespace                                    github-arc-1177490-62595682
 +   └─ kubernetes:helm.sh/v4:Chart                                     github-arc-scale-set-1177490-62595682
 +      ├─ kubernetes:actions.github.com/v1alpha1:AutoscalingRunnerSet  github-arc-scale-set-1177490-62595682:github-arc-1
 +      ├─ kubernetes:rbac.authorization.k8s.io/v1:RoleBinding          github-arc-scale-set-1177490-62595682:github-arc-1
 +      ├─ kubernetes:rbac.authorization.k8s.io/v1:RoleBinding          github-arc-scale-set-1177490-62595682:github-arc-1
 +      ├─ kubernetes:core/v1:ServiceAccount                            github-arc-scale-set-1177490-62595682:github-arc-1
 +      ├─ kubernetes:core/v1:Secret                                    github-arc-scale-set-1177490-62595682:github-arc-1
 +      ├─ kubernetes:rbac.authorization.k8s.io/v1:Role                 github-arc-scale-set-1177490-62595682:github-arc-1
 +      └─ kubernetes:rbac.authorization.k8s.io/v1:Role                 github-arc-scale-set-1177490-62595682:github-arc-1

Resources:
    + 9 to create
    13 unchanged

Updating (dev):
     Type                                                               Name
     pulumi:pulumi:Stack                                                ci-infra-dev
 +   ├─ kubernetes:core/v1:Namespace                                    github-arc-1177490-62595682
 +   └─ kubernetes:helm.sh/v4:Chart                                     github-arc-scale-set-1177490-62595682
 +      ├─ kubernetes:rbac.authorization.k8s.io/v1:RoleBinding          github-arc-scale-set-1177490-62595682:github-arc-1
 +      ├─ kubernetes:core/v1:Secret                                    github-arc-scale-set-1177490-62595682:github-arc-1
 +      ├─ kubernetes:rbac.authorization.k8s.io/v1:Role                 github-arc-scale-set-1177490-62595682:github-arc-1
 +      ├─ kubernetes:rbac.authorization.k8s.io/v1:RoleBinding          github-arc-scale-set-1177490-62595682:github-arc-1
 +      ├─ kubernetes:rbac.authorization.k8s.io/v1:Role                 github-arc-scale-set-1177490-62595682:github-arc-1
 +      ├─ kubernetes:actions.github.com/v1alpha1:AutoscalingRunnerSet  github-arc-scale-set-1177490-62595682:github-arc-1
 +      └─ kubernetes:core/v1:ServiceAccount                            github-arc-scale-set-1177490-62595682:github-arc-1

Resources:
    + 9 created
    13 unchanged

Duration: 23s

```

After the deployment is finished, you can see the controller, a listener and a runner scale set pod in the cluster:

```bash
$ kubectl get pods -A
NAMESPACE                     NAME                                                              READY   STATUS    RESTARTS   AGE
github-arc-1177490-62595682   github-arc-scale-set-1177490-62595682-bbkzv-runner-k22mv          1/1     Running   0          92s
github-arc                    github-arc-scale-set-1177490-62595682-8f775bbd-listener           1/1     Running   0          94s
github-arc                    github-arc-scale-set-controller-gha-rs-controller-88fc5847cxgx2   1/1     Running   0          4m36s
kube-system                   coredns-ccb96694c-mkt6n                                           1/1     Running   0          138m
kube-system                   local-path-provisioner-5b5f758bcf-4r4zv                           1/1     Running   0          138m
kube-system                   metrics-server-7bf7d58749-fr7k9                                   1/1     Running   0          138m
```

Furthermore, you should see the runner scale set in the GitHub Actions settings of your repository, e.g.
https://github.com/organizations/kula-app/settings/actions/runners:

![GitHub Actions Runner Scale Set](./assets/XXXX-XX-XX-k3s-powered-github-actions-runner/github-actions-runner-scale-set-default.png)

## Running a workflow on the runner

To test the runner, we can create a simple workflow that prints "Hello, world!" to the console. We will execute it in a
matrix job to spin up multiple runners in parallel.

```yaml
name: Hello World

on:
  workflow_dispatch:
  push:
    branches:
      - main

jobs:
  hello-world:
    strategy:
      matrix:
        runner: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    runs-on: [github-arc-scale-set-1177490-62595682] # The `runs-on` field must match the name of the runner scale set
    container: alpine:latest #
    steps:
      - name: Say Hello
        run: echo "Hello, world! from runner ${{ matrix.runner }}"
      - name: Run a longer task
        run: sleep 30
```

After pushing the changes to the repository, you should see the workflow being executed on the runner scale set:

![GitHub Actions Runner Scale Set](./assets/XXXX-XX-XX-k3s-powered-github-actions-runner/github-actions-runner-scale-set-max.png)

As we start 10 jobs in parallel, we should see the ARC controller to spin up the maximum number of 5 runners. In
addition to the runner, the workflow is also running in a separate pod, as we can see in the following output:

```bash
$ kubectl get pods -n github-arc-1177490-62595682
NAME                                                              READY   STATUS    RESTARTS   AGE
github-arc-scale-set-1177490-62595682-bbkzv-runner-8ll-workflow   1/1     Running   0          26s
github-arc-scale-set-1177490-62595682-bbkzv-runner-8ll52          1/1     Running   0          74s
github-arc-scale-set-1177490-62595682-bbkzv-runner-d78rg          1/1     Running   0          28s
github-arc-scale-set-1177490-62595682-bbkzv-runner-frdj2          1/1     Running   0          27s
github-arc-scale-set-1177490-62595682-bbkzv-runner-gdg-workflow   1/1     Running   0          9s
github-arc-scale-set-1177490-62595682-bbkzv-runner-gdgk2          1/1     Running   0          27s
github-arc-scale-set-1177490-62595682-bbkzv-runner-lvw-workflow   1/1     Running   0          23s
github-arc-scale-set-1177490-62595682-bbkzv-runner-lvwj9          1/1     Running   0          74s
```

## Conclusion

In this post, we have deployed a GitHub Actions runner scale set on a K3s cluster using Pulumi. We have also created a
simple workflow that prints "Hello, world!" to the console and executed it on the runner scale set.
