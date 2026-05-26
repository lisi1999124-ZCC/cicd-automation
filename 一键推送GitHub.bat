@echo off
chcp 65001 > nul
echo ============================================================
echo   CI/CD 项目一键推送到 GitHub
echo ============================================================
echo.

:: 检查 Git
git --version > nul 2>&1
if errorlevel 1 (
    echo [错误] 未检测到 Git，请先安装：https://git-scm.com/download/win
    echo 安装完成后重新运行本脚本
    pause
    exit /b 1
)

echo [OK] Git 已安装
echo.

:: 切换到当前目录
cd /d "%~dp0"

:: 配置 Git 用户（如未配置）
git config user.email > nul 2>&1
if errorlevel 1 (
    set /p EMAIL="请输入 Git 邮箱：" 
    git config --global user.email "%EMAIL%"
    set /p NAME="请输入 Git 用户名："
    git config --global user.name "%NAME%"
)

:: 输入 GitHub 仓库 URL
echo.
echo 请先在 GitHub 创建一个空仓库（不要勾选 Initialize README）
echo 然后输入仓库地址（格式：https://github.com/用户名/仓库名.git）
echo.
set /p REPO_URL="请输入仓库 URL："

if "%REPO_URL%"=="" (
    echo [错误] 仓库 URL 不能为空
    pause
    exit /b 1
)

:: 初始化仓库并推送
echo.
echo [1/4] 初始化本地仓库...
git init

echo [2/4] 添加所有文件...
git add .

echo [3/4] 提交...
git commit -m "feat: initial CI/CD automation project"

echo [4/4] 推送到 GitHub...
git branch -M main
git remote add origin %REPO_URL% 2> nul
git remote set-url origin %REPO_URL%
git push -u origin main

if errorlevel 1 (
    echo.
    echo [提示] 如果提示认证失败，请使用 Personal Access Token 代替密码
    echo 获取 Token: GitHub -> Settings -> Developer settings -> Personal access tokens
) else (
    echo.
    echo ============================================================
    echo   成功推送到 GitHub！
    echo   仓库地址：%REPO_URL%
    echo ============================================================
)

pause
