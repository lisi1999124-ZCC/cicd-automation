# 企业级 CI/CD 自动化部署方案

**版本**: v1.0  
**日期**: 2026-05-16  
**作者**: DevOps Automator

---

## 一、方案概述

### 1.1 背景与目标

传统部署流程依赖手工操作，存在以下问题：
- 部署过程繁琐，耗时长达数小时
- 人工操作易出错，环境不一致
- 问题回溯困难，故障定位耗时
- 部署频率低，无法满足快速迭代需求

**本方案目标**：
- 实现代码提交到生产环境的全自动化
- 消除手工操作，确保环境一致性
- 部署频率提升至每日多次
- MTTR（平均恢复时间）降低至 30 分钟内

### 1.2 核心价值

| 指标 | 优化前 | 优化后 |
|------|--------|--------|
| 部署频率 | 每周 1-2 次 | 每日 10+ 次 |
| 部署耗时 | 2-4 小时 | 5-10 分钟 |
| 人工操作 | 100% | 0% |
| 回滚时间 | 30-60 分钟 | 1-2 分钟 |
| 环境一致性 | 不可控 | 100% 一致 |

---

## 二、技术架构

### 2.1 整体架构图

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              CI/CD 自动化部署架构                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

  ┌──────────┐     ┌──────────┐     ┌──────────────────────────────────────┐
  │ Developer │────▶│   Git    │────▶│         GitHub Actions              │
  └──────────┘     └──────────┘     │                                      │
                                     │  ┌─────────┐  ┌─────────┐  ┌───────┐ │
                                     │  │ Security │  │ Build   │  │ Test  │ │
                                     │  │  Scan   │  │ & Push  │  │       │ │
                                     │  └────┬────┘  └────┬────┘  └───┬───┘ │
                                     │       │            │            │     │
                                     │       └────────────┼────────────┘     │
                                     │                    ▼                  │
                                     │  ┌─────────────────────────────────┐  │
                                     │  │        Container Registry       │  │
                                     │  └──────────────┬──────────────────┘  │
                                     └─────────────────┼──────────────────────┘
                                                       │
                                     ┌─────────────────┴─────────────────┐
                                     │                                   │
                                     ▼                                   ▼
                               ┌──────────┐                       ┌──────────┐
                               │ Staging  │───────────────────────│Production│
                               │          │   Manual Approval     │          │
                               └────┬─────┘                       └────┬─────┘
                                    │                                  │
                                    ▼                                  ▼
                               ┌──────────────────────────────────────────────┐
                               │           Kubernetes Cluster                   │
                               │  ┌─────────┐    ┌─────────┐    ┌─────────┐   │
                               │  │ Green   │◄───│   LB    │───▶│  Blue   │   │
                               │  │ (Live)  │    │         │    │(Standby)│   │
                               │  └─────────┘    └─────────┘    └─────────┘   │
                               └──────────────────────────────────────────────┘
                                     │
                                     ▼
                               ┌──────────────────────────────────────────────┐
                               │           Observability Stack                │
                               │  Prometheus → Grafana → Alertmanager → Slack │
                               └──────────────────────────────────────────────┘
```

### 2.2 技术栈

| 类别 | 技术选型 | 说明 |
|------|----------|------|
| **代码仓库** | GitHub | 支持 Actions 自动化 |
| **容器编排** | Kubernetes (EKS) | AWS 托管 K8s |
| **容器化** | Docker | 多阶段构建优化 |
| **CI/CD 引擎** | GitHub Actions | 原生集成 |
| **基础设施** | Terraform | IaC 声明式管理 |
| **监控告警** | Prometheus + Grafana | 指标与可视化 |
| **日志收集** | CloudWatch / ELK | 集中日志 |
| **安全扫描** | Trivy + SAST | 漏洞检测 |

---

## 三、CI/CD 流水线设计

### 3.1 流水线阶段

```
┌────────────────────────────────────────────────────────────────────────────┐
│                          CI/CD Pipeline Flow                               │
└────────────────────────────────────────────────────────────────────────────┘

  代码提交 ──▶ 安全扫描 ──▶ 构建测试 ──▶ 镜像推送 ──▶ Staging ──▶ 审批 ──▶ 生产
     │           │           │           │          │          │         │
     │           │           │           │          │          │         │
     ▼           ▼           ▼           ▼          ▼          ▼         ▼
  Git Push   Trivy扫描   Docker构建   Registry   自动部署   人工确认   蓝绿发布
             依赖审计    单元测试     镜像扫描   冒烟测试               监控告警
             SAST分析    集成测试
