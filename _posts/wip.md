to allow port-forwarding allow incoming 6443:

## Making accessible via port-forward

Allow traffic from local network to port 6443:

```bash
sudo ufw allow from 10.0.0.0/24 to any port 6443 proto tcp
```

## Add the router ip to the Kubernetes API certificate

```bash
sudo kubeadm init phase upload-certs --upload-certs
```


## Setup nginx-controller with static ip

Yes, you can extend this setup to include the NGINX Ingress Controller by adding another frontend and backend configuration in HAProxy to handle traffic for the Ingress Controller. Here’s how you can do it:

1. Decide on a Static Port

Choose a static port on your router for forwarding to the NGINX Ingress Controller. Common choices are:
	-	HTTP traffic: Port 80
	-	HTTPS traffic: Port 443

2. Update Your HAProxy Configuration

Add new frontend and backend sections for the NGINX Ingress Controller in your haproxy.cfg. Example:

# NGINX Ingress Controller Frontend

```conf
frontend nginx-ingress
    mode tcp
    bind 10.1.233.1:80
    bind 10.1.233.1:443
    default_backend ingress-backend
    option tcplog
```

# NGINX Ingress Controller Backend

```conf
backend ingress-backend
    mode tcp
    balance roundrobin
    option tcp-check
    default-server inter 3s fall 3 rise 2
    server worker-1 10.1.1.4:80 check
    server worker-2 10.1.1.5:80 check
    server worker-3 10.1.1.6:80 check
```

Here:
	-	frontend nginx-ingress listens on ports 80 and 443.
	-	backend ingress-backend load balances requests to the NGINX Ingress Controller pods running on your worker nodes.

3. Configure Port Forwarding in Your Router
	-	Forward port 80 (HTTP) and 443 (HTTPS) on your router to the VIP 10.1.233.1.
	-	Example:
	-	External Port 80 → Internal Port 80 → IP 10.1.233.1
	-	External Port 443 → Internal Port 443 → IP 10.1.233.1

4. Deploy NGINX Ingress Controller

Ensure the NGINX Ingress Controller is deployed in your Kubernetes cluster:

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

Verify that the NGINX Ingress Controller is running:

kubectl get pods -n ingress-nginx

5. Expose the NGINX Ingress Controller Service

The NGINX Ingress Controller Service should use a NodePort or LoadBalancer to expose ports 80 and 443. Modify the Service to use NodePort:

apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
spec:
  type: NodePort
  ports:
    - name: http
      port: 80
      targetPort: 80
      nodePort: 30080
    - name: https
      port: 443
      targetPort: 443
      nodePort: 30443
  selector:
    app.kubernetes.io/name: ingress-nginx

Save this as ingress-service.yaml and apply it:

kubectl apply -f ingress-service.yaml

Now, your NGINX Ingress Controller will listen on ports 30080 (HTTP) and 30443 (HTTPS) on each node.

6. Test the Setup
	•	Restart HAProxy to apply the new configuration:

sudo systemctl restart haproxy


	•	Verify that requests to the VIP (10.1.233.1) on ports 80 and 443 are being forwarded to the NGINX Ingress Controller.

7. Security Considerations
	•	Ensure you have SSL/TLS certificates set up for HTTPS traffic.
	•	Use tools like iptables or Kubernetes NetworkPolicy to restrict access to the Ingress Controller.

This setup ensures that the NGINX Ingress Controller is reachable via the VIP (10.1.233.1) on static ports (80 and 443) for external traffic.
