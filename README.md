# GitHub仓库自动化管理工具集

一套轻量级的Shell脚本集合，用于自动化管理本地和远程GitHub仓库，支持批量创建、删除、检出仓库。

## 项目概述

这个工具集提供了一组命令行脚本，旨在简化GitHub仓库的批量管理任务。通过简单的命令行界面，您可以快速创建、删除或检出多个仓库，非常适合需要管理大量仓库的开发者或团队。

## 脚本列表

### 1. local-push-all.sh
批量创建GitHub仓库并将本地子目录代码推送到远程仓库。

**功能特点:**
- 根据当前目录的子文件夹自动创建对应的GitHub仓库
- 自动检测仓库名称冲突并解决
- 支持仓库名称前缀、后缀和日期后缀
- 支持创建公开或私有仓库
- 自动初始化Git仓库并推送代码
- 三层配置优先级系统（命令行 > .env > 默认值）
- **必须指定环境变量文件路径和工作目录路径**

### 2. repos-delete-all.sh
批量删除用户账号下的所有GitHub仓库。

**功能特点:**
- 获取用户所有仓库并显示列表
- 默认需要三次确认（防止误操作）
- 支持 `--force` 强制模式（跳过确认）
- 显示详细进度和操作结果
- 自动统计成功/失败数量
- **必须指定环境变量文件路径和工作目录路径**

### 3. repos-checkout-all.sh
批量检出用户账号下的所有GitHub仓库到本地。

**功能特点:**
- 获取用户所有仓库并显示列表
- 支持指定检出目录
- 默认跳过已存在的仓库
- 支持 HTTPS 和 SSH 两种协议
- 显示仓库类型（公开/私有）
- 显示详细进度和操作结果
- **必须指定环境变量文件路径和工作目录路径**

### 4. local-clean-all.sh
本地仓库清理脚本。

**功能特点:**
- 清理本地仓库的.git目录，重置为普通目录
- 可选择保留或删除.gitignore文件
- 支持强制执行模式
- 安全确认机制

## 安装与配置

### 1. 克隆项目

```bash
git clone <repository-url>
cd batch-github-sh
```

### 2. 环境变量配置

所有脚本共享 `.env` 文件配置，配置优先级：
1. 命令行参数（优先级最高）
2. `.env` 文件中的环境变量
3. 脚本默认值（优先级最低）

复制环境变量模板：
```bash
cp .env-example .env
```

编辑 `.env` 文件：
```bash
# GitHub API配置
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxx
GITHUB_USERNAME=your_username
GITHUB_API=https://api.github.com

# 仓库配置
DEFAULT_BRANCH=main
REPO_PREFIX=
REPO_SUFFIX=
USE_DATE_SUFFIX=false
PRIVATE_REPO=false
REPO_DESCRIPTION=Auto-created repository

# 检出配置
CLONE_DIR=repos
SKIP_EXISTING=true
CLONE_SSH=false
```

### 3. 获取 GitHub Token

访问 GitHub -> Settings -> Developer settings
- Personal access tokens -> Tokens (classic)
- 点击 "Generate new token (classic)"
- 根据脚本需求勾选权限：
  - **local-push-all.sh**: 需要 `repo` 权限
  - **repos-delete-all.sh**: 需要 `delete_repo` 权限
  - **repos-checkout-all.sh**: 需要 `repo` 或 `read:org` 权限

## 使用方法

### local-push-all.sh 使用示例

```bash
# 使用指定的 .env 文件和工作目录
./scripts/github/local-push-all.sh /path/to/.env /path/to/work/dir

# 使用命令行参数
./scripts/github/local-push-all.sh /path/to/.env /path/to/work/dir -u yourname -t your_token

# 使用日期后缀（避免冲突）
./scripts/github/local-push-all.sh /path/to/.env /path/to/work/dir -d

# 指定前缀和后缀
./scripts/github/local-push-all.sh /path/to/.env /path/to/work/dir -p myapp- -s -demo

# 创建私有仓库
./scripts/github/local-push-all.sh /path/to/.env /path/to/work/dir -r

# 完整示例
./scripts/github/local-push-all.sh /path/to/.env /path/to/work/dir -u myname -t ghp_xxx -b main -d -r
```