```

### 3.2 详细阶段说明

#### Stage 1: 源代码控制

| 触发条件 | 分支策略 | 保护规则 |
|----------|----------|----------|
| Push / PR | main, develop, release/* | 需要 PR 审查 + 状态检查通过 |

#### Stage 2: 安全扫描 (并行)

| 扫描类型 | 工具 | 质量门禁 |
|----------|------|----------|
| 漏洞扫描 | Trivy | Critical = 0 |
| 依赖审计 | npm audit | High/Critical = 0 |
| 代码分析 | ESLint + SonarQube | 覆盖率 ≥80% |

#### Stage 3: 构建与测试

| 测试类型 | 覆盖率要求 | 超时时间 |
|----------|------------|----------|
| 单元测试 | ≥80% | 10 分钟 |
| 集成测试 | 核心场景 | 15 分钟 |
| 构建产物 | Docker 镜像 | 5 分钟 |

#### Stage 4: 镜像推送

- 推送到 GitHub Container Registry
- 镜像标签策略: `sha-xxx`, `branch-name`, `latest`
- 镜像扫描: Trivy 扫描构建产物

#### Stage 5: 部署 Staging (自动)

```
部署流程:
1. kubectl set image deployment/app app=<new-image>
2. kubectl rollout status deployment/app
3. curl /health → HTTP 200
4. npm run test:smoke
```

#### Stage 6: 生产审批 (手动)

- GitHub Actions 环境保护规则
- 需要指定审批者同意
- 审批后触发蓝绿部署

#### Stage 7: 蓝绿部署

```
1. 部署到 Blue 环境 (待机)
2. 健康检查 Blue
3. 切换 Load Balancer 流量到 Blue
4. 验证流量正常
5. 保留 Green 用于快速回滚
```

---

## 四、部署策略

### 4.1 蓝绿部署 (推荐)

**适用场景**: 有状态应用、需要零停机的关键系统

**优势**:
- 零停机部署
- 快速回滚 (< 2 分钟)
- 完整验证后再切换流量

```
         ┌─────────────────────────────────────────────────┐
         │              Load Balancer                      │
         │                                                 │
         │    100% Traffic ──────────────────────────┐    │
         │                                          │    │
         └──────────────────────────────────────────┼────┘
                                                    │
                                                    ▼
                                        ┌───────────────────┐
                                        │   🟢 Green (Live) │
                                        │   当前生产版本     │
                                        └───────────────────┘
                                                    │
                                                    │ 切换
                                                    ▼
                                        ┌───────────────────┐
                                        │   🔵 Blue (Standby)│
                                        │   新版本部署中     │
                                        └───────────────────┘
```

### 4.2 金丝雀部署

**适用场景**: 新功能验证、A/B 测试

**策略**: 初始 5% 流量 → 观察指标 → 逐步增加

```yaml
# Ingress 注解示例
nginx.ingress.kubernetes.io/canary: "true"
nginx.ingress.kubernetes.io/canary-weight: "5"
```

### 4.3 滚动更新

**适用场景**: 无状态应用、Dev 环境

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

---

## 五、监控与告警

### 5.1 监控指标

| 类别 | 指标 | 告警阈值 |
|------|------|----------|
| **应用** | 错误率 | > 1% |
| **应用** | P99 延迟 | > 500ms |
| **应用** | QPS | < 正常值 50% |
| **基础设施** | CPU 使用率 | > 85% |
| **基础设施** | 内存使用率 | > 90% |
| **数据库** | 连接数 | > 80% |
| **Redis** | 内存使用率 | > 90% |

### 5.2 告警级别

| 级别 | 含义 | 通知渠道 | 响应时间 |
|------|------|----------|----------|
| 🔴 Critical | 服务不可用 | Slack #alerts + PagerDuty | 5 分钟 |
| 🟡 Warning | 性能下降 | Slack #alerts-warning | 30 分钟 |
| 🔵 Info | 通知类 | Slack #deployments | - |

### 5.3 告警规则示例

```yaml
# 高错误率告警
- alert: HighErrorRate
  expr: |
    sum(rate(http_requests_total{status=~"5.."}[5m])) 
    / sum(rate(http_requests_total[5m])) > 0.01
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "错误率超过 1%"
    runbook: "https://wiki.example.com/runbooks/high-error-rate"
