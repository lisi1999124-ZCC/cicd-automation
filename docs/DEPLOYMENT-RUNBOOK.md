# =============================================================================
# Deployment Runbook
# =============================================================================

## Table of Contents
1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Standard Deployment Process](#standard-deployment-process)
3. [Rollback Procedures](#rollback-procedures)
4. [Emergency Response](#emergency-response)
5. [Post-Deployment Verification](#post-deployment-verification)

---

## Pre-Deployment Checklist

Before initiating a deployment, ensure:

- [ ] All CI/CD pipeline stages have passed
- [ ] Code review approved by at least one team member
- [ ] Security scan completed with no critical vulnerabilities
- [ ] Test coverage meets minimum threshold (80%)
- [ ] Database migrations are backward compatible
- [ ] Feature flags configured if needed
- [ ] Staging deployment verified
- [ ] Monitoring dashboards accessible
- [ ] On-call engineer notified

---

## Standard Deployment Process

### Automated Deployment (Recommended)

1. **Merge to Main Branch**
   ```bash
   git checkout main
   git pull origin main
   git merge feature/your-feature
   git push origin main
   ```

2. **Pipeline Triggers**
   - GitHub Actions automatically:
     - Runs security scans
     - Builds Docker image
     - Deploys to Staging
     - Runs smoke tests
     - Requires manual approval for Production

3. **Production Approval**
   - Go to GitHub Actions workflow run
   - Click "Review deployments"
   - Select "Production" environment
   - Click "Approve and deploy"

### Manual Deployment (Emergency Only)

If automated pipeline is unavailable:

```bash
# 1. Build and tag image
docker build -t app:$(git rev-parse --short HEAD) .

# 2. Push to registry
docker push app:$(git rev-parse --short HEAD)

# 3. Deploy to Kubernetes
kubectl set image deployment/app \
  app=app:$(git rev-parse --short HEAD) \
  -n production

# 4. Monitor rollout
kubectl rollout status deployment/app -n production --timeout=300s
```

---

## Rollback Procedures

### Automatic Rollback
Pipeline automatically rolls back if health checks fail.

### Manual Rollback (One-Command)

```bash
# Rollback to previous version
kubectl rollout undo deployment/app -n production

# Rollback to specific revision
kubectl rollout undo deployment/app -n production --to-revision=2

# Verify rollback
kubectl rollout status deployment/app -n production
```

### Complete Rollback Process

1. **Check deployment history**
   ```bash
   kubectl rollout history deployment/app -n production
   ```

2. **Identify target revision**
   ```
   deployment.apps/app
   REVISION  CHANGE-CAUSE
   1         <none>
   2         kubectl set image deployment/app app=app:v1.0.1
   3         kubectl set image deployment/app app=app:v1.0.2  <-- Current (problematic)
   ```

3. **Rollback**
   ```bash
   kubectl rollout undo deployment/app -n production --to-revision=2
   ```

4. **Verify**
   ```bash
   # Check pods are healthy
   kubectl get pods -n production -l app=app
   
   # Check logs
   kubectl logs -n production -l app=app --tail=100
   
   # Test endpoint
   curl https://example.com/health
   ```

---

## Emergency Response

### Critical Alert Response

1. **Acknowledge Alert** (PagerDuty/Slack)

2. **Assess Impact**
   ```bash
   # Check pod status
   kubectl get pods -n production
   
   # Check recent events
   kubectl get events -n production --sort-by='.lastTimestamp'
   
   # Check pod logs
   kubectl logs -n production -l app=app --tail=500
   ```

3. **Immediate Actions**
   ```bash
   # If pods crashing: Check resource limits
   kubectl describe pod <pod-name> -n production
   
   # If OOMKilled: Scale up resources
   kubectl patch hpa app-hpa -n production -p '{"spec":{"maxReplicas":15}}'
   
   # If network issues: Check ingress
   kubectl describe ingress app-ingress -n production
   ```

4. **Rollback if Needed**
   ```bash
   kubectl rollout undo deployment/app -n production
   ```

5. **Notify Stakeholders**
   - Update Slack channel #incidents
   - Send status page update if applicable
   - Document incident timeline

---

## Post-Deployment Verification

### 1. Health Check
```bash
# HTTP health endpoint
curl -f https://example.com/health

# Expected response: {"status":"ok","version":"1.2.3"}
```

### 2. Smoke Tests
```bash
npm run test:smoke -- --env=production
```

### 3. Verify Metrics
- [ ] Error rate < 1%
- [ ] P99 latency < 500ms
- [ ] Success rate > 99.5%

### 4. Check Dashboards
- [ ] Grafana: Application metrics normal
- [ ] Grafana: No spike in error rate
- [ ] Grafana: Request rate stable

### 5. Verify Logs
```bash
# Check for errors
kubectl logs -n production -l app=app --since=1h | grep -i error

# Check for warnings (normal to see some)
kubectl logs -n production -l app=app --since=1h | grep -i warn
```

### 6. Database Verification
```bash
# Check for pending migrations
kubectl exec -it deployment/app -n production -- npm run migrate:status

# Run pending migrations if any
kubectl exec -it deployment/app -n production -- npm run migrate
```

---

## Monitoring Dashboards

| Dashboard | URL | Purpose |
|-----------|-----|---------|
| Grafana | https://grafana.example.com | Main metrics dashboard |
| Prometheus | https://prometheus.example.com | Raw metrics & alerts |
| Kibana | https://kibana.example.com | Application logs |
| Jaeger | https://jaeger.example.com | Distributed tracing |

---

## Useful Commands

```bash
# Watch pods in real-time
kubectl get pods -n production -w

# Port-forward for local debugging
kubectl port-forward -n production svc/app-svc 8080:80

# Get detailed pod info
kubectl describe pod <pod-name> -n production

# Execute shell in container
kubectl exec -it <pod-name> -n production -- sh

# View resource usage
kubectl top pods -n production
kubectl top nodes

# Check HPA status
kubectl get hpa -n production
kubectl describe hpa app-hpa -n production

# Scale manually (emergency)
kubectl scale deployment app-green -n production --replicas=5
```
