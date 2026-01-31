# GitHub仓库自动化管理工具集

一套轻量级的Shell脚本集合，用于自动化管理本地和远程GitHub仓库，支持批量创建、删除、检出仓库。经过优化，移除了.shignore功能，强制要求指定环境变量文件和工作目录路径。

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

**环境变量配置 (.env):**
```bash
GITHUB_TOKEN=your_token_here              # GitHub Personal Access Token (必填)
GITHUB_USERNAME=your_username_here        # GitHub用户名 (必填)
GITHUB_API=https://api.github.com         # GitHub API地址 (可选)
DEFAULT_BRANCH=main                        # 默认分支名称 (默认: main)
REPO_PREFIX=                               # 仓库名称前缀 (可选)
REPO_SUFFIX=                               # 仓库名称后缀 (可选)
USE_DATE_SUFFIX=false                      # 是否使用日期后缀 (默认: false)
PRIVATE_REPO=false                         # 是否创建私有仓库 (默认: false)
REPO_DESCRIPTION=Auto-created repository   # 仓库描述 (可选)
```

**使用方法:**
```bash
# 使用指定的 .env 文件和工作目录
./local-push-all.sh /path/to/.env /path/to/work/dir

# 使用命令行参数
./local-push-all.sh /path/to/.env /path/to/work/dir -u yourname -t your_token

# 使用日期后缀（避免冲突）
./local-push-all.sh /path/to/.env /path/to/work/dir -d

# 指定前缀和后缀
./local-push-all.sh /path/to/.env /path/to/work/dir -p myapp- -s -demo

# 创建私有仓库
./local-push-all.sh /path/to/.env /path/to/work/dir -r

# 完整示例
./local-push-all.sh /path/to/.env /path/to/work/dir -u myname -t ghp_xxx -b main -d -r
```

**命令行选项:**
- `-u, --username USERNAME` - GitHub用户名
- `-t, --token TOKEN` - GitHub Personal Access Token
- `-b, --branch BRANCH` - 默认分支名称 (默认: main)
- `-p, --prefix PREFIX` - 仓库名称前缀
- `-s, --suffix SUFFIX` - 仓库名称后缀
- `-d, --date-suffix` - 使用日期作为后缀
- `-r, --private` - 创建私有仓库
- `--force` - 强制执行，跳过所有确认
- `-h, --help` - 显示帮助信息

**工作流程:**
1. 扫描工作目录的所有子文件夹
2. 生成对应的仓库名称（可配置前缀/后缀/日期）
3. 检查仓库名称是否冲突，自动添加日期后缀解决
4. 初始化Git仓库并提交代码
5. 在GitHub上创建仓库
6. 推送代码到远端仓库

---

### 2. repos-delete-all.sh
批量删除用户账号下的所有GitHub仓库。

**功能特点:**
- 获取用户所有仓库并显示列表
- 默认需要三次确认（防止误操作）
- 支持 `--force` 强制模式（跳过确认）
- 显示详细进度和操作结果
- 自动统计成功/失败数量
- **必须指定环境变量文件路径和工作目录路径**

**环境变量配置 (.env):**
```bash
GITHUB_TOKEN=your_token_here              # GitHub Personal Access Token (必填)
GITHUB_USERNAME=your_username_here        # GitHub用户名 (必填)
GITHUB_API=https://api.github.com         # GitHub API地址 (可选)
```

**使用方法:**
```bash
# 默认模式（需要三次确认）
./repos-delete-all.sh /path/to/.env /path/to/work/dir

# 强制模式（跳过确认，危险操作）
./repos-delete-all.sh /path/to/.env /path/to/work/dir --force

# 强制模式（短选项）
./repos-delete-all.sh /path/to/.env /path/to/work/dir -f
```

**命令行选项:**
- `-f, --force` - 强制删除，跳过所有确认（危险操作）
- `-h, --help` - 显示帮助信息

**安全机制:**
默认情况下需要三次确认：
1. 第一次：显示将要删除的仓库列表，确认是否继续
2. 第二次：输入 `DELETE` 确认删除操作
3. 第三次：输入 `YES` 最终确认删除

**注意事项:**
- ⚠️ 删除操作不可逆，请谨慎使用
- 需要 GitHub Personal Access Token (delete_repo 权限)
- 建议先备份重要仓库

---

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

**环境变量配置 (.env):**
```bash
GITHUB_TOKEN=your_token_here              # GitHub Personal Access Token (必填)
GITHUB_USERNAME=your_username_here        # GitHub用户名 (必填)
GITHUB_API=https://api.github.com         # GitHub API地址 (可选)
CLONE_DIR=repos                           # 检出目录 (默认: repos)
SKIP_EXISTING=true                        # 是否跳过已存在的仓库 (默认: true)
CLONE_SSH=false                           # 是否使用SSH协议 (默认: false)
```

**使用方法:**
```bash
# 使用指定的 .env 文件和工作目录
./repos-checkout-all.sh /path/to/.env /path/to/work/dir

# 指定检出目录
./repos-checkout-all.sh /path/to/.env /path/to/work/dir -d my-repos

# 强制检出（覆盖已存在的仓库）
./repos-checkout-all.sh /path/to/.env /path/to/work/dir -f

# 使用SSH协议检出
./repos-checkout-all.sh /path/to/.env /path/to/work/dir -s

# 组合使用
./repos-checkout-all.sh /path/to/.env /path/to/work/dir -d my-repos -f -s
```

