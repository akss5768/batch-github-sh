#!/bin/bash

#############################################
# 批量创建GitHub仓库脚本
# 功能：根据子文件夹名称批量创建远端仓库
# 支持：检查冲突、自动重命名、创建仓库、推送代码
#############################################

# ==================== 参数验证 ====================
if [ $# -lt 2 ]; then
    echo "错误: 请指定环境变量文件路径和工作目录路径"
    echo "用法: $0 <env_file_path> <work_directory> [options...]"
    exit 1
fi

ENV_FILE_PATH="$1"
WORK_DIR="$2"
shift 2

if [ ! -f "$ENV_FILE_PATH" ]; then
    echo "错误: 环境变量文件 '$ENV_FILE_PATH' 不存在"
    exit 1
fi

if [ ! -d "$WORK_DIR" ]; then
    echo "错误: 工作目录 '$WORK_DIR' 不存在"
    exit 1
fi

# 加载环境变量文件
set -a
source "$ENV_FILE_PATH" 2>/dev/null || {
    echo "错误: 无法加载环境变量文件 '$ENV_FILE_PATH'"
    echo "请确保文件存在且格式正确"
    exit 1
}
set +a

cd "$WORK_DIR" || exit 1

# ==================== 配置变量 ====================
# GitHub API配置
GITHUB_TOKEN="${GITHUB_TOKEN:-}"                              # GitHub Personal Access Token (必填)
GITHUB_USERNAME="${GITHUB_USERNAME:-}"                        # GitHub用户名 (必填)
GITHUB_API="${GITHUB_API:-https://api.github.com}"

# 仓库配置
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"                       # 默认分支名称
REPO_PREFIX="${REPO_PREFIX:-}"                                # 仓库名称前缀 (可选)
REPO_SUFFIX="${REPO_SUFFIX:-}"                                # 仓库名称后缀 (可选)

REPO_DESCRIPTION="${REPO_DESCRIPTION:-Auto-created repository}" # 仓库描述

# 是否私有仓库
PRIVATE_REPO="${PRIVATE_REPO:-false}"                         # true: 私有, false: 公开

# 脚本行为配置
FORCE_MODE="${FORCE_MODE:-false}"                             # 是否强制执行，跳过所有确认 (true/false)

# ==================== 颜色输出 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==================== 函数定义 ====================



# 打印信息
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查必需命令
check_requirements() {
    local missing_commands=()
    
    for cmd in curl git jq; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -ne 0 ]; then
        log_error "缺少必需命令: ${missing_commands[*]}"
        log_info "请安装缺少的命令:"
        echo "  - macOS: brew install ${missing_commands[*]}"
        echo "  - Linux: apt-get install ${missing_commands[*]}"
        exit 1
    fi
}

# 检查GitHub Token是否配置
check_config() {
    if [ -z "$GITHUB_TOKEN" ]; then
        log_error "GITHUB_TOKEN 未配置"
        log_info "请在脚本中设置 GITHUB_TOKEN"
        log_info "获取方式: GitHub -> Settings -> Developer settings -> Personal access tokens"
        exit 1
    fi
    
    if [ -z "$GITHUB_USERNAME" ]; then
        log_error "GITHUB_USERNAME 未配置"
        log_info "请在脚本中设置 GITHUB_USERNAME"
        exit 1
    fi
}

# 获取当前日期
get_current_date() {
    # 返回格式化的日期字符串 0601011230
    local date_str=$(date +%m%d%H%M)
    echo "$date_str"
}

# 检查仓库是否存在
check_repo_exists() {
    local repo_name="$1"
    
    local response_and_status=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$GITHUB_API/repos/$GITHUB_USERNAME/$repo_name" 2>/dev/null)
    
    # 分离响应体和状态码
    local response_body=$(echo "$response_and_status" | sed '$ d')
    local status_code=$(echo "$response_and_status" | tail -n1)
    
    if [ "$status_code" = "200" ]; then
        return 0  # 存在
    elif [ "$status_code" = "401" ]; then
        log_error "认证失败: 无效或过期的 GitHub Token"
        echo "$response_body" >&2
        exit 1
    else
        return 1  # 不存在或其他错误
    fi
}

