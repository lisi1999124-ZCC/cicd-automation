# 如何把这个项目推送到 GitHub

## 第一步：安装 Git

1. 打开浏览器，访问 https://git-scm.com/download/win
2. 下载 64-bit 安装包，一路 Next 安装完毕
3. 安装完成后**重启 PowerShell**

---

## 第二步：在 GitHub 上创建空仓库

1. 登录 https://github.com
2. 点击右上角 **"+"** → **"New repository"**
3. 填写：
   - Repository name：`cicd-automation`（或你喜欢的名字）
   - 选 **Private**（私有）或 Public
   - ⚠️ **不要**勾选 Initialize README
4. 点击 **"Create repository"**
5. 复制页面上显示的仓库 URL，格式为：
   `https://github.com/你的用户名/cicd-automation.git`

---

## 第三步：推送代码

打开 PowerShell，复制粘贴以下命令（把 URL 换成你的）：

```powershell
cd "C:\Users\ThinkPad\Desktop\CICD-自动化部署方案"

git init
git add .
git commit -m "feat: initial CI/CD automation project"
git branch -M main
git remote add origin https://github.com/你的用户名/cicd-automation.git
git push -u origin main
```

---

## 第四步：验证

浏览器打开你的仓库地址，应该看到所有文件已上传：

```
cicd-automation/
├── .github/workflows/ci-cd-pipeline.yml
├── k8s/
├── monitoring/
├── infrastructure/
├── scripts/
├── docs/
├── Dockerfile
├── docker-compose.yml
└── README.md
```

---

## 常见问题

**Q: push 提示输入密码？**  
GitHub 已停用密码认证，需要用 Token：
1. GitHub → Settings → Developer settings → Personal access tokens → Generate new token
2. 勾选 `repo` 权限，生成后复制
3. push 时用 Token 代替密码

**Q: 遇到 "fatal: remote origin already exists"？**  
运行：`git remote set-url origin https://github.com/你的用户名/cicd-automation.git`
