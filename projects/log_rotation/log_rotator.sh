#!/bin/bash

# 日志轮转工具
# 作者: Shell脚本学习项目
# 版本: 1.0

set -euo pipefail

# 脚本目录和配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config/log_rotation.conf"
CONFIG_DIR="$SCRIPT_DIR/config/logrotate.d"
LOG_FILE="$SCRIPT_DIR/logs/log_rotator.log"
ARCHIVE_DIR="$SCRIPT_DIR/archive"

# 默认配置
GLOBAL_COMPRESS=true
GLOBAL_COMPRESS_FORMAT="gzip"
GLOBAL_COMPRESS_LEVEL=6
GLOBAL_RETENTION_DAYS=30
GLOBAL_MAX_SIZE="100M"
DRY_RUN=false

# 加载配置文件
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        log_message "INFO" "配置文件已加载: $CONFIG_FILE"
    else
        log_message "WARNING" "配置文件不存在，使用默认配置"
    fi
}

# 日志记录函数
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# 解析大小字符串为字节数
parse_size() {
    local size_str="$1"
    local number=$(echo "$size_str" | sed 's/[^0-9]*//g')
    local unit=$(echo "$size_str" | sed 's/[0-9]*//g' | tr '[:lower:]' '[:upper:]')
    
    case "$unit" in
        "K"|"KB") echo $((number * 1024)) ;;
        "M"|"MB") echo $((number * 1024 * 1024)) ;;
        "G"|"GB") echo $((number * 1024 * 1024 * 1024)) ;;
        *) echo "$number" ;;
    esac
}

# 检查文件是否需要轮转
need_rotation() {
    local file="$1"
    local config="$2"
    
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    # 检查大小条件
    local size_limit=$(echo "$config" | grep -o 'size [0-9]*[KMG]*' | awk '{print $2}')
    if [ -n "$size_limit" ]; then
        local file_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
        local max_bytes=$(parse_size "$size_limit")
        
        if [ "$file_size" -gt "$max_bytes" ]; then
            log_message "INFO" "文件 $file 大小 ($file_size bytes) 超过限制 ($max_bytes bytes)"
            return 0
        fi
    fi
    
    # 检查时间条件
    local frequency=$(echo "$config" | grep -o '\(daily\|weekly\|monthly\)')
    if [ -n "$frequency" ]; then
        if check_time_condition "$file" "$frequency"; then
            log_message "INFO" "文件 $file 满足时间轮转条件 ($frequency)"
            return 0
        fi
    fi
    
    return 1
}

# 检查时间条件
check_time_condition() {
    local file="$1"
    local frequency="$2"
    
    local file_mtime=$(stat -c%Y "$file" 2>/dev/null || stat -f%m "$file" 2>/dev/null)
    local current_time=$(date +%s)
    local time_diff=$((current_time - file_mtime))
    
    case "$frequency" in
        "daily")
            # 检查是否超过1天
            if [ "$time_diff" -gt 86400 ]; then
                return 0
            fi
            ;;
        "weekly")
            # 检查是否超过7天
            if [ "$time_diff" -gt 604800 ]; then
                return 0
            fi
            ;;
        "monthly")
            # 检查是否超过30天
            if [ "$time_diff" -gt 2592000 ]; then
                return 0
            fi
            ;;
    esac
    
    return 1
}

# 轮转日志文件
rotate_log() {
    local file="$1"
    local config="$2"
    
    log_message "INFO" "开始轮转日志文件: $file"
    
    if [ "$DRY_RUN" = true ]; then
        log_message "INFO" "[DRY RUN] 将轮转文件: $file"
        return 0
    fi
    
    # 获取轮转数量
    local rotate_count=$(echo "$config" | grep -o 'rotate [0-9]*' | awk '{print $2}')
    rotate_count=${rotate_count:-7}
    
    # 轮转现有文件
    for ((i=rotate_count; i>=1; i--)); do
        local old_file="${file}.$i"
        local new_file="${file}.$((i+1))"
        
        if [ -f "$old_file" ]; then
            if [ "$i" -eq "$rotate_count" ]; then
                # 删除最老的文件
                rm -f "$old_file"
                log_message "INFO" "删除最老的日志文件: $old_file"
            else
                mv "$old_file" "$new_file"
                log_message "INFO" "重命名: $old_file -> $new_file"
            fi
        fi
    done
    
    # 轮转当前文件
    if [ -f "$file" ]; then
        mv "$file" "${file}.1"
        log_message "INFO" "轮转当前文件: $file -> ${file}.1"
        
        # 创建新的空文件
        create_new_log "$file" "$config"
        
        # 压缩轮转的文件
        if should_compress "$config"; then
            compress_log "${file}.1" "$config"
        fi
        
        # 执行后处理脚本
        execute_postrotate "$config"
    fi
}

# 创建新的日志文件
create_new_log() {
    local file="$1"
    local config="$2"
    
    # 获取原文件的权限和所有者
    local permissions="644"
    local owner="root"
    local group="root"
    
    if echo "$config" | grep -q "create"; then
        local create_line=$(echo "$config" | grep "create")
        permissions=$(echo "$create_line" | awk '{print $2}')
        owner=$(echo "$create_line" | awk '{print $3}')
        group=$(echo "$create_line" | awk '{print $4}')
    fi
    
    # 创建新文件
    touch "$file"
    chmod "$permissions" "$file"
    
    if [ "$owner" != "root" ] || [ "$group" != "root" ]; then
        chown "$owner:$group" "$file" 2>/dev/null || true
    fi
    
    log_message "INFO" "创建新日志文件: $file (权限: $permissions, 所有者: $owner:$group)"
}

