---
layout: guide-lesson.liquid
title: Traffic Switching and DNS Cutover

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 4
guide_lesson_id: 21
guide_lesson_abstract: >
  Perform the DNS cutover to switch traffic from Cluster A to Cluster B with minimal disruption.
guide_lesson_conclusion: >
  Traffic has been successfully switched to Cluster B, completing the workload migration phase.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-21.md
---

The DNS cutover is the critical moment when production traffic starts flowing to Cluster B. This lesson covers how
to perform a smooth traffic switch with minimal user impact.

{% include guide-overview-link.liquid.html %}

## Pre-Cutover Verification

Before switching DNS, verify Cluster B is fully ready:

### Verify All Workloads

```bash
# Run the verification script
/root/verify-workloads.sh

# Check for any issues
kubectl get pods -A | grep -v Running | grep -v Completed

# All pods should be Running
```

### Verify Ingress Through Load Balancer

```bash
# Get Load Balancer IP
LB_IP=$(hcloud load-balancer describe k8s-ingress -o format='{{.PublicNet.IPv4.IP}}')

# Test each application
for host in $(kubectl get ingress -A -o jsonpath='{range .items[*]}{.spec.rules[*].host}{"\n"}{end}'); do
    echo -n "$host: "
    curl -s -o /dev/null -w "%{http_code}" -H "Host: $host" http://${LB_IP}/ --max-time 5
    echo ""
done
```

### Test Application Functionality

```bash
# Perform application-specific tests through the Load Balancer
# Example for an API:
curl -H "Host: api.example.com" http://${LB_IP}/health

# Example for a web app:
curl -s -H "Host: www.example.com" http://${LB_IP}/ | grep -o "<title>.*</title>"
```

### Verify TLS Certificates

If using cert-manager or static certificates:

```bash
# Check certificate status
kubectl get certificates -A

# Verify secrets exist
kubectl get secrets -A | grep tls

# Test HTTPS
curl -k -H "Host: www.example.com" https://${LB_IP}/ --max-time 5
```

## DNS Cutover Strategy

### Option 1: Direct Switch (Simplest)

For low-traffic applications or when brief interruption is acceptable:

```bash
# 1. Update DNS records to point to Cluster B Load Balancer IP
# In your DNS provider:
# www.example.com  A    <Cluster-B-LB-IP>
# api.example.com  A    <Cluster-B-LB-IP>

# 2. Wait for DNS propagation
# Time depends on TTL (that's why we lowered it earlier)
```

### Option 2: Weighted DNS (Gradual)

For critical applications, use weighted DNS to gradually shift traffic:

```bash
# Phase 1: 10% to Cluster B
# www.example.com  A  10  <Cluster-B-LB-IP>
# www.example.com  A  90  <Cluster-A-IP>

# Phase 2: 50% to Cluster B (after verification)
# www.example.com  A  50  <Cluster-B-LB-IP>
# www.example.com  A  50  <Cluster-A-IP>

# Phase 3: 100% to Cluster B
# www.example.com  A  100  <Cluster-B-LB-IP>
# Remove Cluster A record
```

### Option 3: Using Cloudflare (or Similar)

If using Cloudflare:

```bash
# Use Load Balancing feature for gradual migration
# Configure health checks for both origins
# Adjust traffic weights through the dashboard
```

## Pre-Cutover Checklist

Complete before switching DNS:

- [ ] All pods running on Cluster B
- [ ] All services have endpoints
- [ ] Ingress responds correctly through Load Balancer
- [ ] TLS certificates working
- [ ] Application functionality verified
- [ ] Database connections working
- [ ] External integrations tested
- [ ] Monitoring and alerting configured on Cluster B
- [ ] Rollback procedure documented

## Execute DNS Cutover

### Step 1: Document Current DNS

```bash
# Record current DNS settings
for domain in www.example.com api.example.com; do
    echo "=== $domain ==="
    dig +short $domain
done > /root/dns-before-cutover.txt

cat /root/dns-before-cutover.txt
```

### Step 2: Update DNS Records

Update your DNS provider to point to the Cluster B Load Balancer IP.

**Example using common DNS providers:**

#### Cloudflare API

```bash
ZONE_ID="your-zone-id"
RECORD_ID="your-record-id"
CF_TOKEN="your-api-token"

curl -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
  -H "Authorization: Bearer ${CF_TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{"type":"A","name":"www","content":"'${LB_IP}'","ttl":300,"proxied":true}'
```

#### AWS Route 53

```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "www.example.com",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "'${LB_IP}'"}]
      }
    }]
  }'
```

#### Hetzner DNS

```bash
hcloud dns record update <record-id> --value ${LB_IP}
```

