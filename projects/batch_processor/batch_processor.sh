#!/bin/bash

# 批量文件处理工具
# 作者: Shell脚本学习项目
# 版本: 1.0

set -euo pipefail

# 脚本目录和配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config/processor.conf"
MODULES_DIR="$SCRIPT_DIR/modules"
PLUGINS_DIR="$SCRIPT_DIR/plugins"
LOG_FILE="$SCRIPT_DIR/logs/processor.log"
OPERATIONS_LOG="$SCRIPT_DIR/logs/operations.log"
BACKUP_DIR="$SCRIPT_DIR/backup"

# 默认配置
MAX_PARALLEL_JOBS=4
ENABLE_PROGRESS_BAR=true
ENABLE_BACKUP=true
LOG_LEVEL="INFO"
DRY_RUN=false
CONFIRM_DESTRUCTIVE_OPERATIONS=true

# 全局变量
PROCESSED_COUNT=0
TOTAL_COUNT=0
OPERATION_ID=""

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

# 记录操作用于撤销
record_operation() {
    local operation="$1"
    local source="$2"
    local target="$3"
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    
    mkdir -p "$(dirname "$OPERATIONS_LOG")"
    echo "{\"id\":\"$OPERATION_ID\",\"timestamp\":\"$timestamp\",\"operation\":\"$operation\",\"source\":\"$source\",\"target\":\"$target\"}" >> "$OPERATIONS_LOG"
}

# 生成操作ID
generate_operation_id() {
    OPERATION_ID="op_$(date +%Y%m%d_%H%M%S)_$$"
}

# 显示进度条
show_progress() {
    if [ "$ENABLE_PROGRESS_BAR" = true ]; then
        local current="$1"
        local total="$2"
        local percent=$((current * 100 / total))
        local filled=$((percent / 2))
        local empty=$((50 - filled))
        
        printf "\r["
        printf "%*s" $filled | tr ' ' '='
        printf "%*s" $empty | tr ' ' '-'
        printf "] %d%% (%d/%d)" $percent $current $total
    fi
}

# 扫描文件
scan_files() {
    local directory="$1"
    local pattern="$2"
    local filters="$3"
    
    log_message "INFO" "扫描目录: $directory, 模式: $pattern"
    
    local files=()
    while IFS= read -r -d '' file; do
        if apply_filters "$file" "$filters"; then
            files+=("$file")
        fi
    done < <(find "$directory" -type f -name "$pattern" -print0)
    
    TOTAL_COUNT=${#files[@]}
    log_message "INFO" "找到 $TOTAL_COUNT 个匹配的文件"
    
    printf '%s\n' "${files[@]}"
}

# 应用过滤条件
apply_filters() {
    local file="$1"
    local filters="$2"
    
    if [ -z "$filters" ]; then
        return 0
    fi
    
    # 大小过滤
    if [[ "$filters" =~ size:([<>]=?)([0-9]+)([KMG]?) ]]; then
        local operator="${BASH_REMATCH[1]}"
        local size_value="${BASH_REMATCH[2]}"
        local size_unit="${BASH_REMATCH[3]}"
        
        if ! check_file_size "$file" "$operator" "$size_value" "$size_unit"; then
            return 1
        fi
    fi
    
    # 日期过滤
    if [[ "$filters" =~ date:([<>]=?)([0-9-]+) ]]; then
        local operator="${BASH_REMATCH[1]}"
        local date_value="${BASH_REMATCH[2]}"
        
        if ! check_file_date "$file" "$operator" "$date_value"; then
            return 1
        fi
    fi
    
    # 扩展名过滤
    if [[ "$filters" =~ ext:([a-zA-Z0-9,]+) ]]; then
        local extensions="${BASH_REMATCH[1]}"
        local file_ext="${file##*.}"
        
        if [[ ",$extensions," != *",$file_ext,"* ]]; then
            return 1
        fi
    fi
    
    return 0
}

# 检查文件大小
check_file_size() {
    local file="$1"
    local operator="$2"
    local size_value="$3"
    local size_unit="$4"
    
    local file_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    local limit_bytes=$size_value
    
    case "$size_unit" in
        "K") limit_bytes=$((size_value * 1024)) ;;
        "M") limit_bytes=$((size_value * 1024 * 1024)) ;;
        "G") limit_bytes=$((size_value * 1024 * 1024 * 1024)) ;;
    esac
    
    case "$operator" in
        ">") [ "$file_size" -gt "$limit_bytes" ] ;;
        ">=") [ "$file_size" -ge "$limit_bytes" ] ;;
        "<") [ "$file_size" -lt "$limit_bytes" ] ;;
        "<=") [ "$file_size" -le "$limit_bytes" ] ;;
        *) [ "$file_size" -eq "$limit_bytes" ] ;;
    esac
}

