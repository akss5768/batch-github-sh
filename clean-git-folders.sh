#!/bin/bash

#############################################
# 清空二级目录的.git目录脚本
# 功能：批量删除当前目录下所有二级目录中的.git目录
# 用途：将已初始化Git的目录重置为普通目录
#############################################

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
清空二级目录的.git目录脚本

此脚本用于批量删除当前目录下所有二级目录中的.git目录，
将已初始化Git的目录重置为普通目录。

⚠️  警告：删除.git目录将：
    - 移除Git版本控制历史
    - 保留所有源代码文件
    - 保留.gitignore文件
    - 断开与远程仓库的连接

用法:
    $0 [选项]

选项:
    -y, --yes               跳过确认直接删除
    -d, --dry-run           模拟运行，只显示将要删除的目录，不实际删除
    -h, --help              显示帮助信息

示例:
    # 默认模式（需要确认）
    $0

    # 跳过确认直接删除
    $0 -y

    # 模拟运行，查看将要删除的目录
    $0 -d

注意:
    - 此操作不可逆
    - 删除.git目录后，目录不再是Git仓库
    - 建议先备份重要数据
    - 此脚本只操作二级目录（当前目录的子目录）

EOF
}

# 扫描二级目录并查找.git目录
scan_git_folders() {
    local git_folders=()
    
    for dir in */; do
        if [ -d "$dir" ]; then
            local dir_name=$(basename "$dir")
            # 排除隐藏目录
            if [[ ! "$dir_name" =~ ^\. ]]; then
                local git_path="${dir}.git"
                if [ -d "$git_path" ]; then
                    git_folders+=("$dir_name")
                fi
            fi
        fi
    done
    
    echo "${git_folders[@]}"
}

# 显示将要删除的.git目录
display_git_folders() {
    local folders=("$@")
    
    if [ ${#folders[@]} -eq 0 ]; then
        log_info "没有找到包含.git目录的二级目录"
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}找到 ${#folders[@]} 个包含.git目录的二级目录${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    for i in "${!folders[@]}"; do
        local dir="${folders[$i]}"
        local git_path="$dir/.git"
        local size=$(du -sh "$git_path" 2>/dev/null | cut -f1)
        echo -e "${GREEN}%3d${NC}. ${MAGENTA}%s${NC} ${BLUE}(.git 大小: %s)${NC}" "$((i+1))" "$dir" "$size"
    done
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# 删除单个.git目录
delete_git_folder() {
    local dir="$1"
    local git_path="$dir/.git"
    
    if [ ! -d "$git_path" ]; then
        return 1
    fi
    
    rm -rf "$git_path"
    
    if [ $? -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# 主流程
main() {
    local skip_confirm=false
    local dry_run=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -y|--yes)
                skip_confirm=true
                shift
                ;;
            -d|--dry-run)
                dry_run=true
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
    
    log_info "开始扫描二级目录的.git目录"
    echo ""
    
    # 扫描.git目录
    local git_folders=($(scan_git_folders))
    
    if [ ${#git_folders[@]} -eq 0 ]; then
        log_success "没有找到需要清理的.git目录"
        exit 0
    fi
    
    # 显示将要删除的目录
    display_git_folders "${git_folders[@]}"
    
    # 模拟运行
    if [ "$dry_run" = true ]; then
        echo -e "${YELLOW}─── 模拟运行模式 ───${NC}"
        echo -e "${YELLOW}以上是将要删除的.git目录列表，未执行实际删除操作${NC}"
        exit 0
    fi
    
    # 确认操作
    if [ "$skip_confirm" = false ]; then
        echo -e "${YELLOW}⚠️  警告：此操作将删除以上所有目录中的.git目录${NC}"
        echo -e "${RED}删除后将无法恢复Git历史记录！${NC}"
        echo ""
        read -p "$(echo -e ${BLUE}是否继续删除这些.git目录? [y/N]: ${NC})" confirm
        
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            log_info "操作已取消"
            exit 0
        fi
        
        echo ""
    fi
    
    # 开始删除
    log_info "开始删除.git目录..."
    echo ""
    
    local success_count=0
    local fail_count=0
    local failed_dirs=()
    
    for i in "${!git_folders[@]}"; do
        local dir="${git_folders[$i]}"
        local progress=$((i + 1))
        local total=${#git_folders[@]}
        
        printf "\r${BLUE}进度:${NC} [%3d/%3d] 正在删除: ${MAGENTA}%s/.git${NC}  " "$progress" "$total" "$dir"
        
        if delete_git_folder "$dir"; then
            ((success_count++))
            printf "\r${GREEN}✓${NC} 进度: [%3d/%3d] 已删除: ${MAGENTA}%s/.git${NC}\n" "$progress" "$total" "$dir"
        else
            ((fail_count++))
            failed_dirs+=("$dir")
            printf "\r${RED}✗${NC} 进度: [%3d/%3d] 失败: ${MAGENTA}%s/.git${NC}\n" "$progress" "$total" "$dir"
        fi
    done
    
    echo ""
    echo ""
    
    # 显示结果
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}清理操作完成${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "总计: ${#git_folders[@]} 个.git目录"
    echo -e "${GREEN}成功: $success_count 个${NC}"
    
    if [ $fail_count -gt 0 ]; then
        echo -e "${RED}失败: $fail_count 个${NC}"
        echo ""
        echo "失败的目录:"
        for dir in "${failed_dirs[@]}"; do
            echo -e "  ${RED}✗${NC} $dir/.git"
        done
    fi
    
    echo ""
    
    if [ $success_count -gt 0 ]; then
        log_success "成功删除 $success_count 个.git目录"
        echo ""
        log_info "以下目录已不再是Git仓库，可以重新初始化"
    fi
    
    if [ $fail_count -gt 0 ]; then
        log_error "有 $fail_count 个.git目录删除失败"
        log_info "请检查文件权限或磁盘空间"
    fi
}

# ==================== 参数解析 ====================
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
    exit 0
fi

# 执行主流程
main "$@"