# 重命名文件夹（仅对冲突的仓库添加日期后缀）
# 使用全局变量避免 nameref 依赖 (兼容旧版本 bash)
rename_folders() {
    # 全局变量:
    #   RENAME_FOLDERS_ARRAY: 文件夹数组名称
    #   RENAME_EXISTING_REPOS_ARRAY: 现有仓库列表数组名称
    # $1: 日期后缀字符串

    # 通过 eval 获取数组
    eval "local -a folders_array=(\"\${${RENAME_FOLDERS_ARRAY}[@]}\")"
    eval "local -a existing_repos_array=(\"\${${RENAME_EXISTING_REPOS_ARRAY}[@]}\")"
    local date_suffix="$1"

    log_info "正在重命名冲突的文件夹..."

    for existing_repo in "${existing_repos_array[@]}"; do
        for folder in "${folders_array[@]}"; do
            # 检查文件夹对应的仓库名是否与冲突仓库名相同
            local repo_name="${REPO_PREFIX}${folder}${REPO_SUFFIX}"
            if [ "$repo_name" = "$existing_repo" ]; then
                # 找到冲突的文件夹，重命名它
                local new_folder="${folder}-${date_suffix}"
                log_warning "仓库名称冲突: $repo_name (已存在)"
                log_info "重命名文件夹: $folder -> $new_folder"

                if [ -d "$folder" ]; then
                    mv "$folder" "$new_folder"
                else
                    log_warning "文件夹不存在: $folder (可能已被重命名)"
                fi
                break  # 找到匹配的文件夹后，跳出内层循环
            fi
        done
    done
}
# 初始化Git仓库
init_git_repo() {
    local folder_path="$1"
    local branch="$2"

    # 保存当前目录
    local current_dir="$(pwd)"

    cd "$folder_path" || return 1

    # 初始化仓库
    if [ ! -d ".git" ]; then
        log_info "正在初始化Git仓库..."
        git init
        log_info "正在创建并切换到分支: $branch"
        git branch -M "$branch"
    else
        log_info "Git仓库已存在，跳过初始化"
    fi

    # 显示当前 Git 状态
    local current_branch=$(git branch --show-current 2>/dev/null || echo "未设置")
    log_info "当前分支: $current_branch"

    # 添加所有文件
    log_info "正在添加所有文件..."
    git add .

    # 显示暂存状态
    local staged_files=$(git diff --staged --name-only | wc -l | tr -d ' ')
    log_info "已暂存文件数: $staged_files"

    # 检查是否有改动
    if git diff --staged --quiet && [ -z "$(git status --porcelain)" ]; then
        log_warning "没有文件需要提交: $folder_path"
        # 创建一个默认的 README.md 文件确保有内容可提交
        local folder_basename=$(basename "$folder_path")
        echo "# ${folder_basename}" > README.md
        git add README.md
        log_info "创建默认 README.md 文件用于提交"
    else
        log_info "检测到文件更改，准备提交"
    fi

    # 提交
    log_info "正在提交更改..."
    commit_output=$(git commit -m "Initial commit" 2>&1)
    commit_result=$?

    if [ $commit_result -eq 0 ]; then
        local commit_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "未知")
        log_info "提交成功: $commit_hash"
    else
        # 检查是否是"nothing to commit"的情况
        if echo "$commit_output" | grep -qi "nothing to commit"; then
            log_info "没有新的更改需要提交"
        else
            log_warning "提交警告: $(echo "$commit_output" | tail -3)"
        fi
    fi

    # 恢复原始目录
    cd "$current_dir"
    return 0
}