# 检查文件日期
check_file_date() {
    local file="$1"
    local operator="$2"
    local date_value="$3"
    
    local file_mtime=$(stat -c%Y "$file" 2>/dev/null || stat -f%m "$file" 2>/dev/null)
    local limit_timestamp=$(date -d "$date_value" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$date_value" +%s 2>/dev/null)
    
    case "$operator" in
        ">") [ "$file_mtime" -gt "$limit_timestamp" ] ;;
        ">=") [ "$file_mtime" -ge "$limit_timestamp" ] ;;
        "<") [ "$file_mtime" -lt "$limit_timestamp" ] ;;
        "<=") [ "$file_mtime" -le "$limit_timestamp" ] ;;
        *) [ "$file_mtime" -eq "$limit_timestamp" ] ;;
    esac
}

# 批量重命名
batch_rename() {
    local files=("$@")
    local rule="$2"
    local options="$3"
    
    log_message "INFO" "开始批量重命名，规则: $rule"
    
    for file in "${files[@]}"; do
        local new_name=$(apply_rename_rule "$file" "$rule" "$options")
        local new_path="$(dirname "$file")/$new_name"
        
        if [ "$file" != "$new_path" ]; then
            if [ "$DRY_RUN" = true ]; then
                log_message "INFO" "[DRY RUN] 重命名: $file -> $new_path"
            else
                if [ "$ENABLE_BACKUP" = true ]; then
                    create_backup "$file"
                fi
                
                mv "$file" "$new_path"
                record_operation "rename" "$file" "$new_path"
                log_message "INFO" "重命名: $file -> $new_path"
            fi
        fi
        
        ((PROCESSED_COUNT++))
        show_progress "$PROCESSED_COUNT" "$TOTAL_COUNT"
    done
    
    echo  # 换行
}

# 应用重命名规则
apply_rename_rule() {
    local file="$1"
    local rule="$2"
    local options="$3"
    
    local filename=$(basename "$file")
    local name="${filename%.*}"
    local ext="${filename##*.}"
    
    case "$rule" in
        "lowercase")
            echo "${filename,,}"
            ;;
        "uppercase")
            echo "${filename^^}"
            ;;
        "remove_spaces")
            echo "${filename// /_}"
            ;;
        "add_date_prefix")
            local date_format="${options:-YYYY-MM-DD}"
            local date_str=$(date "+%Y-%m-%d")
            echo "${date_str}_${filename}"
            ;;
        "add_sequence")
            local seq_num="${PROCESSED_COUNT:-1}"
            local seq_format="${options:-3d}"
            local seq_str=$(printf "%0${seq_format}d" "$seq_num")
            echo "${seq_str}_${filename}"
            ;;
        "clean_filename")
            # 清理特殊字符
            local clean_name=$(echo "$filename" | sed 's/[^a-zA-Z0-9._-]/_/g')
            echo "$clean_name"
            ;;
        *)
            echo "$filename"
            ;;
    esac
}

# 批量格式转换
batch_convert() {
    local files=("$@")
    local from_format="$2"
    local to_format="$3"
    local options="$4"
    
    log_message "INFO" "开始格式转换: $from_format -> $to_format"
    
    # 加载转换模块
    if [ -f "$MODULES_DIR/convert.sh" ]; then
        source "$MODULES_DIR/convert.sh"
    else
        log_message "ERROR" "转换模块不存在: $MODULES_DIR/convert.sh"
        return 1
    fi
    
    for file in "${files[@]}"; do
        local output_file="${file%.*}.$to_format"
        
        if [ "$DRY_RUN" = true ]; then
            log_message "INFO" "[DRY RUN] 转换: $file -> $output_file"
        else
            if convert_file "$file" "$output_file" "$from_format" "$to_format" "$options"; then
                record_operation "convert" "$file" "$output_file"
                log_message "INFO" "转换成功: $file -> $output_file"
            else
                log_message "ERROR" "转换失败: $file"
            fi
        fi
        
        ((PROCESSED_COUNT++))
        show_progress "$PROCESSED_COUNT" "$TOTAL_COUNT"
    done
    
    echo  # 换行
}