```

---

## 六、基础设施配置

### 6.1 AWS EKS 集群

| 配置项 | 规格 | 说明 |
|--------|------|------|
| 集群版本 | 1.28 | 最新稳定版 |
| 节点类型 | m6i.xlarge | 4vCPU/16GB |
| 节点数量 | 2-10 | 自动扩缩容 |
| 区域 | us-east-1 | 多可用区部署 |

### 6.2 数据库配置

**RDS PostgreSQL**:
- 实例类型: db.r6g.large
- 存储: 100GB (最大 500GB)
- 多可用区: 启用
- 自动备份: 7 天

**ElastiCache Redis**:
- 节点类型: cache.r6g.large
- 副本数: 2
- 自动故障转移: 启用

### 6.3 网络架构

```
┌────────────────────────────────────────────────────────────┐
│                         VPC (10.0.0.0/16)                 │
│                                                          │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ Public Subnets (可访问互联网)                        │  │
│  │  - 10.0.101.0/24  (AZ1)                            │  │
│  │  - 10.0.102.0/24  (AZ2)                            │  │
│  │  - 10.0.103.0/24  (AZ3)                            │  │
│  │                                                      │  │
│  │  - NAT Gateway                                       │  │
│  │  - Application Load Balancer                        │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                          │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ Private Subnets (仅 VPC 内部访问)                    │  │
│  │  - 10.0.1.0/24   (AZ1)                            │  │
│  │  - 10.0.2.0/24   (AZ2)                            │  │
│  │  - 10.0.3.0/24   (AZ3)                            │  │
│  │                                                      │  │
│  │  - EKS Worker Nodes                                 │  │
│  │  - RDS PostgreSQL                                  │  │
│  │  - ElastiCache Redis                               │  │
│  └─────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

---

## 七、回滚策略

### 7.1 自动回滚

触发条件:
- 健康检查连续失败 3 次
- 错误率超过阈值
- 响应时间异常

```yaml
# GitHub Actions 自动回滚配置
- name: Rollback on failure
  if: failure()
  run: |
    kubectl rollout undo deployment/app -n production
```

### 7.2 手动回滚

```bash
# 一键回滚
kubectl rollout undo deployment/app-green -n production

# 回滚到指定版本
kubectl rollout undo deployment/app-green -n production --to-revision=3

# 查看历史
kubectl rollout history deployment/app-green -n production
```

### 7.3 回滚决策流程

```
┌─────────────────────────────────────────────────┐
│                  告警触发                        │
└───────────────────────┬─────────────────────────┘
                        │
                        ▼
          ┌─────────────────────────────┐
          │     问题影响评估            │
          │  - 错误率上升?              │
          │  - 功能不可用?              │
          │  - 性能严重下降?            │
          └─────────────┬───────────────┘
                        │
          ┌─────────────┴───────────────┐
          │                            │
          ▼                            ▼
    ┌──────────┐               ┌──────────┐
    │   是     │               │   否     │
    │ 紧急回滚 │               │ 继续排查  │
    └────┬─────┘               └──────────┘
         │
         ▼
    ┌─────────────────────────────────┐
    │  kubectl rollout undo           │
    │  通知团队 (Slack + PagerDuty)   │
    │  创建事故单                      │
    └─────────────────────────────────┘
```

---

## 八、安全配置

### 8.1 网络安全

- 所有 Pod 间通信加密
- 外部访问仅通过 LoadBalancer
- 数据库仅允许应用层访问
- 敏感数据通过 Kubernetes Secrets 管理

### 8.2 容器安全

| 措施 | 配置 |
|------|------|
| 非 root 用户运行 | `runAsNonRoot: true` |
| 只读文件系统 | `readOnlyRootFilesystem: true` |
| 特权禁用 | `allowPrivilegeEscalation: false` |
| 镜像签名 | Cosign 签名验证 |

### 8.3 密钥管理

```bash
# 使用 External Secrets Operator
# 从 AWS Secrets Manager 同步密钥
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
spec:
  secretStoreRef:
    name: aws-secrets-manager
  target:
    name: app-secrets
  data:
    - secretKey: DATABASE_URL
      remoteRef:
        key: production/app/database
```

---

## 九、实施计划

### Phase 1: 基础建设 (第 1-2 周)

| 任务 | 负责人 | 交付物 |
|------|--------|--------|
| 云基础设施部署 | DevOps | EKS 集群 + RDS + Redis |
| CI/CD 流水线搭建 | DevOps | GitHub Actions 工作流 |
| 容器化改造 | 开发团队 | Dockerfile + 镜像 |
| K8s 部署配置 | DevOps | Deployment + Service |

### Phase 2: 自动化测试 (第 3 周)

| 任务 | 负责人 | 交付物 |
|------|--------|--------|
| 单元测试完善 | 开发团队 | 测试覆盖率 ≥80% |
| 集成测试 | 开发团队 | 核心场景覆盖 |
| 安全扫描集成 | DevOps | Trivy + SAST |
| 冒烟测试 | QA | 测试用例 |

### Phase 3: 监控告警 (第 4 周)

| 任务 | 负责人 | 交付物 |
|------|--------|--------|
| Prometheus 部署 | DevOps | 指标采集 |
| Grafana 仪表盘 | DevOps | 可视化面板 |
| 告警规则 | DevOps | 40+ 告警规则 |
| 告警通知 | DevOps | Slack + PagerDuty |

### Phase 4: 生产切换 (第 5-6 周)