### Step 3: Verify DNS Propagation

```bash
# Check DNS resolution
for domain in www.example.com api.example.com; do
    echo "=== $domain ==="
    dig +short $domain

    # Check from multiple resolvers
    dig +short $domain @8.8.8.8
    dig +short $domain @1.1.1.1
done

# Monitor propagation
watch -n 30 'dig +short www.example.com'
```

### Step 4: Monitor Traffic

```bash
# Watch Cluster B ingress logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik -f

# Watch pod resource usage
watch kubectl top pods -A

# Monitor Cluster A (should show decreasing traffic)
# On Cluster A:
# kubectl logs -n kube-system -l app=traefik -f
```

## Post-Cutover Monitoring

### Immediate Monitoring (First Hour)

```bash
# Create monitoring script
cat <<'EOF' > /root/post-cutover-monitor.sh
#!/bin/bash
while true; do
    echo "=== $(date) ==="

    # Check pods
    not_running=$(kubectl get pods -A --no-headers | grep -v Running | grep -v Completed | wc -l)
    echo "Non-running pods: $not_running"

    # Check ingress health
    for host in www.example.com api.example.com; do
        status=$(curl -s -o /dev/null -w "%{http_code}" https://$host/ --max-time 5 2>/dev/null)
        echo "$host: $status"
    done

    # Check error rate in logs (last minute)
    errors=$(kubectl logs -n traefik -l app.kubernetes.io/name=traefik --since=1m 2>/dev/null | grep -c "500\|502\|503\|504")
    echo "5xx errors: $errors"

    echo ""
    sleep 60
done
EOF

chmod +x /root/post-cutover-monitor.sh
/root/post-cutover-monitor.sh
```

### Key Metrics to Watch

- HTTP response codes (watch for 5xx errors)
- Response latency
- Pod restarts
- CPU and memory usage
- Database connections
- Error logs

## Rollback Procedure

If issues arise, rollback to Cluster A:

### Quick Rollback (DNS)

```bash
# Immediately update DNS to point back to Cluster A
# This is why we kept Cluster A running!

# Update DNS to Cluster A IP
# www.example.com  A  <Cluster-A-IP>
```

### Verify Rollback

```bash
# Check DNS is pointing to Cluster A
dig +short www.example.com

# Verify Cluster A is handling traffic
# On Cluster A:
kubectl logs -n kube-system -l app=traefik -f
```

## Traffic Verification

### Confirm No Traffic on Cluster A

After DNS propagation (wait at least 2x TTL):

```bash
# On Cluster A, check for traffic
kubectl logs -n kube-system -l app=traefik --since=10m | grep -c "HTTP"

# Should show minimal or no new requests
```

### Confirm All Traffic on Cluster B

```bash
# On Cluster B
kubectl logs -n traefik -l app.kubernetes.io/name=traefik --since=10m | wc -l

# Should show active traffic
```

## Document the Cutover

```bash
cat <<EOF >> /root/migration-log.txt
=== DNS Cutover Complete ===
Timestamp: $(date)
Load Balancer IP: ${LB_IP}
Domains migrated:
$(kubectl get ingress -A -o jsonpath='{range .items[*]}{.spec.rules[*].host}{"\n"}{end}')

DNS propagation verified: YES
Traffic flowing to Cluster B: YES
Cluster A still available for rollback: YES
EOF
```

## Post-Cutover Tasks

### Keep Cluster A Available

Don't decommission Cluster A immediately:

```bash
# Keep Cluster A running but idle
# This provides rollback capability

# On Cluster A, scale down non-essential workloads to save resources
kubectl scale deployment --all --replicas=0 -n <namespace>
```

### Monitor for 24-48 Hours

- Watch error rates
- Monitor response times
- Check for data consistency issues
- Review application logs

### Update Documentation

- Update runbooks with new cluster details
- Update monitoring dashboards
- Update CI/CD pipelines
- Notify stakeholders

## Cutover Checklist

- [ ] Pre-cutover verification complete
- [ ] DNS records updated
- [ ] DNS propagation confirmed
- [ ] Traffic flowing to Cluster B
- [ ] No 5xx errors
- [ ] Application functionality verified
- [ ] Monitoring active
- [ ] Cluster A available for rollback
- [ ] Stakeholders notified
- [ ] Documentation updated

## Summary

Traffic is now flowing to Cluster B. The key points:

1. **Keep Cluster A running** for at least 24-48 hours as a rollback option
2. **Monitor closely** for the first few hours
3. **Don't rush** - verify everything is working before proceeding

In the next section, we'll decommission Cluster A and add Node 1 as a worker to complete the migration.