### repos-delete-all.sh 使用示例

```bash
# 默认模式（需要三次确认）
./scripts/github/repos-delete-all.sh /path/to/.env /path/to/work/dir

# 强制模式（跳过确认，危险操作）
./scripts/github/repos-delete-all.sh /path/to/.env /path/to/work/dir --force
```

### repos-checkout-all.sh 使用示例

```bash
# 使用指定的 .env 文件和工作目录
./scripts/github/repos-checkout-all.sh /path/to/.env /path/to/work/dir

# 指定检出目录
./scripts/github/repos-checkout-all.sh /path/to/.env /path/to/work/dir -d my-repos

# 强制检出（覆盖已存在的仓库）
./scripts/github/repos-checkout-all.sh /path/to/.env /path/to/work/dir -f

# 使用SSH协议检出
./scripts/github/repos-checkout-all.sh /path/to/.env /path/to/work/dir -s

# 组合使用
./scripts/github/repos-checkout-all.sh /path/to/.env /path/to/work/dir -d my-repos -f -s
```

### local-clean-all.sh 使用示例

```bash
# 需要确认的清理操作
./scripts/github/local-clean-all.sh /path/to/.env /path/to/work/dir

# 强制执行，跳过所有确认
./scripts/github/local-clean-all.sh /path/to/.env /path/to/work/dir --force
```

## 依赖要求

所有脚本需要以下命令：

- **curl** - 用于与GitHub API通信
- **git** - 用于Git操作
- **jq** - 用于JSON解析（处理API响应）

### 安装依赖

**macOS:**
```bash
brew install curl git jq
```

**Ubuntu/Debian:**
```bash
sudo apt-get install curl git jq
```

**CentOS/RHEL:**
```bash
sudo yum install curl git jq
```

## 使用场景

### 场景1: 批量创建新项目
```bash
# 1. 在当前目录创建多个项目文件夹
mkdir project-a project-b project-c

# 2. 执行批量创建脚本
./scripts/github/local-push-all.sh /path/to/.env /path/to/work/dir -d
```

### 场景2: 迁移所有仓库到新账户
```bash
# 1. 从旧账户检出所有仓库
./scripts/github/repos-checkout-all.sh /path/to/.env /path/to/work/dir -d old-backup

# 2. 修改 .env 中的 GITHUB_USERNAME 为新账户

# 3. 批量创建并推送到新账户
cd old-backup
../local-push-all.sh /path/to/.env /path/to/work/dir
```

### 场景3: 清理测试仓库
```bash
# 删除所有测试仓库（需要三次确认）
./scripts/github/repos-delete-all.sh /path/to/.env /path/to/work/dir
```

### 场景4: 本地仓库重置
```bash
# 清理本地仓库的.git目录，重置为普通目录
./scripts/github/local-clean-all.sh /path/to/.env /path/to/work/dir
```

### 场景5: 备份所有仓库
```bash
# 检出所有仓库到指定目录
./scripts/github/repos-checkout-all.sh /path/to/.env /path/to/work/dir -d backup-$(date +%Y%m%d)
```

## 安全注意事项

1. **保护敏感信息**
   - `.env` 文件已添加到 `.gitignore`，不会被提交到版本控制
   - 不要泄露 GitHub Token
   - Token 应定期轮换

2. **确认操作**
   - 使用 `repos-delete-all.sh` 前务必确认要删除的仓库
   - 建议先使用 `repos-checkout-all.sh` 备份重要仓库

3. **权限最小化**
   - 根据脚本需求分配最小权限
   - 不使用的权限不要勾选

## 轻量级特性

- **零外部依赖**：仅使用系统自带的shell命令
- **单文件设计**：每个脚本都是独立的单个文件
- **高效执行**：针对大量仓库的批量操作进行了优化
- **简化配置**：移除了.shignore功能，统一参数格式
- **安全可靠**：强制指定环境变量文件和工作目录路径，多重确认机制防止误操作
- **增强安全**：改进了环境变量加载方式，添加了信号处理以安全清理敏感信息

## 许可证

MIT License