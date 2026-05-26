# 应用 CI/CD 流水线

面向生产环境的自动化部署流水线，集成安全扫描、测试和监控。

## 概述

本项目实现了一套完整的 CI/CD 流水线，具备以下能力：

- **安全优先**：Trivy 漏洞扫描、依赖审计、SAST 静态分析
- **全面测试**：单元测试、集成测试、冒烟测试
- **零停机部署**：蓝绿部署策略
- **全链路可观测**：Prometheus 指标采集、Grafana 可视化、告警通知
- **基础设施即代码**：Terraform 管理 AWS 基础设施

## 架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        CI/CD 流水线                             │
├─────────────────────────────────────────────────────────────────┤
│  源码 → 安全扫描 → 构建 → 测试 → 推送 → 预发布 → 审批 → 生产环境
└─────────────────────────────────────────────────────────────────┘
```

## 快速开始

### 1. 配置密钥

设置所需的 GitHub Secrets：

```bash
# Kubernetes 配置（Base64 编码）
KUBE_CONFIG_STAGING=<预发布环境-kubeconfig>
KUBE_CONFIG_PRODUCTION=<生产环境-kubeconfig>

# 云服务凭证
AWS_ACCESS_KEY_ID=<密钥ID>
AWS_SECRET_ACCESS_KEY=<访问密钥>

# 通知渠道
SLACK_WEBHOOK_URL=https://hooks.slack.com/...
```

完整列表见 [docs/SECRETS-MANAGEMENT.md](docs/SECRETS-MANAGEMENT.md)

### 2. 部署基础设施

```bash
cd infrastructure/terraform
terraform init
terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
```

### 3. 推送代码

```bash
git checkout -b feature/你的功能分支
# 修改代码
git push origin feature/你的功能分支
# 创建 Pull Request
```

流水线将自动：
- 运行安全扫描
- 构建并推送 Docker 镜像
- 部署到预发布环境
- 执行冒烟测试

### 4. 部署到生产环境

1. 进入 GitHub Actions
2. 找到对应的流水线运行记录
3. 点击「Review deployments」
4. 批准生产环境部署

## 目录结构

```
.
├── .github/
│   ├── workflows/           # GitHub Actions 流水线
│   └── environments/        # 环境配置
├── k8s/                     # Kubernetes 部署清单
│   ├── deployment.yaml      # 应用部署
│   ├── service.yaml         # 服务定义
│   ├── ingress.yaml         # 入口规则
│   └── configmap-secret.yaml # ConfigMap 和 Secret
├── monitoring/
│   └── prometheus/          # 监控配置
│       ├── prometheus.yml   # Prometheus 配置
│       ├── rules/           # 告警规则
│       └── alertmanager.yml # 告警路由
├── infrastructure/
│   └── terraform/           # 基础设施即代码
├── docker-compose*.yml      # 本地开发
├── Dockerfile               # 多阶段 Docker 构建
└── scripts/
    └── deploy.sh           # 部署辅助脚本
```

## 部署策略

### 蓝绿部署

流量在绿色和蓝色环境之间切换：

```bash
# 部署到绿色环境
kubectl set image deployment/app-green app=app:v2.0.0

# 运行验证...

# 切换流量
kubectl patch service app-svc -p '{"spec":{"selector":{"slot":"green"}}}'
```

### 金丝雀部署

逐步灰度切换流量：

```yaml
# nginx ingress 注解
nginx.ingress.kubernetes.io/canary: "true"
nginx.ingress.kubernetes.io/canary-weight: "5"  # 5% 流量到金丝雀
```

## 回滚

```bash
# 一键回滚
kubectl rollout undo deployment/app -n production

# 回滚到指定版本
kubectl rollout undo deployment/app -n production --to-revision=3
```

## 监控

| 面板 | 用途 |
|------|------|
| Grafana | 指标可视化 |
| Prometheus | 指标采集 |
| Kibana | 日志聚合 |
| Jaeger | 分布式链路追踪 |

## 故障排查

### 部署卡住

```bash
# 查看 Pod 状态
kubectl get pods -n production

# 查看事件
kubectl describe deployment app -n production

# 查看 Pod 日志
kubectl logs -l app=app -n production --tail=100
```

### 错误率高

1. 检查 Prometheus 告警
2. 查看应用日志
3. 验证数据库连接
4. 检查资源限制

## 贡献指南

1. 从 `develop` 分支创建功能分支
2. 编写代码并补充测试
3. 向 `develop` 发起 Pull Request
4. 审批通过后合并到 `main`
5. 流水线自动部署到生产环境

## 许可证

MIT