# 批量文件组织
batch_organize() {
    local files=("$@")
    local rule="$2"
    local target_dir="$3"
    
    log_message "INFO" "开始文件组织，规则: $rule"
    
    # 加载组织模块
    if [ -f "$MODULES_DIR/organize.sh" ]; then
        source "$MODULES_DIR/organize.sh"
    else
        log_message "ERROR" "组织模块不存在: $MODULES_DIR/organize.sh"
        return 1
    fi
    
    for file in "${files[@]}"; do
        local dest_path=$(get_organize_path "$file" "$rule" "$target_dir")
        
        if [ "$DRY_RUN" = true ]; then
            log_message "INFO" "[DRY RUN] 移动: $file -> $dest_path"
        else
            mkdir -p "$(dirname "$dest_path")"
            
            if [ "$ENABLE_BACKUP" = true ]; then
                create_backup "$file"
            fi
            
            mv "$file" "$dest_path"
            record_operation "move" "$file" "$dest_path"
            log_message "INFO" "移动: $file -> $dest_path"
        fi
        
        ((PROCESSED_COUNT++))
        show_progress "$PROCESSED_COUNT" "$TOTAL_COUNT"
    done
    
    echo  # 换行
}

# 创建备份
create_backup() {
    local file="$1"
    local backup_path="$BACKUP_DIR/$OPERATION_ID/$(dirname "$file")"
    
    mkdir -p "$backup_path"
    cp "$file" "$backup_path/"
    log_message "DEBUG" "创建备份: $file -> $backup_path/"
}

