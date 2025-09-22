#!/bin/bash

# =============================================================================
# 案例1: 脚本退出时自动清理临时文件
# 功能: 演示如何使用trap确保临时资源在脚本退出时被正确清理
# 使用场景: 任何需要创建临时文件/目录的脚本
# =============================================================================

set -euo pipefail  # 严格模式

# 全局变量存储需要清理的资源
TEMP_FILES=()
TEMP_DIRS=()
LOCK_FILES=()

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $*" >&2
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

# =============================================================================
# 清理函数 - 这是trap的核心处理函数
# =============================================================================
cleanup() {
    local exit_code=$?
    
    log "开始执行清理操作..."
    
    # 清理临时文件
    if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
        log "清理临时文件..."
        for file in "${TEMP_FILES[@]}"; do
            if [[ -f "$file" ]]; then
                rm -f "$file"
                log "已删除临时文件: $file"
            fi
        done
    fi
    
    # 清理临时目录
    if [[ ${#TEMP_DIRS[@]} -gt 0 ]]; then
        log "清理临时目录..."
        for dir in "${TEMP_DIRS[@]}"; do
            if [[ -d "$dir" ]]; then
                rm -rf "$dir"
                log "已删除临时目录: $dir"
            fi
        done
    fi
    
    # 清理锁文件
    if [[ ${#LOCK_FILES[@]} -gt 0 ]]; then
        log "清理锁文件..."
        for lock in "${LOCK_FILES[@]}"; do
            if [[ -f "$lock" ]]; then
                rm -f "$lock"
                log "已删除锁文件: $lock"
            fi
        done
    fi
    
    # 根据退出码显示不同信息
    if [[ $exit_code -eq 0 ]]; then
        success "脚本正常结束，清理完成"
    else
        error "脚本异常退出 (退出码: $exit_code)，清理完成"
    fi
}

# =============================================================================
# 注册清理函数到EXIT信号
# EXIT信号在脚本退出时总是会被触发，无论是正常退出还是异常退出
# =============================================================================
trap cleanup EXIT

# =============================================================================
# 辅助函数：创建临时资源并注册到清理列表
# =============================================================================

# 创建临时文件
create_temp_file() {
    local prefix="${1:-temp}"
    local temp_file=$(mktemp "/tmp/${prefix}.XXXXXX")
    TEMP_FILES+=("$temp_file")
    log "创建临时文件: $temp_file"
    echo "$temp_file"
}

# 创建临时目录
create_temp_dir() {
    local prefix="${1:-temp_dir}"
    local temp_dir=$(mktemp -d "/tmp/${prefix}.XXXXXX")
    TEMP_DIRS+=("$temp_dir")
    log "创建临时目录: $temp_dir"
    echo "$temp_dir"
}

# 创建锁文件
create_lock_file() {
    local lock_name="$1"
    local lock_file="/tmp/${lock_name}.lock"
    
    # 检查锁是否已存在
    if [[ -f "$lock_file" ]]; then
        error "锁文件已存在: $lock_file"
        return 1
    fi
    
    echo $$ > "$lock_file"
    LOCK_FILES+=("$lock_file")
    log "创建锁文件: $lock_file (PID: $$)"
    echo "$lock_file"
}

# =============================================================================
# 主程序演示
# =============================================================================

main() {
    log "开始演示临时资源清理..."
    
    # 创建锁文件防止重复运行
    local script_lock
    script_lock=$(create_lock_file "cleanup_demo")
    
    # 创建一些临时文件
    log "创建临时文件..."
    local config_file data_file log_file
    config_file=$(create_temp_file "config")
    data_file=$(create_temp_file "data")
    log_file=$(create_temp_file "log")
    
    # 向临时文件写入内容
    cat > "$config_file" << EOF
# 临时配置文件
debug=true
log_level=info
temp_dir=$(dirname "$config_file")
EOF
    
    echo "重要数据内容" > "$data_file"
    echo "$(date): 脚本开始执行" > "$log_file"
    
    # 创建临时目录
    log "创建临时目录..."
    local work_dir cache_dir
    work_dir=$(create_temp_dir "work")
    cache_dir=$(create_temp_dir "cache")
    
    # 在临时目录中创建一些文件
    echo "工作文件1" > "$work_dir/file1.txt"
    echo "工作文件2" > "$work_dir/file2.txt"
    mkdir -p "$work_dir/subdir"
    echo "子目录文件" > "$work_dir/subdir/file3.txt"
    
    echo "缓存数据" > "$cache_dir/cache.dat"
    
    # 显示创建的资源
    log "当前创建的资源:"
    echo "临时文件:"
    for file in "${TEMP_FILES[@]}"; do
        echo "  - $file ($(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "unknown") bytes)"
    done
    
    echo "临时目录:"
    for dir in "${TEMP_DIRS[@]}"; do
        local file_count=$(find "$dir" -type f | wc -l)
        echo "  - $dir ($file_count files)"
    done
    
    echo "锁文件:"
    for lock in "${LOCK_FILES[@]}"; do
        echo "  - $lock (PID: $(cat "$lock"))"
    done
    
    # 模拟一些工作
    log "模拟处理工作..."
    for i in {1..5}; do
        echo "处理步骤 $i/5" | tee -a "$log_file"
        sleep 1
    done
    
    # 询问用户是否要模拟错误
    echo
    read -p "是否要模拟脚本错误退出? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        error "模拟错误情况..."
        # 这会触发trap清理
        exit 1
    fi
    
    success "所有工作完成！"
    log "脚本即将正常退出，trap将自动执行清理..."
}

# =============================================================================
# 脚本入口
# =============================================================================

# 显示脚本信息
cat << 'EOF'
================================================================================
                        Trap 清理演示脚本
================================================================================
本脚本演示如何使用 trap 命令在脚本退出时自动清理临时资源。

功能特性:
- 自动清理临时文件和目录
- 清理锁文件防止资源泄露
- 支持正常退出和异常退出的清理
- 彩色日志输出便于观察

注意: 无论脚本如何退出，trap 都会确保资源被正确清理。
================================================================================
EOF

# 执行主程序
main "$@"