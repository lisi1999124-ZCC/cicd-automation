# =============================================================================
# Secrets Management - Reference Documentation
# =============================================================================

# Required GitHub Secrets to configure in Settings > Secrets and variables > Actions

## Container Registry
| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `GITHUB_TOKEN` | GitHub Packages authentication | (Auto-configured) |

## Cloud Provider (AWS/GCP/Azure)
| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key for deployment | `AKIA...` |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Key for deployment | `...` |
| `AWS_REGION` | Target AWS region | `us-east-1` |

## Kubernetes
| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `KUBE_CONFIG_STAGING` | Base64-encoded kubeconfig for staging | `LS0t...` |
| `KUBE_CONFIG_PRODUCTION` | Base64-encoded kubeconfig for production | `LS0t...` |

## Database
| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `DB_PASSWORD` | PostgreSQL password | `your-secure-password` |
| `DB_HOST` | Database host | `prod.db.internal:5432` |

## Monitoring & Alerting
| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `SLACK_WEBHOOK_URL` | Slack webhook for notifications | `https://hooks.slack.com/...` |
| `PAGERDUTY_KEY` | PagerDuty integration key | `...` |
| `GRAFANA_PASSWORD` | Grafana admin password | `secure-password` |

## Third-Party Services
| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `SENTRY_DSN` | Sentry error tracking | `https://...@sentry.io/...` |
| `SENDGRID_API_KEY` | Email service API key | `SG...` |
| `CODECOV_TOKEN` | Codecov upload token | `...` |

## Testing
| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `SMOKE_TEST_TOKEN` | API token for smoke tests | `test-token` |

---

# How to Create Kubeconfig Secrets

## 1. Get kubeconfig from your cluster
```bash
aws eks update-kubeconfig --name your-cluster-name --region us-east-1
```

## 2. Encode the kubeconfig
```bash
cat ~/.kube/config | base64 | tr -d '\n'
```

## 3. Add as GitHub Secret
Go to Settings > Secrets and variables > Actions > New repository secret

Name: `KUBE_CONFIG_STAGING`
Value: [paste the base64 encoded kubeconfig]

---

# How to Create AWS Credentials

## 1. Create an IAM user for CI/CD
```bash
aws iam create-user --user-name github-actions
```

## 2. Attach permissions policy
```bash
aws iam attach-user-policy \
  --user-name github-actions \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
```

## 3. Create access key
```bash
aws iam create-access-key --user-name github-actions
```

## 4. Add credentials to GitHub
AWS_ACCESS_KEY_ID: [Your Access Key ID]
AWS_SECRET_ACCESS_KEY: [Your Secret Access Key]

---

# Secret Rotation Policy

- Rotate all secrets quarterly
- Immediately rotate if a breach is suspected
- Use AWS Secrets Manager for automatic rotation where possible
- Review access logs monthly
