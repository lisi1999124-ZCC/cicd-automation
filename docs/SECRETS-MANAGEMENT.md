# =============================================================================
# 密钥管理 - 参考文档
# =============================================================================

# 需要在 Settings > Secrets and variables > Actions 中配置的 GitHub Secrets

## 容器镜像仓库
| 密钥名称 | 说明 | 示例值 |
|----------|------|--------|
| `GITHUB_TOKEN` | GitHub Packages 认证 | （自动配置） |

## 云服务商（AWS/GCP/Azure）
| 密钥名称 | 说明 | 示例值 |
|----------|------|--------|
| `AWS_ACCESS_KEY_ID` | AWS 访问密钥 ID | `AKIA...` |
| `AWS_SECRET_ACCESS_KEY` | AWS 秘密访问密钥 | `...` |
| `AWS_REGION` | 目标 AWS 区域 | `us-east-1` |

## Kubernetes
| 密钥名称 | 说明 | 示例值 |
|----------|------|--------|
| `KUBE_CONFIG_STAGING` | 预发布环境 kubeconfig（Base64 编码） | `LS0t...` |
| `KUBE_CONFIG_PRODUCTION` | 生产环境 kubeconfig（Base64 编码） | `LS0t...` |

## 数据库
| 密钥名称 | 说明 | 示例值 |
|----------|------|--------|
| `DB_PASSWORD` | PostgreSQL 密码 | `your-secure-password` |
| `DB_HOST` | 数据库主机地址 | `prod.db.internal:5432` |

## 监控与告警
| 密钥名称 | 说明 | 示例值 |
|----------|------|--------|
| `SLACK_WEBHOOK_URL` | Slack 通知 Webhook | `https://hooks.slack.com/...` |
| `PAGERDUTY_KEY` | PagerDuty 集成密钥 | `...` |
| `GRAFANA_PASSWORD` | Grafana 管理员密码 | `secure-password` |

## 第三方服务
| 密钥名称 | 说明 | 示例值 |
|----------|------|--------|
| `SENTRY_DSN` | Sentry 错误追踪 | `https://...@sentry.io/...` |
| `SENDGRID_API_KEY` | 邮件服务 API 密钥 | `SG...` |
| `CODECOV_TOKEN` | Codecov 上传令牌 | `...` |

## 测试
| 密钥名称 | 说明 | 示例值 |
|----------|------|--------|
| `SMOKE_TEST_TOKEN` | 冒烟测试 API 令牌 | `test-token` |

---

# 如何创建 Kubeconfig 密钥

## 1. 从集群获取 kubeconfig
```bash
aws eks update-kubeconfig --name your-cluster-name --region us-east-1
```

## 2. 编码 kubeconfig
```bash
cat ~/.kube/config | base64 | tr -d '\n'
```

## 3. 添加为 GitHub Secret
进入 Settings > Secrets and variables > Actions > New repository secret

名称：`KUBE_CONFIG_STAGING`
值：[粘贴 Base64 编码后的 kubeconfig]

---

# 如何创建 AWS 凭证

## 1. 为 CI/CD 创建 IAM 用户
```bash
aws iam create-user --user-name github-actions
```

## 2. 附加权限策略
```bash
aws iam attach-user-policy \
  --user-name github-actions \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
```

## 3. 创建访问密钥
```bash
aws iam create-access-key --user-name github-actions
```

## 4. 将凭证添加到 GitHub
AWS_ACCESS_KEY_ID：[你的访问密钥 ID]
AWS_SECRET_ACCESS_KEY：[你的秘密访问密钥]

---

# 密钥轮换策略

- 每季度轮换全部密钥
- 怀疑泄露时立即轮换
- 尽可能使用 AWS Secrets Manager 自动轮换
- 每月审查访问日志