**命令行选项:**
- `-d, --dir DIRECTORY` - 检出到指定目录 (默认: repos)
- `-f, --force` - 强制检出已存在的仓库
- `-s, --ssh` - 使用SSH协议检出 (默认HTTPS)
- `-h, --help` - 显示帮助信息

**工作流程:**
1. 从GitHub API获取用户的所有仓库列表
2. 在指定目录下创建对应的文件夹
3. 使用git clone检出每个仓库
4. 跳过已存在的仓库（除非使用 --force）

## 配置指南

### 1. 环境变量配置

所有脚本共享 `.env` 文件配置，配置优先级：
1. 命令行参数（优先级最高）
2. `.env` 文件中的环境变量
3. 脚本默认值（优先级最低）

### 2. 配置步骤

1. **复制环境变量模板**
   ```bash
   cp .env-example .env
   ```

2. **编辑 .env 文件**
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

3. **获取 GitHub Token**
   - 访问 GitHub -> Settings -> Developer settings
   - Personal access tokens -> Tokens (classic)
   - 点击 "Generate new token (classic)"
   - 根据脚本需求勾选权限：
     - **local-push-all.sh**: 需要 `repo` 权限
     - **repos-delete-all.sh**: 需要 `delete_repo` 权限
     - **repos-checkout-all.sh**: 需要 `repo` 或 `read:org` 权限

4. **执行脚本**
   ```bash
   ./local-push-all.sh /path/to/.env /path/to/work/dir
   ./repos-delete-all.sh /path/to/.env /path/to/work/dir
   ./repos-checkout-all.sh /path/to/.env /path/to/work/dir
   ./local-clean-all.sh /path/to/.env /path/to/work/dir
   ```

### 3. 权限说明

| 权限 | local-push-all.sh | repos-delete-all.sh | repos-checkout-all.sh |
|------|-------------------|---------------------|-----------------------|
| repo | ✅ 必需 | ✅ 必需 | ✅ 可选 |
| delete_repo | - | ✅ 必需 | - |
| read:org | - | - | ✅ 可选 |

---

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

---

## 使用场景

### 场景1: 批量创建新项目
```bash
# 1. 在当前目录创建多个项目文件夹
mkdir project-a project-b project-c

# 2. 执行批量创建脚本
./local-push-all.sh /path/to/.env /path/to/work/dir -d
```

### 场景2: 迁移所有仓库到新账户
```bash
# 1. 从旧账户检出所有仓库
./repos-checkout-all.sh /path/to/.env /path/to/work/dir -d old-backup

# 2. 修改 .env 中的 GITHUB_USERNAME 为新账户

# 3. 批量创建并推送到新账户
cd old-backup
../local-push-all.sh /path/to/.env /path/to/work/dir
```

### 场景3: 清理测试仓库
```bash
# 删除所有测试仓库（需要三次确认）
./repos-delete-all.sh /path/to/.env /path/to/work/dir
```

### 场景4: 本地仓库重置
```bash
# 清理本地仓库的.git目录，重置为普通目录
./local-clean-all.sh /path/to/.env /path/to/work/dir
```

### 场景5: 备份所有仓库
```bash
# 检出所有仓库到指定目录
./repos-checkout-all.sh /path/to/.env /path/to/work/dir -d backup-$(date +%Y%m%d)
```

---

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

---

## 故障排查

### 1. Token 无效或权限不足
```
[ERROR] 仓库创建失败: my-repo (状态码: 401)
```
**解决方案:**
- 检查 Token 是否正确
- 确认 Token 是否具有所需权限
- 检查 Token 是否已过期

### 2. 网络连接失败
```
[ERROR] 无法连接到 GitHub API
```
**解决方案:**
- 检查网络连接
- 确认 GitHub 服务是否正常
- 尝试使用代理

### 3. Git 操作失败
```
[ERROR] 推送失败: my-repo
```
**解决方案:**
- 检查 SSH 密钥配置（如果使用 SSH）
- 检查本地 Git 配置
- 确认仓库URL是否正确

### 4. jq 命令不存在
```
[ERROR] 缺少必需命令: jq
```
**解决方案:**
```bash
# macOS
brew install jq

# Linux
sudo apt-get install jq
```

---

## 项目结构

```
batch-github-sh/
├── .env-example            # 环境变量模板
├── .gitignore              # Git忽略文件
├── README.md               # 本文档
├── local-clean-all.sh      # 本地仓库清理脚本
├── local-push-all.sh       # 批量推送仓库脚本
├── repos-checkout-all.sh   # 批量检出仓库脚本
└── repos-delete-all.sh     # 批量删除仓库脚本
```

---

## 轻量级特性

- **零外部依赖**：仅使用系统自带的shell命令
- **单文件设计**：每个脚本都是独立的单个文件
- **高效执行**：针对大量仓库的批量操作进行了优化
- **简化配置**：移除了.shignore功能，统一参数格式
- **安全可靠**：强制指定环境变量文件和工作目录路径，多重确认机制防止误操作
- **增强安全**：改进了环境变量加载方式，添加了信号处理以安全清理敏感信息

## 许可证

MIT License