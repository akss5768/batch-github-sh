#!/bin/bash

#############################################
# 检出所有GitHub仓库脚本
# 功能：批量检出用户账号下的所有GitHub仓库到本地
# 支持：指定目录、跳过已存在、显示进度
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
GITHUB_TOKEN="${GITHUB_TOKEN:-}"                              # GitHub Personal Access Token (必填)
GITHUB_USERNAME="${GITHUB_USERNAME:-}"                        # GitHub用户名 (必填)
GITHUB_API="${GITHUB_API:-https://api.github.com}"

# 检出配置
CLONE_DIR="${CLONE_DIR:-repos}"                              # 检出目录
SKIP_EXISTING="${SKIP_EXISTING:-true}"                       # 是否跳过已存在的仓库 (true/false)
CLONE_SSH="${CLONE_SSH:-false}"                              # 是否使用SSH (true/false)

# 脚本行为配置
FORCE_MODE="${FORCE_MODE:-false}"                             # 是否强制执行，跳过所有确认 (true/false)

# ==================== 颜色输出 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
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

# 打印带图标的警告
print_warning() {
    local message="$1"
    local line="${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "$line"
    echo -e "${YELLOW}⚠️  警告${NC}"
    echo "$message"
    echo "$line"
    echo ""
}

# 显示使用说明
usage() {
    cat << EOF
检出所有GitHub仓库脚本

用法:
    $0 <env_file_path> <work_directory> [选项]

选项:
    -d, --dir DIRECTORY        检出到指定目录 (默认: repos)
    -f, --force                强制检出已存在的仓库
    --force                    强制执行，跳过所有确认
    -s, --ssh                  使用SSH协议检出 (默认HTTPS)
    -h, --help                 显示帮助信息

环境变量 (通过 .env 文件配置):
    GITHUB_TOKEN               GitHub Personal Access Token (必填)
    GITHUB_USERNAME            GitHub用户名 (必填)
    GITHUB_API                 GitHub API地址 (默认: https://api.github.com)
    CLONE_DIR                  检出目录 (默认: repos)
    SKIP_EXISTING              是否跳过已存在的仓库 (默认: true)
    CLONE_SSH                  是否使用SSH协议 (默认: false)

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
       CLONE_DIR=repos
    
    3. 执行脚本
       ./repos-checkout-all.sh /path/to/.env /path/to/work/directory

工作流程:
    1. 从GitHub API获取用户的所有仓库列表
    2. 在指定目录下创建对应的文件夹
    3. 使用git clone检出每个仓库
    4. 跳过已存在的仓库 (除非使用 --force)

示例:
    # 使用指定的 .env 文件和工作目录
    $0 /path/to/.env /path/to/work/dir

    # 指定检出目录
    $0 /path/to/.env /path/to/work/dir -d my-repos

    # 强制检出（覆盖已存在的仓库）
    $0 /path/to/.env /path/to/work/dir -f

    # 使用SSH协议检出
    $0 /path/to/.env /path/to/work/dir -s

    # 组合使用
    $0 /path/to/.env /path/to/work/dir -d my-repos -f -s

    # 强制执行，跳过所有确认
    $0 /path/to/.env /path/to/work/dir --force

注意:
    - 需要 GitHub Personal Access Token (read:org 或 repo 权限)
    - 默认跳过已存在的仓库，使用 -f 可覆盖
    - 默认使用HTTPS协议，使用 -s 可切换到SSH
    - .env 文件已添加到 .gitignore，不会被提交
    - 必须指定环境变量文件路径和工作目录路径

获取GitHub Token:
    GitHub -> Settings -> Developer settings -> Personal access tokens -> Tokens (classic)
    勾选 'repo' 权限

EOF
}

# 检查GitHub Token是否配置
check_config() {
    if [ -z "$GITHUB_TOKEN" ]; then
        log_error "GITHUB_TOKEN 未配置"
        log_info "请在 .env 文件中设置 GITHUB_TOKEN"
        log_info "获取方式: GitHub -> Settings -> Developer settings -> Personal access tokens"
        exit 1
    fi
    
    if [ -z "$GITHUB_USERNAME" ]; then
        log_error "GITHUB_USERNAME 未配置"
        log_info "请在 .env 文件中设置 GITHUB_USERNAME"
        exit 1
    fi
}

# 获取所有仓库列表
get_all_repos() {
    log_info "正在获取仓库列表..."
    
    local repos=()
    local page=1
    local per_page=100
    
    while true; do
        local response=$(curl -s \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "$GITHUB_API/user/repos?page=$page&per_page=$per_page&sort=created&direction=asc" 2>/dev/null)
        
        # 检查是否还有更多仓库
        local count=$(echo "$response" | jq '. | length' 2>/dev/null || echo "0")
        
        if [ "$count" -eq 0 ]; then
            break
        fi
        
        # 提取仓库名称和克隆URL
        while IFS= read -r repo_info; do
            local repo_name=$(echo "$repo_info" | cut -d'|' -f1)
            repos+=("$repo_info")
        done < <(echo "$response" | jq -r '.[] | "\(.name)|\(.clone_url)|\(.ssh_url)|\(.visibility)"' 2>/dev/null)
        
        ((page++))
        
        # 如果获取的仓库数量少于每页限制，说明已获取完所有仓库
        if [ "$count" -lt "$per_page" ]; then
            break
        fi
    done
    
    printf '%s\n' "${repos[@]}"
}

# 显示仓库列表
display_repos() {
    local repos=("$@")
    
    if [ ${#repos[@]} -eq 0 ]; then
        log_info "没有找到任何仓库"
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}将要检出的仓库列表 (${#repos[@]} 个)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    local private_count=0
    local public_count=0
    
    for i in "${!repos[@]}"; do
        local repo_info="${repos[$i]}"
        local repo_name=$(echo "$repo_info" | cut -d'|' -f1)
        local visibility=$(echo "$repo_info" | cut -d'|' -f4)
        
        if [ "$visibility" = "private" ]; then
            echo -e "${GREEN}%3d${NC}. ${MAGENTA}%s${NC} ${YELLOW}[私有]${NC}" "$((i+1))" "$repo_name"
            ((private_count++))
        else
            echo -e "${GREEN}%3d${NC}. ${MAGENTA}%s${NC} ${CYAN}[公开]${NC}" "$((i+1))" "$repo_name"
            ((public_count++))
        fi
    done
    
    echo ""
    echo -e "  公开仓库: ${CYAN}$public_count${NC} 个"
    echo -e "  私有仓库: ${YELLOW}$private_count${NC} 个"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# 检出单个仓库
clone_repo() {
    local repo_info="$1"
    local target_dir="$2"
    
    local repo_name=$(echo "$repo_info" | cut -d'|' -f1)
    local clone_url=$(echo "$repo_info" | cut -d'|' -f2)
    local ssh_url=$(echo "$repo_info" | cut -d'|' -f3)
    
    local local_path="$target_dir/$repo_name"
    
    # 检查是否已存在
    if [ -d "$local_path" ]; then
        if [ "$SKIP_EXISTING" = "true" ]; then
            log_warning "已存在，跳过: $repo_name"
            return 2
        else
            log_warning "已存在，删除后重新检出: $repo_name"
            rm -rf "$local_path"
        fi
    fi
    
    # 选择URL
    local url="$clone_url"
    if [ "$CLONE_SSH" = "true" ]; then
        url="$ssh_url"
    fi
    
    # 检出仓库
    git clone "$url" "$local_path" &>/dev/null
    
    if [ $? -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# 主流程
main() {
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--dir)
                CLONE_DIR="$2"
                shift 2
                ;;
            -f|--force)
                # 原有功能：强制检出已存在的仓库
                SKIP_EXISTING=false
                shift
                ;;
            --force)
                # 新增功能：跳过所有确认
                FORCE_MODE=true
                shift
                ;;
            -s|--ssh)
                CLONE_SSH=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    log_info "开始检出GitHub仓库"
    echo ""
    
    # 检查配置
    check_config
    
    # 创建检出目录
    if [ ! -d "$CLONE_DIR" ]; then
        mkdir -p "$CLONE_DIR"
        log_success "创建检出目录: $CLONE_DIR"
    fi
    
    # 获取所有仓库
    local repos=($(get_all_repos))
    
    if [ ${#repos[@]} -eq 0 ]; then
        log_success "没有需要检出的仓库"
        exit 0
    fi
    
    # 显示仓库信息
    display_repos "${repos[@]}"
    
    # 显示配置
    log_info "配置信息:"
    echo "  检出目录: $CLONE_DIR"
    echo "  协议: $([ "$CLONE_SSH" = "true" ] && echo "SSH" || echo "HTTPS")"
    echo "  跳过已存在: $([ "$SKIP_EXISTING" = "true" ] && echo "是" || echo "否")"
    echo ""
    
    # 确认是否继续
    if [ "$FORCE_MODE" != "true" ]; then
        read -p "$(echo -e ${BLUE}是否继续检出这些仓库? [y/N]: ${NC})" confirm
        
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            log_info "操作已取消"
            exit 0
        fi
    else
        log_info "强制模式：跳过检出确认"
    fi
    
    echo ""
    
    # 开始检出
    log_info "开始检出仓库..."
    echo ""
    
    local success_count=0
    local fail_count=0
    local skip_count=0
    local failed_repos=()
    
    for i in "${!repos[@]}"; do
        local repo_info="${repos[$i]}"
        local repo_name=$(echo "$repo_info" | cut -d'|' -f1)
        local progress=$((i + 1))
        local total=${#repos[@]}
        
        printf "\r${BLUE}进度:${NC} [%3d/%3d] 正在检出: ${MAGENTA}%s${NC}  " "$progress" "$total" "$repo_name"
        
        clone_repo "$repo_info" "$CLONE_DIR"
        local result=$?
        
        if [ $result -eq 0 ]; then
            ((success_count++))
            printf "\r${GREEN}✓${NC} 进度: [%3d/%3d] 已检出: ${MAGENTA}%s${NC}\n" "$progress" "$total" "$repo_name"
        elif [ $result -eq 2 ]; then
            ((skip_count++))
            printf "\r${YELLOW}-${NC} 进度: [%3d/%3d] 跳过: ${MAGENTA}%s${NC}\n" "$progress" "$total" "$repo_name"
        else
            ((fail_count++))
            failed_repos+=("$repo_name")
            printf "\r${RED}✗${NC} 进度: [%3d/%3d] 失败: ${MAGENTA}%s${NC}\n" "$progress" "$total" "$repo_name"
        fi
    done
    
    echo ""
    echo ""
    
    # 显示结果
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}检出操作完成${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "总计: ${#repos[@]} 个仓库"
    echo -e "${GREEN}成功: $success_count 个${NC}"
    
    if [ $skip_count -gt 0 ]; then
        echo -e "${YELLOW}跳过: $skip_count 个${NC}"
    fi
    
    if [ $fail_count -gt 0 ]; then
        echo -e "${RED}失败: $fail_count 个${NC}"
        echo ""
        echo "失败的仓库:"
        for repo in "${failed_repos[@]}"; do
            echo -e "  ${RED}✗${NC} $repo"
        done
    fi
    
    echo ""
    
    if [ $success_count -gt 0 ]; then
        log_success "成功检出 $success_count 个仓库到目录: $CLONE_DIR"
    fi
    
    if [ $fail_count -gt 0 ]; then
        log_error "有 $fail_count 个仓库检出失败"
        log_info "请检查权限或网络连接"
    fi
}

# ==================== 参数解析 ====================
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
    exit 0
fi

# 信号处理函数 - 用于清理敏感信息
cleanup() {
    log_info "收到中断信号，正在清理..."
    # 恢复到原始目录
    cd "$WORK_DIR" 2>/dev/null || cd "$OLDPWD" 2>/dev/null
    log_info "清理完成"
    exit 1
}

# 注册信号处理器
trap cleanup INT TERM EXIT

# 执行主流程
main "$@"
