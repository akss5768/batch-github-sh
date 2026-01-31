#!/bin/bash

#############################################
# 本地仓库清理脚本
# 功能：批量清理本地目录中的.git目录
# 支持：模拟运行、跳过确认、显示进度
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
DRY_RUN=false
SKIP_CONFIRM=false

# 脚本行为配置
FORCE_MODE=false                             # 是否强制执行，跳过所有确认

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

# 显示使用说明
usage() {
    cat << EOF
本地仓库清理脚本

用法:
    $0 <env_file_path> <work_directory> [选项]

选项:
    -y, --yes                跳过确认直接删除
    --force                  强制执行，跳过所有确认
    -d, --dry-run            模拟运行，只显示将要删除的目录，不实际删除
    -h, --help               显示帮助信息

配置步骤:
    1. 复制 .env-example 到 .env
       cp .env-example .env
    
    2. 编辑 .env 文件，配置你的信息
       GITHUB_TOKEN=your_token_here
       GITHUB_USERNAME=your_username_here
    
    3. 执行脚本
       ./local-clean-all.sh /path/to/.env /path/to/work/directory

示例:
    # 使用指定的 .env 文件和工作目录
    $0 /path/to/.env /path/to/work/dir

    # 跳过确认直接删除
    $0 /path/to/.env /path/to/work/dir -y

    # 模拟运行，查看将要删除的目录
    $0 /path/to/.env /path/to/work/dir -d

    # 强制执行，跳过所有确认
    $0 /path/to/.env /path/to/work/dir --force

注意:
    - 此操作将删除所有子目录中的 .git 目录
    - 所有源代码文件将被保留
    - 跳过确认操作非常危险，请谨慎使用
EOF
}

# 查找所有包含 .git 目录的子目录
find_git_dirs() {
    find . -mindepth 2 -maxdepth 2 -type d -name ".git" | xargs dirname
}

# 主流程
main() {
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -y|--yes)
                SKIP_CONFIRM=true
                shift
                ;;
            --force)
                FORCE_MODE=true
                SKIP_CONFIRM=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
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
    
    log_info "开始清理本地仓库的 .git 目录"
    log_info "工作目录: $(pwd)"
    echo ""
    
    # 查找所有包含 .git 目录的子目录
    local git_dirs=($(find_git_dirs))
    
    if [ ${#git_dirs[@]} -eq 0 ]; then
        log_info "没有找到包含 .git 目录的子目录"
        exit 0
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}将要清理的目录列表 (${#git_dirs[@]} 个)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    for i in "${!git_dirs[@]}"; do
        printf "${GREEN}%3d${NC}. ${MAGENTA}%s${NC}\n" "$((i+1))" "${git_dirs[$i]}"
    done
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ "$DRY_RUN" = true ]; then
        log_info "模拟运行模式，不会删除任何文件"
        exit 0
    fi
    
    if [ "$SKIP_CONFIRM" = false ]; then
        echo ""
        read -p "$(echo -e ${BLUE}确认要删除以上 ${#git_dirs[@]} 个目录中的 .git 目录吗? [y/N]: ${NC})" confirm
        
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            log_info "操作已取消"
            exit 0
        fi
    fi
    
    echo ""
    log_info "开始删除 .git 目录..."
    echo ""
    
    local success_count=0
    local fail_count=0
    local failed_dirs=()
    
    for i in "${!git_dirs[@]}"; do
        local dir="${git_dirs[$i]}"
        local git_path="$dir/.git"
        local progress=$((i + 1))
        local total=${#git_dirs[@]}
        
        printf "\r${BLUE}进度:${NC} [%3d/%3d] 正在清理: ${MAGENTA}%s${NC}  " "$progress" "$total" "$dir"
        
        if rm -rf "$git_path"; then
            ((success_count++))
            printf "\r${GREEN}✓${NC} 进度: [%3d/%3d] 已清理: ${MAGENTA}%s${NC}\n" "$progress" "$total" "$dir"
        else
            ((fail_count++))
            failed_dirs+=("$dir")
            printf "\r${RED}✗${NC} 进度: [%3d/%3d] 失败: ${MAGENTA}%s${NC}\n" "$progress" "$total" "$dir"
        fi
    done
    
    echo ""
    echo ""
    
    # 显示结果
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}清理操作完成${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "总计: ${#git_dirs[@]} 个目录"
    echo -e "${GREEN}成功: $success_count 个${NC}"
    
    if [ $fail_count -gt 0 ]; then
        echo -e "${RED}失败: $fail_count 个${NC}"
        echo ""
        echo "失败的目录:"
        for dir in "${failed_dirs[@]}"; do
            echo -e "  ${RED}✗${NC} $dir"
        done
    fi
    
    echo ""
    
    if [ $success_count -gt 0 ]; then
        log_success "成功清理 $success_count 个目录中的 .git 目录"
        log_info "源代码文件已被保留"
    fi
    
    if [ $fail_count -gt 0 ]; then
        log_error "有 $fail_count 个目录清理失败"
        log_info "请检查权限或文件是否被占用"
    fi
}

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