# 并行处理文件
process_files_parallel() {
    local operation="$1"
    shift
    local files=("$@")
    
    local job_count=0
    local batch_size=$((${#files[@]} / MAX_PARALLEL_JOBS))
    
    if [ "$batch_size" -lt 1 ]; then
        batch_size=1
    fi
    
    for ((i=0; i<${#files[@]}; i+=batch_size)); do
        local batch=("${files[@]:$i:$batch_size}")
        
        # 等待作业槽位
        while [ "$job_count" -ge "$MAX_PARALLEL_JOBS" ]; do
            wait -n
            ((job_count--))
        done
        
        # 启动新的处理作业
        case "$operation" in
            "rename")
                batch_rename "${batch[@]}" &
                ;;
            "convert")
                batch_convert "${batch[@]}" &
                ;;
            "organize")
                batch_organize "${batch[@]}" &
                ;;
        esac
        
        ((job_count++))
    done
    
    # 等待所有作业完成
    wait
}

# 撤销操作
undo_operations() {
    local operation_id="$1"
    
    log_message "INFO" "撤销操作: $operation_id"
    
    # 反向读取操作记录
    grep "\"id\":\"$operation_id\"" "$OPERATIONS_LOG" | tac | while IFS= read -r line; do
        local operation=$(echo "$line" | sed -n 's/.*"operation":"\([^"]*\)".*/\1/p')
        local source=$(echo "$line" | sed -n 's/.*"source":"\([^"]*\)".*/\1/p')
        local target=$(echo "$line" | sed -n 's/.*"target":"\([^"]*\)".*/\1/p')
        
        case "$operation" in
            "rename"|"move")
                if [ -f "$target" ]; then
                    mv "$target" "$source"
                    log_message "INFO" "撤销: $target -> $source"
                fi
                ;;
            "convert"|"copy")
                if [ -f "$target" ]; then
                    rm -f "$target"
                    log_message "INFO" "删除: $target"
                fi
                ;;
        esac
    done
}

# 显示帮助信息
show_help() {
    cat << EOF
批量文件处理工具

用法: $0 <操作> [选项] [参数]

操作:
    rename      批量重命名文件
    convert     批量格式转换
    organize    批量文件组织
    undo        撤销操作

重命名选项:
    --rule RULE         重命名规则 (lowercase, uppercase, remove_spaces, add_date_prefix, add_sequence, clean_filename)
    --options OPTIONS   规则选项

转换选项:
    --from FORMAT       源格式
    --to FORMAT         目标格式
    --options OPTIONS   转换选项

组织选项:
    --rule RULE         组织规则 (by_type, by_date, by_size)
    --target DIR        目标目录

通用选项:
    --directory DIR     处理目录
    --pattern PATTERN   文件模式 (默认: *)
    --filters FILTERS   过滤条件
    --parallel          启用并行处理
    --dry-run           试运行模式
    --backup            启用备份
    --no-confirm        跳过确认
    -v, --verbose       详细输出
    -h, --help          显示帮助

示例:
    $0 rename --rule lowercase --directory /path/to/files --pattern "*.JPG"
    $0 convert --from jpg --to png --directory /path/to/images
    $0 organize --rule by_type --target /path/to/organized --directory /path/to/files
    $0 undo op_20240115_143022_1234
EOF
}

# 主函数
main() {
    local operation=""
    local directory="."
    local pattern="*"
    local filters=""
    local rule=""
    local options=""
    local from_format=""
    local to_format=""
    local target_dir=""
    local parallel=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            rename|convert|organize|undo)
                operation="$1"
                shift
                ;;
            --directory)
                directory="$2"
                shift 2
                ;;
            --pattern)
                pattern="$2"
                shift 2
                ;;
            --filters)
                filters="$2"
                shift 2
                ;;
            --rule)
                rule="$2"
                shift 2
                ;;
            --options)
                options="$2"
                shift 2
                ;;
            --from)
                from_format="$2"
                shift 2
                ;;
            --to)
                to_format="$2"
                shift 2
                ;;
            --target)
                target_dir="$2"
                shift 2
                ;;
            --parallel)
                parallel=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --backup)
                ENABLE_BACKUP=true
                shift
                ;;
            --no-confirm)
                CONFIRM_DESTRUCTIVE_OPERATIONS=false
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
                if [ -z "$operation" ]; then
                    echo "未知操作: $1"
                    show_help
                    exit 1
                else
                    # 可能是撤销操作的ID
                    operation_id="$1"
                    shift
                fi
                ;;
        esac
    done
    
    if [ -z "$operation" ]; then
        echo "请指定操作"
        show_help
        exit 1
    fi
    
    # 加载配置
    load_config
    
    # 生成操作ID
    generate_operation_id
    
    log_message "INFO" "开始批量处理操作: $operation (ID: $OPERATION_ID)"
    
    case "$operation" in
        "undo")
            if [ -n "${operation_id:-}" ]; then
                undo_operations "$operation_id"
            else
                echo "请指定要撤销的操作ID"
                exit 1
            fi
            ;;
        *)
            # 扫描文件
            mapfile -t files < <(scan_files "$directory" "$pattern" "$filters")
            
            if [ ${#files[@]} -eq 0 ]; then
                log_message "WARNING" "没有找到匹配的文件"
                exit 0
            fi
            
            # 确认操作
            if [ "$CONFIRM_DESTRUCTIVE_OPERATIONS" = true ] && [ "$DRY_RUN" = false ]; then
                echo "将处理 ${#files[@]} 个文件，继续吗？ (y/N)"
                read -r confirm
                if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                    echo "操作已取消"
                    exit 0
                fi
            fi
            
            # 执行操作
            case "$operation" in
                "rename")
                    if [ "$parallel" = true ]; then
                        process_files_parallel "rename" "${files[@]}"
                    else
                        batch_rename "${files[@]}" "$rule" "$options"
                    fi
                    ;;
                "convert")
                    if [ "$parallel" = true ]; then
                        process_files_parallel "convert" "${files[@]}"
                    else
                        batch_convert "${files[@]}" "$from_format" "$to_format" "$options"
                    fi
                    ;;
                "organize")
                    if [ "$parallel" = true ]; then
                        process_files_parallel "organize" "${files[@]}"
                    else
                        batch_organize "${files[@]}" "$rule" "$target_dir"
                    fi
                    ;;
            esac
            ;;
    esac
    
    log_message "INFO" "批量处理完成 (ID: $OPERATION_ID)"
}

# 运行主函数
main "$@"