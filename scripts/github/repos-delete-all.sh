#!/bin/bash

#############################################
# 删除所有GitHub仓库脚本
# 功能：批量删除用户账号下的所有GitHub仓库
# 安全：默认需要三次确认
# 选项：--force 跳过确认直接删除
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
删除所有GitHub仓库脚本

⚠️  警告：此操作不可逆，请谨慎使用！

用法:
    $0 <env_file_path> <work_directory> [选项]

选项:
    -f, --force              强制删除，跳过所有确认（危险操作）
    --force                  强制执行，跳过所有确认（危险操作）
    -h, --help               显示帮助信息

环境变量 (通过 .env 文件配置):
    GITHUB_TOKEN               GitHub Personal Access Token (必填)
    GITHUB_USERNAME            GitHub用户名 (必填)
    GITHUB_API                 GitHub API地址 (默认: https://api.github.com)

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
       ./repos-delete-all.sh /path/to/.env /path/to/work/directory

安全机制:
    默认情况下，脚本会要求进行三次确认：
    1. 第一次：显示将删除的仓库列表，确认是否继续
    2. 第二次：输入 'DELETE' 确认删除操作
    3. 第三次：输入 'YES' 最终确认删除

示例:
    # 使用指定的 .env 文件和工作目录
    $0 /path/to/.env /path/to/work/dir

    # 强制模式（跳过确认）
    $0 /path/to/.env /path/to/work/dir --force

    # 强制模式（短选项）
    $0 /path/to/.env /path/to/work/dir -f

    # 强制执行，跳过所有确认
    $0 /path/to/.env /path/to/work/dir --force

注意:
    - 需要 GitHub Personal Access Token (delete_repo 权限)
    - 删除的仓库无法恢复
    - 请确保你有足够的权限删除这些仓库
    - 建议先备份重要仓库
    - .env 文件已添加到 .gitignore，不会被提交
    - 必须指定环境变量文件路径和工作目录路径

获取GitHub Token:
    GitHub -> Settings -> Developer settings -> Personal access tokens -> Tokens (classic)
    勾选 'delete_repo' 权限

EOF
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

# 获取所有仓库列表
get_all_repos() {
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
        
        # 提取仓库名称
        while IFS= read -r repo_name; do
            if [ -n "$repo_name" ] && [ "$repo_name" != "null" ]; then
                repos+=("$repo_name")
            fi
        done < <(echo "$response" | jq -r '.[].name' 2>/dev/null)
        
        ((page++))
        
        # 如果获取的仓库数量少于每页限制，说明已获取完所有仓库
        if [ "$count" -lt "$per_page" ]; then
            break
        fi
    done
    
    echo "${repos[@]}"
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
    echo -e "${CYAN}将要删除的仓库列表 (${#repos[@]} 个)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    for i in "${!repos[@]}"; do
        printf "${GREEN}%3d${NC}. ${MAGENTA}%s${NC}\n" "$((i+1))" "${repos[$i]}"
    done
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# 删除单个仓库
delete_repo() {
    local repo_name="$1"
    local repo_url="$GITHUB_API/repos/$GITHUB_USERNAME/$repo_name"
    
    local response_and_status=$(curl -s -w "\n%{http_code}" \
        -X DELETE \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$repo_url" 2>/dev/null)
    
    # 分离响应体和状态码
    local response_body=$(echo "$response_and_status" | sed '$ d')
    local status_code=$(echo "$response_and_status" | tail -n1)
    
    if [ "$status_code" = "204" ] || [ "$status_code" = "404" ]; then
        # 204表示删除成功，404表示仓库已不存在（也可以认为是删除成功）
        return 0
    else
        return 1
    fi
}

# 第一次确认
confirm_step_1() {
    local repos=("$@")
    
    print_warning "您即将删除以下 ${#repos[@]} 个GitHub仓库:"
    display_repos "${repos[@]}"
    
    echo -e "${YELLOW}此操作不可逆，删除后将无法恢复！${NC}"
    echo ""
    read -p "$(echo -e ${BLUE}是否继续? [y/N]: ${NC})" confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "操作已取消"
        exit 0
    fi
    
    echo ""
}

# 第二次确认
confirm_step_2() {
    echo -e "${RED}╔════════════════════════════════════════╗${NC}"
    echo -e "${RED}║       第二次确认 - 请谨慎操作        ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}请输入 '${CYAN}DELETE${YELLOW}' 以确认删除操作:${NC}"
    echo ""
    read -p "> " confirm
    
    if [ "$confirm" != "DELETE" ]; then
        log_error "确认失败"
        log_info "操作已取消"
        exit 0
    fi
    
    echo ""
}

# 第三次确认
confirm_step_3() {
    echo -e "${RED}╔════════════════════════════════════════╗${NC}"
    echo -e "${RED}║       最后一次确认机会               ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}请输入 '${CYAN}YES${YELLOW}' 以最终确认删除所有仓库:${NC}"
    echo -e "${RED}注意：此操作将永久删除 ${#repos[@]} 个仓库！${NC}"
    echo ""
    read -p "> " confirm
    
    if [ "$confirm" != "YES" ]; then
        log_error "确认失败"
        log_info "操作已取消"
        exit 0
    fi
    
    echo ""
}

# 倒计时
countdown() {
    local seconds=$1
    
    echo -e "${YELLOW}将在 ${seconds} 秒后开始删除...${NC}"
    echo -e "${YELLOW}按 Ctrl+C 取消操作${NC}"
    echo ""
    
    for ((i=seconds; i>=1; i--)); do
        echo -ne "\r${YELLOW}倒计时: ${i} 秒${NC}  "
        sleep 1
    done
    
    echo -e "\r${GREEN}开始删除...${NC}    "
    echo ""
    echo ""
}

# 主流程
main() {
    local force_mode=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                force_mode=true
                shift
                ;;
            --force)
                FORCE_MODE=true
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
    
    # 强制模式警告
    if [ "$force_mode" = true ] || [ "$FORCE_MODE" = true ]; then
        if [ "$FORCE_MODE" = true ]; then
            print_warning "正在使用强制模式 (--force-all)"
        else
            print_warning "正在使用强制模式 (--force)"
        fi
        log_warning "这将跳过所有确认直接删除所有仓库"
        log_info "按 Ctrl+C 立即取消"
        echo ""
        countdown 5
    fi
    
    log_info "开始执行删除GitHub仓库操作"
    echo ""
    
    # 检查配置
    check_config
    
    # 获取所有仓库
    local repos=($(get_all_repos))
    
    if [ ${#repos[@]} -eq 0 ]; then
        log_success "没有需要删除的仓库"
        exit 0
    fi
    
    # 显示仓库信息
    display_repos "${repos[@]}"
    
    # 确认步骤（如果不是强制模式）
    if [ "$force_mode" = false ] && [ "$FORCE_MODE" = false ]; then
        confirm_step_1 "${repos[@]}"
        confirm_step_2
        confirm_step_3
    else
        if [ "$FORCE_MODE" = true ]; then
            log_info "强制模式：跳过所有确认步骤"
        fi
    fi
    
    # 开始删除
    log_info "开始删除仓库..."
    echo ""
    
    local success_count=0
    local fail_count=0
    local failed_repos=()
    
    for i in "${!repos[@]}"; do
        local repo="${repos[$i]}"
        local progress=$((i + 1))
        local total=${#repos[@]}
        
        printf "${BLUE}进度:${NC} [%3d/%3d] 正在删除: ${MAGENTA}%s${NC}\n" "$progress" "$total" "$repo"
        
        # 保存当前光标位置并在新的一行列出操作结果，避免覆盖和混合输出
        if delete_repo "$repo" 2>/dev/null; then
            ((success_count++))
            printf "\n${GREEN}✓${NC} 进度: [%3d/%3d] 已删除: ${MAGENTA}%s${NC}\n" "$progress" "$total" "$repo"
        else
            ((fail_count++))
            failed_repos+=("$repo")
            printf "\n${RED}✗${NC} 进度: [%3d/%3d] 失败: ${MAGENTA}%s${NC}\n" "$progress" "$total" "$repo"
        fi
    done
    
    echo ""
    echo ""
    
    # 显示结果
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}删除操作完成${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "总计: ${#repos[@]} 个仓库"
    echo -e "${GREEN}成功: $success_count 个${NC}"
    
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
        log_success "成功删除 $success_count 个仓库"
    fi
    
    if [ $fail_count -gt 0 ]; then
        log_error "有 $fail_count 个仓库删除失败"
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