# 检查是否需要压缩
should_compress() {
    local config="$1"
    
    if echo "$config" | grep -q "compress" && ! echo "$config" | grep -q "nocompress"; then
        return 0
    fi
    
    return 1
}

# 压缩日志文件
compress_log() {
    local file="$1"
    local config="$2"
    
    # 检查是否延迟压缩
    if echo "$config" | grep -q "delaycompress"; then
        log_message "INFO" "延迟压缩已启用，跳过压缩: $file"
        return 0
    fi
    
    local compress_format="$GLOBAL_COMPRESS_FORMAT"
    local compress_level="$GLOBAL_COMPRESS_LEVEL"
    
    log_message "INFO" "压缩日志文件: $file"
    
    case "$compress_format" in
        "gzip")
            gzip -"$compress_level" "$file"
            log_message "INFO" "使用gzip压缩完成: ${file}.gz"
            ;;
        "bzip2")
            bzip2 -"$compress_level" "$file"
            log_message "INFO" "使用bzip2压缩完成: ${file}.bz2"
            ;;
        "xz")
            xz -"$compress_level" "$file"
            log_message "INFO" "使用xz压缩完成: ${file}.xz"
            ;;
        *)
            log_message "WARNING" "未知的压缩格式: $compress_format"
            ;;
    esac
}

# 执行后处理脚本
execute_postrotate() {
    local config="$1"
    
    # 提取postrotate脚本
    local postrotate_script=$(echo "$config" | sed -n '/postrotate/,/endscript/p' | sed '1d;$d')
    
    if [ -n "$postrotate_script" ]; then
        log_message "INFO" "执行后处理脚本"
        
        if [ "$DRY_RUN" = true ]; then
            log_message "INFO" "[DRY RUN] 将执行: $postrotate_script"
        else
            eval "$postrotate_script"
            log_message "INFO" "后处理脚本执行完成"
        fi
    fi
}

# 清理旧日志文件
cleanup_old_logs() {
    local pattern="$1"
    local retention_days="$GLOBAL_RETENTION_DAYS"
    
    log_message "INFO" "清理旧日志文件: $pattern (保留 $retention_days 天)"
    
    # 查找并删除旧文件
    find "$(dirname "$pattern")" -name "$(basename "$pattern")*" -type f -mtime +$retention_days | while read -r old_file; do
        if [ "$DRY_RUN" = true ]; then
            log_message "INFO" "[DRY RUN] 将删除旧文件: $old_file"
        else
            rm -f "$old_file"
            log_message "INFO" "删除旧文件: $old_file"
        fi
    done
}

# 处理配置文件
process_config_file() {
    local config_file="$1"
    
    log_message "INFO" "处理配置文件: $config_file"
    
    # 读取配置文件内容
    local config_content=$(cat "$config_file")
    
    # 提取日志文件模式和配置
    echo "$config_content" | while IFS= read -r line; do
        # 跳过注释和空行
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$line" ]]; then
            continue
        fi
        
        # 检查是否是日志文件模式行
        if [[ "$line" =~ ^[[:space:]]*/.* ]]; then
            local log_pattern=$(echo "$line" | awk '{print $1}')
            
            # 读取配置块
            local config_block=""
            while IFS= read -r config_line; do
                if [[ "$config_line" =~ ^[[:space:]]*} ]]; then
                    break
                fi
                config_block+="$config_line"$'\n'
            done
            
            # 处理匹配的日志文件
            for log_file in $log_pattern; do
                if [ -f "$log_file" ]; then
                    if need_rotation "$log_file" "$config_block"; then
                        rotate_log "$log_file" "$config_block"
                    fi
                    cleanup_old_logs "$log_file"
                fi
            done
        fi
    done
}

# 显示帮助信息
show_help() {
    cat << EOF
日志轮转工具

用法: $0 [选项]

选项:
    -c, --config FILE    指定配置文件
    -d, --dry-run        试运行模式，不实际执行操作
    -f, --force          强制轮转所有日志
    -v, --verbose        详细输出
    -h, --help           显示此帮助信息

示例:
    $0                   # 使用默认配置运行
    $0 -d                # 试运行模式
    $0 -c /etc/logrotate.conf  # 使用指定配置文件
EOF
}

# 主函数
main() {
    local force_rotation=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                force_rotation=true
                shift
                ;;
            -v|--verbose)
                set -x
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    log_message "INFO" "开始日志轮转任务"
    
    if [ "$DRY_RUN" = true ]; then
        log_message "INFO" "运行在试运行模式"
    fi
    
    # 加载配置
    load_config
    
    # 创建必要的目录
    mkdir -p "$ARCHIVE_DIR"
    
    # 处理配置目录中的所有配置文件
    if [ -d "$CONFIG_DIR" ]; then
        for config_file in "$CONFIG_DIR"/*.conf; do
            if [ -f "$config_file" ]; then
                process_config_file "$config_file"
            fi
        done
    fi
    
    log_message "INFO" "日志轮转任务完成"
}

# 运行主函数
main "$@"