# 创建GitHub仓库
create_github_repo() {
    local repo_name="$1"

    log_info "创建GitHub仓库: $repo_name"

    local visibility="public"
    if [ "$PRIVATE_REPO" = "true" ]; then
        visibility="private"
    fi

    local private_flag="false"
    if [ "$PRIVATE_REPO" = "true" ]; then
        private_flag="true"
    fi

    log_info "仓库配置: 可见性=$visibility, 默认分支=$DEFAULT_BRANCH"

    local response_and_status=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$GITHUB_API/user/repos" \
        -d "{
            \"name\": \"$repo_name\",
            \"description\": \"$REPO_DESCRIPTION\",
            \"private\": $private_flag,
            \"auto_init\": false,
            \"default_branch\": \"$DEFAULT_BRANCH\"
        }" 2>/dev/null)

    # 分离响应体和状态码
    local response_body=$(echo "$response_and_status" | sed '$ d')
    local status_code=$(echo "$response_and_status" | tail -n1)

    log_info "API 响应状态码: $status_code"

    if [ "$status_code" = "201" ]; then
        # 提取仓库 URL
        local repo_url=$(echo "$response_body" | jq -r '.html_url' 2>/dev/null || echo "未知")
        local clone_url=$(echo "$response_body" | jq -r '.clone_url' 2>/dev/null || echo "未知")

        log_success "仓库创建成功: $repo_name"
        log_info "仓库地址: $repo_url"
        log_info "克隆地址: $clone_url"
        return 0
    elif [ "$status_code" = "401" ]; then
        log_error "认证失败: 无效或过期的 GitHub Token"
        log_info "请检查您的 GITHUB_TOKEN 配置"
        echo "$response_body" >&2
        exit 1
    elif [ "$status_code" = "422" ]; then
        # 检查是否是因为仓库已存在导致的422错误
        if echo "$response_body" | grep -q "already exists"; then
            log_warning "仓库已存在: $repo_name"
            return 0  # 返回0表示继续处理，因为仓库已经存在
        else
            log_error "仓库创建失败: $repo_name (状态码: $status_code)"
            echo "$response_body" >&2
            return 1
        fi
    else
        log_error "仓库创建失败: $repo_name (状态码: $status_code)"
        echo "$response_body" >&2
        return 1
    fi
}

# 推送代码到GitHub
push_to_github() {
    local folder_path="$1"
    local repo_name="$2"
    local branch="$3"

    log_info "推送到GitHub: $repo_name"

    # 保存当前目录
    local current_dir="$(pwd)"

    cd "$folder_path" || return 1

    # 使用包含认证信息的HTTPS URL
    local repo_url="https://${GITHUB_TOKEN}@github.com/${GITHUB_USERNAME}/${repo_name}.git"

    # 添加或更新远程仓库
    if git remote get-url origin &>/dev/null; then
        git remote set-url origin "$repo_url"
        log_info "更新远程仓库地址"
    else
        git remote add origin "$repo_url"
        log_info "添加远程仓库地址"
    fi

    # 显示当前远程仓库信息
    log_info "远程仓库: $(git remote get-url origin)"

    # 显示当前分支和提交信息
    local current_branch=$(git branch --show-current)
    local current_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "无提交")
    local commit_count=$(git rev-list --count HEAD 2>/dev/null || echo "0")

    log_info "当前分支: $current_branch"
    log_info "当前提交: $current_commit (共 $commit_count 个提交)"

    # 检查是否有待推送的提交
    local unpushed_commits=$(git log origin/$branch..$branch 2>/dev/null | grep -c "^commit" || echo "0")
    unpushed_commits=$(echo "$unpushed_commits" | tr -d '\n\r' | tr -d ' ')
    if [ -n "$unpushed_commits" ] && [ "$unpushed_commits" -gt 0 ] 2>/dev/null; then
        log_info "待推送提交: $unpushed_commits 个"
    else
        log_info "没有待推送的提交（可能是新仓库或已同步）"
    fi

    log_info "正在推送代码: $repo_name (分支: $branch)"

    local push_success=false
    local push_output=""

    # 首先尝试常规推送，捕获输出
    log_info "尝试第1次推送..."
    push_output=$(git push -u origin "$branch" 2>&1)
    push_result=$?

    if [ $push_result -eq 0 ]; then
        push_success=true
        log_info "推送输出:"
        echo "$push_output" | grep -E "^To |^\*|^\+|^-" || echo "$push_output"
    else
        log_warning "第1次推送失败 (退出码: $push_result)"
        log_info "失败原因: $(echo "$push_output" | tail -5)"

        # 等待一段时间，让新创建的仓库准备好接收推送
        log_warning "等待3秒后重试..."
        sleep 3

        # 再次尝试推送，使用 --set-upstream 参数
        log_info "尝试第2次推送..."
        push_output=$(git push --set-upstream origin "$branch" 2>&1)
        push_result=$?

        if [ $push_result -eq 0 ]; then
            push_success=true
            log_info "推送输出:"
            echo "$push_output" | grep -E "^To |^\*|^\+|^-" || echo "$push_output"
        else
            log_warning "第2次推送失败 (退出码: $push_result)"
            log_info "失败原因: $(echo "$push_output" | tail -5)"

            # 检查是否是分支不匹配问题
            if echo "$push_output" | grep -qi "branch.*does not exist"; then
                log_warning "远程分支不存在，尝试创建..."
                git push --set-upstream origin "$branch" 2>&1 && {
                    push_success=true
                    log_info "成功创建并推送远程分支"
                }
            elif echo "$push_output" | grep -qi "failed to push\|rejected\|non-fast-forward"; then
                log_warning "检测到推送冲突，尝试 pull 后再 push"
                # 如果是新仓库，第一次推送可能会失败，尝试 pull 再 push
                log_info "执行 git pull --rebase..."
                pull_output=$(git pull --rebase origin "$branch" 2>&1)
                pull_result=$?

                log_info "Pull 输出: $(echo "$pull_output" | tail -3)"

                if [ $pull_result -eq 0 ] || [ $pull_result -eq 1 ]; then
                    # pull 成功或已是最新，尝试推送
                    log_info "尝试第3次推送 (pull 后)..."
                    push_output=$(git push --set-upstream origin "$branch" 2>&1)
                    push_result=$?

                    if [ $push_result -eq 0 ]; then
                        push_success=true
                        log_info "推送输出:"
                        echo "$push_output" | grep -E "^To |^\*|^\+|^-" || echo "$push_output"
                    else
                        log_error "最终推送失败"
                        log_info "错误详情: $(echo "$push_output" | tail -10)"
                    fi
                else
                    log_error "Pull 操作失败"
                    log_info "错误详情: $(echo "$pull_output" | tail -10)"
                fi
            else
                log_error "未知推送错误"
                log_info "错误详情: $(echo "$push_output" | tail -10)"
            fi
        fi
    fi

    # 推送成功后，将远程URL改回不包含token的形式以增加安全性
    if [ "$push_success" = true ]; then
        git remote set-url origin "https://github.com/${GITHUB_USERNAME}/${repo_name}.git"

        # 显示推送后的状态
        final_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "无")
        log_info "推送完成，当前提交: $final_commit"

        log_success "推送成功: $repo_name (分支: $branch)"
        cd "$current_dir"
        return 0
    else
        log_error "推送失败: $repo_name (分支: $branch)"

        # 显示调试信息
        log_info "=========================================="
        log_info "调试信息:"
        log_info "本地分支: $(git branch --show-current 2>/dev/null || echo '无')"
        log_info "远程仓库: $(git remote get-url origin 2>/dev/null || echo '无')"
        log_info "本地提交数: $(git rev-list --count HEAD 2>/dev/null || echo '0')"
        log_info "=========================================="

        cd "$current_dir"
        return 1
    fi
}

