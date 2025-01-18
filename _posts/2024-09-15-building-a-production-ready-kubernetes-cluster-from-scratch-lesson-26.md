---
layout: course-lesson
title: Deploying Sample Applications (L26)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-26
---

In this lesson, we will deploy a WordPress application and a MariaDB database to
your Kubernetes cluster. This will help test your cluster's readiness to handle
real-world workloads, including web applications that require persistent
storage, networking, and service integration.

This is the twenty-sixth lesson in the series on building a production-ready
Kubernetes cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-25)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## Step 1: Deploy a MariaDB Database for WordPress

1. **Create a Persistent Volume Claim (PVC) for MariaDB:**

   Save the following YAML as `mariadb-pvc.yaml`:

   ```yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: mariadb-pv-claim
   spec:
     accessModes:
       - ReadWriteOnce
     resources:
       requests:
         storage: 5Gi
     storageClassName: longhorn # Use the Longhorn storage class for persistence
   ```

   Apply the PVC:

   ```bash
   kubectl apply -f mariadb-pvc.yaml
   ```

2. **Deploy the MariaDB StatefulSet:**

   Save the following YAML as `mariadb-deployment.yaml`:

   ```yaml
   apiVersion: apps/v1
   kind: StatefulSet
   metadata:
     name: mariadb
   spec:
     serviceName: 'mariadb'
     replicas: 1
     selector:
       matchLabels:
         app: mariadb
     template:
       metadata:
         labels:
           app: mariadb
       spec:
         containers:
           - name: mariadb
             image: mariadb:10.5
             env:
               - name: MYSQL_ROOT_PASSWORD
                 value: my-secret-pw
               - name: MYSQL_DATABASE
                 value: wordpress
               - name: MYSQL_USER
                 value: wpuser
               - name: MYSQL_PASSWORD
                 value: password123
             ports:
               - containerPort: 3306
                 name: mysql
             volumeMounts:
               - name: mariadb-persistent-storage
                 mountPath: /var/lib/mysql
     volumeClaimTemplates:
       - metadata:
           name: mariadb-persistent-storage
         spec:
           accessModes: ['ReadWriteOnce']
           storageClassName: longhorn
           resources:
             requests:
               storage: 5Gi
   ```

   Apply the StatefulSet:

   ```bash
   kubectl apply -f mariadb-deployment.yaml
   ```

3. **Verify the MariaDB Deployment:**

   Ensure the MariaDB pod is running and the PVC is bound:

   ```bash
   kubectl get pods -l app=mariadb
   kubectl get pvc
   ```

   The MariaDB pod should be in a "Running" state, and the PVC should be
   "Bound."

## Step 2: Deploy the WordPress Application

1. **Create a Deployment for WordPress:**

   Save the following YAML as `wordpress-deployment.yaml`:

   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: wordpress
   spec:
     replicas: 2
     selector:
       matchLabels:
         app: wordpress
     template:
       metadata:
         labels:
           app: wordpress
       spec:
         containers:
           - name: wordpress
             image: wordpress:latest
             env:
               - name: WORDPRESS_DB_HOST
                 value: mariadb
               - name: WORDPRESS_DB_USER
                 value: wpuser
               - name: WORDPRESS_DB_PASSWORD
                 value: password123
               - name: WORDPRESS_DB_NAME
                 value: wordpress
             ports:
               - containerPort: 80
   ```

   This deployment creates two replicas of the WordPress web application,
   connecting it to the MariaDB database.

2. **Apply the WordPress Deployment:**

   Deploy the WordPress application:

   ```bash
   kubectl apply -f wordpress-deployment.yaml
   ```

   Verify that the WordPress pods are running:

   ```bash
   kubectl get pods -l app=wordpress
   ```

   The WordPress pods should be in a "Running" state.

3. **Expose the WordPress Deployment:**

   Expose the WordPress service to make it accessible externally:

   ```bash
   kubectl expose deployment wordpress --type=NodePort --name=wordpress-service
   ```

   Retrieve the details of the exposed service:

   ```bash
   kubectl get svc wordpress-service
   ```

   Note the `NodePort` assigned to the WordPress service.

## Step 3: Access the WordPress Application

Open a web browser and navigate to `http://<node-ip>:<node-port>`, replacing
`<node-ip>` with the IP address of any cluster node and `<node-port>` with the
assigned NodePort. You should see the WordPress setup page.

- Complete the WordPress setup process by following the prompts to configure
  your new website.
- Test the functionality by creating posts, installing plugins, and checking
  that your changes are saved correctly.

## Step 4: Validate Application Functionality

1. **Test WordPress and MariaDB Connectivity:**

   Ensure that WordPress can communicate with the MariaDB database by checking
   the WordPress site functionality (e.g., creating and saving posts).

2. **Monitor Application Performance:**

   Use Grafana dashboards to monitor the performance of the WordPress and
   MariaDB deployments. Look for metrics like CPU and memory usage, response
   times, and network traffic.

## Step 5: Clean Up the Applications

After testing, clean up the deployments to free up resources:

```bash
kubectl delete deployment wordpress
kubectl delete svc wordpress-service
kubectl delete statefulset mariadb
kubectl delete pvc mariadb-pv-claim
```

## Lesson Conclusion

Congratulations! By deploying WordPress and MariaDB, you have tested your
cluster's ability to handle a real-world web application stack. In the next
lesson, we will simulate node failures and recovery scenarios to validate the
resilience of your Kubernetes cluster.

You have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-27).
