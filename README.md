# Application CI/CD Pipeline

Automated deployment pipeline for production workloads with security scanning, testing, and monitoring.

## Overview

This project implements a complete CI/CD pipeline with the following features:

- **Security First**: Trivy vulnerability scanning, dependency audit, SAST
- **Comprehensive Testing**: Unit tests, integration tests, smoke tests
- **Zero-Downtime Deployment**: Blue-green deployment strategy
- **Full Observability**: Prometheus metrics, Grafana dashboards, alerting
- **Infrastructure as Code**: Terraform for AWS infrastructure

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        CI/CD Pipeline                           │
├─────────────────────────────────────────────────────────────────┤
│  Source → Security → Build → Test → Push → Stage → Approve → Prod
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Configure Secrets

Set up required GitHub secrets:

```bash
# Kubernetes configs (base64 encoded)
KUBE_CONFIG_STAGING=<staging-kubeconfig>
KUBE_CONFIG_PRODUCTION=<production-kubeconfig>

# Cloud credentials
AWS_ACCESS_KEY_ID=<key>
AWS_SECRET_ACCESS_KEY=<secret>

# Notifications
SLACK_WEBHOOK_URL=https://hooks.slack.com/...
```

See [docs/SECRETS-MANAGEMENT.md](docs/SECRETS-MANAGEMENT.md) for full list.

### 2. Deploy Infrastructure

```bash
cd infrastructure/terraform
terraform init
terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
```

### 3. Push Code

```bash
git checkout -b feature/your-feature
# Make changes
git push origin feature/your-feature
# Create PR
```

Pipeline will automatically:
- Run security scans
- Build and push Docker image
- Deploy to staging
- Run smoke tests

### 4. Deploy to Production

1. Go to GitHub Actions
2. Find the workflow run
3. Click "Review deployments"
4. Approve production deployment

## Directory Structure

```
.
├── .github/
│   ├── workflows/           # GitHub Actions pipelines
│   └── environments/        # Environment configurations
├── k8s/                     # Kubernetes manifests
│   ├── deployment.yaml      # Application deployment
│   ├── service.yaml         # Service definitions
│   ├── ingress.yaml         # Ingress rules
│   └── configmap-secret.yaml # ConfigMaps & Secrets
├── monitoring/
│   └── prometheus/          # Monitoring configuration
│       ├── prometheus.yml   # Prometheus config
│       ├── rules/           # Alert rules
│       └── alertmanager.yml # Alert routing
├── infrastructure/
│   └── terraform/           # Infrastructure as Code
├── docker-compose*.yml      # Local development
├── Dockerfile               # Multi-stage Docker build
└── scripts/
    └── deploy.sh           # Deployment helper script
```

## Deployment Strategies

### Blue-Green Deployment

Traffic switches between green and blue environments:

```bash
# Deploy to green
kubectl set image deployment/app-green app=app:v2.0.0

# Run validation...

# Switch traffic
kubectl patch service app-svc -p '{"spec":{"selector":{"slot":"green"}}}'
```

### Canary Deployment

Gradually shift traffic:

```yaml
# nginx ingress annotation
nginx.ingress.kubernetes.io/canary: "true"
nginx.ingress.kubernetes.io/canary-weight: "5"  # 5% to canary
```

## Rollback

```bash
# One-command rollback
kubectl rollout undo deployment/app -n production

# Rollback to specific revision
kubectl rollout undo deployment/app -n production --to-revision=3
```

## Monitoring

| Dashboard | Purpose |
|-----------|---------|
| Grafana | Metrics visualization |
| Prometheus | Metrics collection |
| Kibana | Log aggregation |
| Jaeger | Distributed tracing |

## Troubleshooting

### Deployment Stuck

```bash
# Check pod status
kubectl get pods -n production

# View events
kubectl describe deployment app -n production

# Check pod logs
kubectl logs -l app=app -n production --tail=100
```

### High Error Rate

1. Check Prometheus alerts
2. View application logs
3. Verify database connectivity
4. Check resource limits

## Contributing

1. Create feature branch from `develop`
2. Make changes with tests
3. Open PR to `develop`
4. After approval, merge to `main`
5. Pipeline deploys to production

## License

MIT