# 处理单个文件夹
process_folder() {
    local folder_name="$1"
    local repo_name="$2"

    log_info "=========================================="
    log_info "处理文件夹: $folder_name -> $repo_name"
    log_info "=========================================="

    # 注意: 冲突检查和重命名已在 main() 函数中完成

    # 初始化Git仓库
    log_info "初始化Git仓库: $folder_name (分支: $DEFAULT_BRANCH)"
    if ! init_git_repo "$folder_name" "$DEFAULT_BRANCH"; then
        log_warning "初始化Git仓库失败，跳过: $folder_name"
        return 1
    fi
    log_info "Git仓库初始化完成: $folder_name"

    # 创建GitHub仓库
    log_info "创建远程仓库: $repo_name"
    if ! create_github_repo "$repo_name"; then
        log_error "创建远程仓库失败: $repo_name"
        return 1
    fi
    log_info "远程仓库创建完成: $repo_name"

    # 推送代码
    log_info "开始推送仓库: $repo_name"
    if ! push_to_github "$folder_name" "$repo_name" "$DEFAULT_BRANCH"; then
        log_error "仓库推送失败: $repo_name"
        return 1
    fi
    log_info "仓库推送完成: $repo_name"

    log_success "✓ 完成: $repo_name"
    return 0
}

