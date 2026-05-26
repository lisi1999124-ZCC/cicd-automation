# =============================================================================
# 部署操作手册
# =============================================================================

## 目录
1. [部署前检查清单](#部署前检查清单)
2. [标准部署流程](#标准部署流程)
3. [回滚流程](#回滚流程)
4. [应急响应](#应急响应)
5. [部署后验证](#部署后验证)

---

## 部署前检查清单

发起部署前，请确认：

- [ ] 所有 CI/CD 流水线阶段已通过
- [ ] 至少一名团队成员已完成代码审查
- [ ] 安全扫描已完成且无严重漏洞
- [ ] 测试覆盖率达到最低阈值（80%）
- [ ] 数据库迁移向后兼容
- [ ] 功能开关已按需配置
- [ ] 预发布环境部署已验证
- [ ] 监控面板可正常访问
- [ ] 已通知值班工程师

---

## 标准部署流程

### 自动化部署（推荐）

1. **合并到主分支**
   ```bash
   git checkout main
   git pull origin main
   git merge feature/你的功能分支
   git push origin main
   ```

2. **流水线自动触发**
   - GitHub Actions 自动执行：
     - 运行安全扫描
     - 构建 Docker 镜像
     - 部署到预发布环境
     - 执行冒烟测试
     - 等待生产环境手动审批

3. **生产环境审批**
   - 进入 GitHub Actions 流水线运行记录
   - 点击「Review deployments」
   - 选择「Production」环境
   - 点击「Approve and deploy」

### 手动部署（仅限紧急情况）

当自动化流水线不可用时：

```bash
# 1. 构建并打标签
docker build -t app:$(git rev-parse --short HEAD) .

# 2. 推送到镜像仓库
docker push app:$(git rev-parse --short HEAD)

# 3. 部署到 Kubernetes
kubectl set image deployment/app \
  app=app:$(git rev-parse --short HEAD) \
  -n production

# 4. 监控发布状态
kubectl rollout status deployment/app -n production --timeout=300s
```

---

## 回滚流程

### 自动回滚
健康检查失败时流水线自动回滚。

### 手动回滚（一键操作）

```bash
# 回滚到上一个版本
kubectl rollout undo deployment/app -n production

# 回滚到指定版本
kubectl rollout undo deployment/app -n production --to-revision=2

# 验证回滚
kubectl rollout status deployment/app -n production
```

### 完整回滚流程

1. **查看部署历史**
   ```bash
   kubectl rollout history deployment/app -n production
   ```

2. **确定目标版本**
   ```
   deployment.apps/app
   REVISION  CHANGE-CAUSE
   1         <none>
   2         kubectl set image deployment/app app=app:v1.0.1
   3         kubectl set image deployment/app app=app:v1.0.2  <-- 当前（有问题）
   ```

3. **执行回滚**
   ```bash
   kubectl rollout undo deployment/app -n production --to-revision=2
   ```

4. **验证**
   ```bash
   # 检查 Pod 是否健康
   kubectl get pods -n production -l app=app
   
   # 查看日志
   kubectl logs -n production -l app=app --tail=100
   
   # 测试接口
   curl https://example.com/health
   ```

---

## 应急响应

### 严重告警响应

1. **确认告警**（PagerDuty / Slack）

2. **评估影响范围**
   ```bash
   # 查看 Pod 状态
   kubectl get pods -n production
   
   # 查看近期事件
   kubectl get events -n production --sort-by='.lastTimestamp'
   
   # 查看 Pod 日志
   kubectl logs -n production -l app=app --tail=500
   ```

3. **立即行动**
   ```bash
   # Pod 崩溃：检查资源限制
   kubectl describe pod <pod-name> -n production
   
   # OOMKilled：扩容资源
   kubectl patch hpa app-hpa -n production -p '{"spec":{"maxReplicas":15}}'
   
   # 网络问题：检查 Ingress
   kubectl describe ingress app-ingress -n production
   ```

4. **必要时回滚**
   ```bash
   kubectl rollout undo deployment/app -n production
   ```

5. **通知相关方**
   - 更新 Slack #incidents 频道
   - 更新状态页（如适用）
   - 记录事件时间线

---

## 部署后验证

### 1. 健康检查
```bash
# HTTP 健康检查接口
curl -f https://example.com/health

# 期望返回：{"status":"ok","version":"1.2.3"}
```

### 2. 冒烟测试
```bash
npm run test:smoke -- --env=production
```

### 3. 验证指标
- [ ] 错误率 < 1%
- [ ] P99 延迟 < 500ms
- [ ] 成功率 > 99.5%

### 4. 检查监控面板
- [ ] Grafana：应用指标正常
- [ ] Grafana：错误率无突增
- [ ] Grafana：请求速率稳定

### 5. 验证日志
```bash
# 检查错误日志
kubectl logs -n production -l app=app --since=1h | grep -i error

# 检查警告日志（部分警告属于正常现象）
kubectl logs -n production -l app=app --since=1h | grep -i warn
```

### 6. 数据库验证
```bash
# 检查待执行的迁移
kubectl exec -it deployment/app -n production -- npm run migrate:status

# 执行待处理的迁移
kubectl exec -it deployment/app -n production -- npm run migrate
```

---

## 监控面板

| 面板 | URL | 用途 |
|------|-----|------|
| Grafana | https://grafana.example.com | 主指标面板 |
| Prometheus | https://prometheus.example.com | 原始指标与告警 |
| Kibana | https://kibana.example.com | 应用日志 |
| Jaeger | https://jaeger.example.com | 分布式链路追踪 |

---

## 常用命令

```bash
# 实时监控 Pod 状态
kubectl get pods -n production -w

# 端口转发用于本地调试
kubectl port-forward -n production svc/app-svc 8080:80

# 获取 Pod 详细信息
kubectl describe pod <pod-name> -n production

# 进入容器执行 Shell
kubectl exec -it <pod-name> -n production -- sh

# 查看资源使用情况
kubectl top pods -n production
kubectl top nodes

# 检查 HPA 状态
kubectl get hpa -n production
kubectl describe hpa app-hpa -n production

# 手动扩缩容（紧急情况）
kubectl scale deployment app-green -n production --replicas=5
```