| 任务 | 负责人 | 交付物 |
|------|--------|--------|
| Staging 环境验证 | 全团队 | 全流程测试 |
| 生产环境部署 | DevOps | 生产 K8s |
| 蓝绿部署演练 | DevOps | 回滚演练 |
| 文档完善 | DevOps | 运维手册 |

---

## 十、运维手册

### 10.1 日常部署流程

```bash
# 1. 合并代码到 main
git checkout main
git pull
git merge feature/your-feature
git push origin main

# 2. 等待流水线执行
# - 安全扫描: ~5 分钟
# - 构建测试: ~10 分钟
# - Staging 部署: ~5 分钟

# 3. 审批生产部署
# GitHub Actions → 点击 "Review deployments" → Approve

# 4. 验证部署
./scripts/deploy.sh status production
```

### 10.2 常用命令

```bash
# 查看部署状态
kubectl get pods -n production -l app=app

# 查看日志
kubectl logs -f deployment/app-green -n production

# 进入容器
kubectl exec -it <pod-name> -n production -- sh

# 查看资源使用
kubectl top pods -n production

# 扩缩容
kubectl scale deployment app-green -n production --replicas=5

# 回滚
kubectl rollout undo deployment/app-green -n production
```

### 10.3 故障排查

| 问题 | 排查命令 | 解决方案 |
|------|----------|----------|
| Pod 不启动 | `kubectl describe pod` | 检查资源限制、镜像拉取 |
| 健康检查失败 | `kubectl logs` + `/health` 端点 | 检查应用日志 |
| 502 错误 | `kubectl get endpoints` | 检查 Service selector |
| 网络不通 | `kubectl exec` + `curl` | 检查 NetworkPolicy |

---

## 十一、文件清单

| 文件路径 | 说明 |
|----------|------|
| `.github/workflows/ci-cd-pipeline.yml` | GitHub Actions 主流水线 |
| `Dockerfile` | 多阶段 Docker 构建 |
| `docker-compose.yml` | 本地开发环境 |
| `docker-compose.staging.yml` | Staging 环境 |
| `k8s/deployment.yaml` | 应用 Deployment + HPA |
| `k8s/service.yaml` | Kubernetes Service |
| `k8s/ingress.yaml` | Ingress 配置 |
| `k8s/configmap-secret.yaml` | ConfigMap/Secret/NetworkPolicy |
| `k8s/additional-resources.yaml` | PDB/Quota/CronJob |
| `monitoring/prometheus/prometheus.yml` | Prometheus 配置 |
| `monitoring/prometheus/rules/alerts.yml` | 告警规则 |
| `monitoring/prometheus/alertmanager.yml` | 告警路由 |
| `infrastructure/terraform/main.tf` | AWS 基础设施 |
| `scripts/deploy.sh` | 部署辅助脚本 |
| `docs/CICD-ARCHITECTURE.md` | 架构文档 |
| `docs/DEPLOYMENT-RUNBOOK.md` | 部署手册 |
| `docs/SECRETS-MANAGEMENT.md` | 密钥管理指南 |

---

## 十二、验收标准

### 12.1 功能验收

- [ ] 代码提交自动触发流水线
- [ ] 安全扫描阻塞高危漏洞
- [ ] 自动部署到 Staging
- [ ] 人工审批控制生产部署
- [ ] 蓝绿部署零停机
- [ ] 一键回滚功能正常

### 12.2 性能验收

- [ ] 流水线执行时间 < 20 分钟
- [ ] 部署时间 < 10 分钟
- [ ] 回滚时间 < 2 分钟
- [ ] 监控数据延迟 < 1 分钟

### 12.3 安全验收

- [ ] 无 Critical 漏洞进入生产
- [ ] 敏感信息不暴露在代码中
- [ ] 审计日志完整记录

---

## 附录 A: GitHub Secrets 配置

| Secret 名称 | 说明 | 必填 |
|-------------|------|------|
| `KUBE_CONFIG_STAGING` | Staging kubeconfig | ✅ |
| `KUBE_CONFIG_PRODUCTION` | Production kubeconfig | ✅ |
| `AWS_ACCESS_KEY_ID` | AWS 访问密钥 | ✅ |
| `AWS_SECRET_ACCESS_KEY` | AWS 密钥 | ✅ |
| `SLACK_WEBHOOK_URL` | Slack 通知 | ✅ |
| `CODECOV_TOKEN` | 代码覆盖率 | ❌ |

---

## 附录 B: 联系方式

| 角色 | 职责 | 响应时间 |
|------|------|----------|
| DevOps 团队 | 基础设施、CI/CD | 工作时间 |
| On-Call | 生产故障 | 5 分钟 |
| 安全团队 | 安全事件 | 1 小时 |

---

**文档版本历史**:

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| v1.0 | 2026-05-16 | 初始版本 |

---

*本方案由 DevOps Automator 生成，可根据实际业务需求进行调整。*