# 主流程
main() {
    log_info "开始批量创建GitHub仓库"
    log_info "=========================================="
    
    # 检查配置
    check_config
    
    # 获取所有子文件夹
    local folders=()
    for item in */; do
        if [ -d "$item" ]; then
            folder_name=$(basename "$item")
            # 排除隐藏文件夹和特定文件夹
            if [[ ! "$folder_name" =~ ^\. ]] && [ "$folder_name" != "提交" ]; then
                folders+=("$folder_name")
            fi
        fi
    done
    
    if [ ${#folders[@]} -eq 0 ]; then
        log_warning "没有找到子文件夹"
        exit 0
    fi
    
    log_info "找到 ${#folders[@]} 个子文件夹:"
    printf '  - %s\n' "${folders[@]}"
    log_info "=========================================="
    
    # 生成初始仓库名称
    local repo_names=()
    for folder in "${folders[@]}"; do
        repo_name="${REPO_PREFIX}${folder}${REPO_SUFFIX}"
        repo_names+=("$repo_name")
    done

    # 保存原始文件夹列表用于重命名逻辑
    local original_folders=("${folders[@]}")

    # 循环检查和处理冲突
    local max_attempts=10
    local attempt=0
    local date_suffix=$(get_current_date)

    while [ $attempt -lt $max_attempts ]; do
        ((attempt++))
        log_info ""
        log_info "=========================================="
        log_info "第 $attempt 次检查仓库冲突"
        log_info "=========================================="

        # 检查哪些仓库已存在（只检查当前repo_names列表中的）
        local existing_repos=()
        for repo_name in "${repo_names[@]}"; do
            if check_repo_exists "$repo_name"; then
                existing_repos+=("$repo_name")
            fi
        done

        if [ ${#existing_repos[@]} -eq 0 ]; then
            log_success "没有冲突的仓库"
            break
        fi

        if [ $attempt -ge $max_attempts ]; then
            log_error "超过最大重试次数 ($max_attempts)"
            log_error "请手动检查以下冲突仓库:"
            printf '  - %s\n' "${existing_repos[@]}"
            exit 1
        fi

        log_warning "发现 ${#existing_repos[@]} 个冲突仓库"
        log_info "将添加日期后缀并重命名文件夹..."

        # 重命名文件夹（只对冲突的仓库操作）
        # 第一次循环时，使用原始文件夹列表；后续循环使用当前文件夹列表
        # 使用全局变量传递数组名称（兼容旧版本 bash）
        if [ $attempt -eq 1 ]; then
            RENAME_FOLDERS_ARRAY=original_folders
            RENAME_EXISTING_REPOS_ARRAY=existing_repos
            rename_folders "$date_suffix"
        else
            RENAME_FOLDERS_ARRAY=folders
            RENAME_EXISTING_REPOS_ARRAY=existing_repos
            rename_folders "$date_suffix"
        fi

        # 重新获取文件夹列表和仓库名称
        folders=()
        repo_names=()
        for item in */; do
            if [ -d "$item" ]; then
                folder_name=$(basename "$item")
                if [[ ! "$folder_name" =~ ^\. ]] && [ "$folder_name" != "提交" ]; then
                    folders+=("$folder_name")
                    # 使用前缀和后缀生成仓库名
                    repo_name="${REPO_PREFIX}${folder_name}${REPO_SUFFIX}"
                    repo_names+=("$repo_name")
                fi
            fi
        done
    done
    
    log_info ""
    log_info "=========================================="
    log_info "最终仓库名称列表:"
    printf '  - %s\n' "${repo_names[@]}"
    log_info "=========================================="
    
    # 确认是否继续
    if [ "$FORCE_MODE" != "true" ]; then
        echo ""
        read -p "是否继续创建这些仓库? (y/n): " confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            log_info "操作已取消"
            exit 0
        fi
    else
        log_info "强制模式：跳过创建确认"
    fi
    
    # 批量创建和推送
    local success_count=0
    local fail_count=0

    log_info ""
    log_info "=========================================="
    log_info "开始批量创建和推送仓库"
    log_info "=========================================="

    local total=${#folders[@]}
    for i in "${!folders[@]}"; do
        local folder="${folders[$i]}"
        local repo="${repo_names[$i]}"
        local progress=$((i + 1))

        log_info "处理仓库 [$progress/$total]: $folder -> $repo"

        if process_folder "$folder" "$repo"; then
            ((success_count++))
            log_success "仓库处理成功: $repo"
        else
            ((fail_count++))
            log_error "仓库处理失败: $repo"
        fi
        echo ""
    done
    
    # 汇总结果
    log_info ""
    log_info "=========================================="
    log_info "操作完成"
    log_info "=========================================="
    log_info "总计: ${#folders[@]} 个仓库"
    log_success "成功: $success_count 个"
    if [ $fail_count -gt 0 ]; then
        log_error "失败: $fail_count 个"
    fi
}

# ==================== 使用说明 ====================
usage() {
    cat << EOF
批量创建GitHub仓库脚本

用法:
    $0 <env_file_path> <work_directory> [选项]

选项:
    -u, --username USERNAME    GitHub用户名
    -t, --token TOKEN          GitHub Personal Access Token
    -b, --branch BRANCH        默认分支名称 (默认: main)
    -p, --prefix PREFIX        仓库名称前缀
    -s, --suffix SUFFIX        仓库名称后缀

    -r, --private              创建私有仓库
    --force                    强制执行，跳过所有确认
    -h, --help                 显示帮助信息

环境变量 (通过 .env 文件配置):
    GITHUB_TOKEN               GitHub Personal Access Token
    GITHUB_USERNAME            GitHub用户名
    GITHUB_API                 GitHub API地址 (默认: https://api.github.com)
    DEFAULT_BRANCH             默认分支名称 (默认: main)
    REPO_PREFIX                仓库名称前缀
    REPO_SUFFIX                仓库名称后缀

    PRIVATE_REPO               是否私有仓库 (true/false)
    REPO_DESCRIPTION           仓库描述

配置优先级:
    1. 命令行参数 (优先级最高)
    2. .env 文件中的环境变量
    3. 脚本默认值 (优先级最低)

配置步骤:
    1. 复制 .env-example 到 .env
       cp .env-example .env
    
    2. 编辑 .env 文件，配置你的信息
       GITHUB_TOKEN=your_token_here
       GITHUB_USERNAME=your_username_here
    
    3. 执行脚本
       ./local-push-all.sh /path/to/.env /path/to/work/directory

示例:
    # 使用指定的 .env 文件和工作目录
    $0 /path/to/.env /path/to/work/dir

    # 使用命令行参数
    $0 /path/to/.env /path/to/work/dir -u yourname -t your_token -d

    # 指定前缀和后缀
    $0 /path/to/.env /path/to/work/dir -p myapp- -s -demo

    # 创建私有仓库
    $0 /path/to/.env /path/to/work/dir -r

    # 强制执行，跳过所有确认
    $0 /path/to/.env /path/to/work/dir --force

注意:
    - 需要安装: curl, git, jq
    - 需要配置 GitHub Personal Access Token (repo 权限)
    - .env 文件已添加到 .gitignore，不会被提交
    - 首次使用请先配置 .env 文件
    - 必须指定环境变量文件路径和工作目录路径
EOF
}

# ==================== 参数解析 ====================
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
    exit 0
fi

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--username)
            GITHUB_USERNAME="$2"
            shift 2
            ;;
        -t|--token)
            GITHUB_TOKEN="$2"
            shift 2
            ;;
        -b|--branch)
            DEFAULT_BRANCH="$2"
            shift 2
            ;;
        -p|--prefix)
            REPO_PREFIX="$2"
            shift 2
            ;;
        -s|--suffix)
            REPO_SUFFIX="$2"
            shift 2
            ;;

        -r|--private)
            PRIVATE_REPO=true
            shift
            ;;
        --force)
            FORCE_MODE=true
            shift
            ;;
        *)
            log_error "未知选项: $1"
            usage
            exit 1
            ;;
    esac
done

# 信号处理函数 - 用于清理敏感信息
cleanup() {
    log_info "收到中断信号，正在清理..."
    # 恢复到原始目录
    cd "$WORK_DIR" 2>/dev/null || cd "$OLDPWD" 2>/dev/null

    # 尝试清理可能的凭证配置
    local current_dir=$(pwd)
    for dir in */; do
        if [ -d "$dir/.git" ]; then
            cd "$dir" &>/dev/null
            git config --unset http.extraheader 2>/dev/null || true
            cd "$current_dir" &>/dev/null
        fi
    done

    log_info "清理完成"
    exit 130  # 退出码130表示被SIGINT中断
}

# 注册信号处理器 - 只对中断和终止信号处理，不包括正常退出
trap cleanup INT TERM

# 检查必需命令
check_requirements

# 执行主流程
main
