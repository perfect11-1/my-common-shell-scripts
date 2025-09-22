#!/bin/bash

# =============================================================================
# 案例5: 定时任务中的异常捕获
# 功能: 演示在定时任务(cron)环境中使用trap进行异常处理和监控
# 使用场景: 定时备份、日志清理、系统监控、数据同步等定时任务
# =============================================================================

set -euo pipefail

# 配置参数
SCRIPT_NAME=$(basename "$0")
LOCK_DIR="/tmp/${SCRIPT_NAME%.*}_locks"
LOG_DIR="/var/log/${SCRIPT_NAME%.*}"
WORK_DIR="/tmp/${SCRIPT_NAME%.*}_work"
CONFIG_FILE="/etc/${SCRIPT_NAME%.*}.conf"

# 运行时配置
MAX_RUNTIME=${MAX_RUNTIME:-3600}  # 最大运行时间(秒)
RETRY_COUNT=${RETRY_COUNT:-3}     # 重试次数
RETRY_DELAY=${RETRY_DELAY:-60}    # 重试间隔(秒)
ALERT_EMAIL=${ALERT_EMAIL:-""}    # 告警邮箱
ENABLE_MONITORING=${ENABLE_MONITORING:-1}  # 启用监控

# 全局状态变量
START_TIME=$(date +%s)
SCRIPT_PID=$$
LOCK_FILE="$LOCK_DIR/${SCRIPT_NAME%.*}.lock"
LOG_FILE="$LOG_DIR/${SCRIPT_NAME%.*}_$(date +%Y%m%d).log"
ERROR_LOG="$LOG_DIR/${SCRIPT_NAME%.*}_error.log"
METRICS_FILE="$LOG_DIR/${SCRIPT_NAME%.*}_metrics.log"

# 任务状态
CURRENT_TASK=""
TASK_COUNT=0
ERROR_COUNT=0
WARNING_COUNT=0
LAST_SUCCESS_TIME=""
CLEANUP_NEEDED=false

# 临时文件列表
TEMP_FILES=()
BACKGROUND_PIDS=()

# 颜色定义 (在cron环境中通常不需要，但保留用于手动执行)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    PURPLE=''
    CYAN=''
    NC=''
fi

# =============================================================================
# 日志和通知函数
# =============================================================================

# 标准日志函数
log() {
    local level="$1"
    shift
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[$timestamp] [$level] [PID:$SCRIPT_PID] $*"
    
    echo "$message" >> "$LOG_FILE"
    
    # 如果是交互式终端，也输出到屏幕
    if [[ -t 1 ]]; then
        case "$level" in
            "ERROR")   echo -e "${RED}$message${NC}" >&2 ;;
            "WARN")    echo -e "${YELLOW}$message${NC}" >&2 ;;
            "SUCCESS") echo -e "${GREEN}$message${NC}" ;;
            "INFO")    echo -e "${BLUE}$message${NC}" ;;
            *)         echo "$message" ;;
        esac
    fi
}

# 专用日志函数
log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; ((WARNING_COUNT++)); }
log_error() { log "ERROR" "$@"; echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$ERROR_LOG"; ((ERROR_COUNT++)); }
log_success() { log "SUCCESS" "$@"; }

# 记录性能指标
log_metrics() {
    local metric_name="$1"
    local metric_value="$2"
    local timestamp=$(date +%s)
    
    echo "$timestamp,$metric_name,$metric_value" >> "$METRICS_FILE"
}

# 发送告警通知
send_alert() {
    local subject="$1"
    local message="$2"
    local priority="${3:-normal}"
    
    log_error "ALERT: $subject - $message"
    
    # 如果配置了邮箱，发送邮件告警
    if [[ -n "$ALERT_EMAIL" ]] && command -v mail >/dev/null 2>&1; then
        {
            echo "主机: $(hostname)"
            echo "时间: $(date)"
            echo "脚本: $0"
            echo "PID: $SCRIPT_PID"
            echo "任务: $CURRENT_TASK"
            echo ""
            echo "详细信息:"
            echo "$message"
            echo ""
            echo "最近的日志:"
            tail -20 "$LOG_FILE" 2>/dev/null || echo "无法读取日志文件"
        } | mail -s "[$priority] $subject" "$ALERT_EMAIL"
        
        log_info "告警邮件已发送到: $ALERT_EMAIL"
    fi
    
    # 系统日志
    if command -v logger >/dev/null 2>&1; then
        logger -t "$SCRIPT_NAME" -p user.err "$subject: $message"
    fi
}

# =============================================================================
# 锁管理函数
# =============================================================================

# 获取执行锁
acquire_lock() {
    mkdir -p "$LOCK_DIR"
    
    # 检查是否已有锁文件
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid
        lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        
        # 检查进程是否还在运行
        if [[ -n "$lock_pid" ]] && kill -0 "$lock_pid" 2>/dev/null; then
            log_error "脚本已在运行中 (PID: $lock_pid)"
            exit 1
        else
            log_warn "发现僵尸锁文件，清理中..."
            rm -f "$LOCK_FILE"
        fi
    fi
    
    # 创建锁文件
    echo "$SCRIPT_PID" > "$LOCK_FILE"
    log_info "获取执行锁成功 (PID: $SCRIPT_PID)"
}

# 释放执行锁
release_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid
        lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        
        if [[ "$lock_pid" == "$SCRIPT_PID" ]]; then
            rm -f "$LOCK_FILE"
            log_info "执行锁已释放"
        else
            log_warn "锁文件PID不匹配，可能被其他进程修改"
        fi
    fi
}

# =============================================================================
# 超时和监控函数
# =============================================================================

# 启动超时监控
start_timeout_monitor() {
    if [[ $ENABLE_MONITORING -eq 1 ]]; then
        (
            sleep "$MAX_RUNTIME"
            if kill -0 "$SCRIPT_PID" 2>/dev/null; then
                log_error "脚本运行超时 (${MAX_RUNTIME}秒)，强制终止"
                send_alert "脚本运行超时" "脚本运行时间超过 $MAX_RUNTIME 秒，已被强制终止"
                kill -TERM "$SCRIPT_PID" 2>/dev/null || kill -KILL "$SCRIPT_PID" 2>/dev/null
            fi
        ) &
        
        local monitor_pid=$!
        BACKGROUND_PIDS+=($monitor_pid)
        log_info "超时监控已启动 (PID: $monitor_pid, 超时: ${MAX_RUNTIME}秒)"
    fi
}

# 启动资源监控
start_resource_monitor() {
    if [[ $ENABLE_MONITORING -eq 1 ]]; then
        (
            while kill -0 "$SCRIPT_PID" 2>/dev/null; do
                # 监控内存使用
                local memory_usage
                memory_usage=$(ps -o rss= -p "$SCRIPT_PID" 2>/dev/null || echo "0")
                log_metrics "memory_usage_kb" "$memory_usage"
                
                # 监控CPU使用 (需要一段时间来计算)
                local cpu_usage
                cpu_usage=$(ps -o %cpu= -p "$SCRIPT_PID" 2>/dev/null || echo "0")
                log_metrics "cpu_usage_percent" "$cpu_usage"
                
                # 监控磁盘空间
                local disk_usage
                disk_usage=$(df "$WORK_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
                log_metrics "disk_usage_percent" "$disk_usage"
                
                sleep 30
            done
        ) &
        
        local monitor_pid=$!
        BACKGROUND_PIDS+=($monitor_pid)
        log_info "资源监控已启动 (PID: $monitor_pid)"
    fi
}

# =============================================================================
# 异常处理函数
# =============================================================================

# 通用错误处理
handle_error() {
    local exit_code=$?
    local line_number=$1
    local command="$LAST_COMMAND"
    
    log_error "脚本在第 $line_number 行发生错误"
    log_error "错误命令: $command"
    log_error "退出代码: $exit_code"
    log_error "当前任务: ${CURRENT_TASK:-"未知"}"
    
    # 记录调用栈
    log_error "调用栈:"
    local i=1
    while [[ ${FUNCNAME[i]:-} ]]; do
        log_error "  [$i] ${FUNCNAME[i]} (${BASH_SOURCE[i]}:${BASH_LINENO[i-1]})"
        ((i++))
    done
    
    # 发送告警
    send_alert "脚本执行错误" "脚本在第 $line_number 行发生错误，退出代码: $exit_code" "high"
    
    # 设置清理标志
    CLEANUP_NEEDED=true
    
    exit $exit_code
}

# 中断信号处理
handle_interrupt() {
    log_warn "收到中断信号，正在安全退出..."
    
    if [[ -n "$CURRENT_TASK" ]]; then
        log_warn "当前任务: $CURRENT_TASK"
        log_warn "等待当前任务完成..."
        
        # 给当前任务一些时间完成
        sleep 5
    fi
    
    send_alert "脚本被中断" "脚本收到中断信号，正在安全退出"
    CLEANUP_NEEDED=true
    exit 130
}

# 终止信号处理
handle_termination() {
    log_warn "收到终止信号，立即退出..."
    send_alert "脚本被终止" "脚本收到终止信号，立即退出"
    CLEANUP_NEEDED=true
    exit 143
}

# 用户信号处理 - 状态报告
handle_status_request() {
    log_info "收到状态查询请求"
    generate_status_report
}

# =============================================================================
# 任务执行函数
# =============================================================================

# 执行带重试的任务
execute_with_retry() {
    local task_name="$1"
    local task_command="$2"
    local max_retries="${3:-$RETRY_COUNT}"
    
    CURRENT_TASK="$task_name"
    log_info "开始执行任务: $task_name"
    
    local attempt=1
    local success=false
    
    while [[ $attempt -le $max_retries ]]; do
        log_info "任务 '$task_name' 第 $attempt 次尝试"
        
        if eval "$task_command"; then
            log_success "任务 '$task_name' 执行成功"
            success=true
            break
        else
            local exit_code=$?
            log_error "任务 '$task_name' 第 $attempt 次尝试失败 (退出代码: $exit_code)"
            
            if [[ $attempt -lt $max_retries ]]; then
                log_info "等待 $RETRY_DELAY 秒后重试..."
                sleep "$RETRY_DELAY"
            fi
        fi
        
        ((attempt++))
    done
    
    if [[ "$success" != true ]]; then
        log_error "任务 '$task_name' 在 $max_retries 次尝试后仍然失败"
        send_alert "任务执行失败" "任务 '$task_name' 在 $max_retries 次尝试后仍然失败"
        return 1
    fi
    
    ((TASK_COUNT++))
    CURRENT_TASK=""
    return 0
}

# =============================================================================
# 示例任务函数
# =============================================================================

# 系统健康检查
task_system_health_check() {
    log_info "执行系统健康检查..."
    
    # 检查磁盘空间
    local disk_usage
    disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [[ $disk_usage -gt 90 ]]; then
        log_error "根分区磁盘使用率过高: ${disk_usage}%"
        return 1
    fi
    
    log_metrics "root_disk_usage" "$disk_usage"
    
    # 检查内存使用
    local memory_usage
    memory_usage=$(free | awk 'NR==2{printf "%.2f", $3*100/$2}')
    
    if (( $(echo "$memory_usage > 95" | bc -l) )); then
        log_error "内存使用率过高: ${memory_usage}%"
        return 1
    fi
    
    log_metrics "memory_usage" "$memory_usage"
    
    # 检查负载
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    
    log_metrics "load_average" "$load_avg"
    
    log_success "系统健康检查完成"
    return 0
}

# 日志清理任务
task_log_cleanup() {
    log_info "执行日志清理..."
    
    local log_dirs=("/var/log" "/tmp")
    local days_to_keep=7
    local cleaned_files=0
    
    for log_dir in "${log_dirs[@]}"; do
        if [[ -d "$log_dir" ]]; then
            # 查找并删除旧日志文件
            while IFS= read -r -d '' file; do
                rm -f "$file"
                ((cleaned_files++))
                log_info "删除旧日志文件: $file"
            done < <(find "$log_dir" -name "*.log" -type f -mtime +$days_to_keep -print0 2>/dev/null)
        fi
    done
    
    log_metrics "cleaned_log_files" "$cleaned_files"
    log_success "日志清理完成，清理了 $cleaned_files 个文件"
    return 0
}

# 数据备份任务
task_data_backup() {
    log_info "执行数据备份..."
    
    local source_dir="/important/data"
    local backup_dir="/backup/$(date +%Y%m%d)"
    local temp_backup="/tmp/backup_$$.tar.gz"
    
    # 添加到临时文件列表
    TEMP_FILES+=("$temp_backup")
    
    # 创建备份目录
    mkdir -p "$backup_dir"
    
    # 创建备份 (模拟)
    if [[ -d "$source_dir" ]]; then
        tar -czf "$temp_backup" -C "$(dirname "$source_dir")" "$(basename "$source_dir")" 2>/dev/null || {
            log_error "创建备份文件失败"
            return 1
        }
    else
        # 模拟备份创建
        echo "模拟备份数据" > "$temp_backup"
    fi
    
    # 移动到最终位置
    mv "$temp_backup" "$backup_dir/data_backup_$(date +%H%M%S).tar.gz"
    
    # 从临时文件列表中移除
    TEMP_FILES=("${TEMP_FILES[@]/$temp_backup}")
    
    local backup_size
    backup_size=$(du -sh "$backup_dir" | awk '{print $1}')
    
    log_metrics "backup_size" "$backup_size"
    log_success "数据备份完成，大小: $backup_size"
    return 0
}

# 网络连接检查
task_network_check() {
    log_info "执行网络连接检查..."
    
    local test_hosts=("8.8.8.8" "google.com" "github.com")
    local failed_hosts=()
    
    for host in "${test_hosts[@]}"; do
        if ! ping -c 1 -W 5 "$host" >/dev/null 2>&1; then
            failed_hosts+=("$host")
            log_warn "无法连接到: $host"
        else
            log_info "连接正常: $host"
        fi
    done
    
    local success_rate=$(( (${#test_hosts[@]} - ${#failed_hosts[@]}) * 100 / ${#test_hosts[@]} ))
    log_metrics "network_success_rate" "$success_rate"
    
    if [[ ${#failed_hosts[@]} -gt 0 ]]; then
        log_error "网络连接检查失败，无法连接的主机: ${failed_hosts[*]}"
        return 1
    fi
    
    log_success "网络连接检查完成"
    return 0
}

# =============================================================================
# 状态报告和清理函数
# =============================================================================

# 生成状态报告
generate_status_report() {
    local current_time=$(date +%s)
    local runtime=$((current_time - START_TIME))
    local hours=$((runtime / 3600))
    local minutes=$(((runtime % 3600) / 60))
    local seconds=$((runtime % 60))
    
    {
        echo "==================== 定时任务状态报告 ===================="
        echo "脚本名称: $SCRIPT_NAME"
        echo "进程ID: $SCRIPT_PID"
        echo "开始时间: $(date -d "@$START_TIME" '+%Y-%m-%d %H:%M:%S')"
        echo "运行时间: ${hours}h ${minutes}m ${seconds}s"
        echo "当前任务: ${CURRENT_TASK:-"空闲"}"
        echo ""
        echo "执行统计:"
        echo "  已完成任务: $TASK_COUNT"
        echo "  错误次数: $ERROR_COUNT"
        echo "  警告次数: $WARNING_COUNT"
        echo ""
        echo "资源使用:"
        if command -v ps >/dev/null 2>&1; then
            echo "  内存使用: $(ps -o rss= -p $SCRIPT_PID 2>/dev/null || echo "N/A") KB"
            echo "  CPU使用: $(ps -o %cpu= -p $SCRIPT_PID 2>/dev/null || echo "N/A")%"
        fi
        echo ""
        echo "文件路径:"
        echo "  日志文件: $LOG_FILE"
        echo "  错误日志: $ERROR_LOG"
        echo "  指标文件: $METRICS_FILE"
        echo "  锁文件: $LOCK_FILE"
        echo "========================================================"
    } | tee -a "$LOG_FILE"
}

# 清理资源
cleanup_resources() {
    local exit_code=$?
    
    log_info "开始清理资源..."
    
    # 终止后台进程
    for pid in "${BACKGROUND_PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            log_info "终止后台进程: $pid"
            kill -TERM "$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null
        fi
    done
    
    # 清理临时文件
    for temp_file in "${TEMP_FILES[@]}"; do
        if [[ -f "$temp_file" ]]; then
            rm -f "$temp_file"
            log_info "删除临时文件: $temp_file"
        fi
    done
    
    # 释放锁
    release_lock
    
    # 记录最终统计
    local end_time=$(date +%s)
    local total_runtime=$((end_time - START_TIME))
    
    log_metrics "total_runtime" "$total_runtime"
    log_metrics "total_tasks" "$TASK_COUNT"
    log_metrics "total_errors" "$ERROR_COUNT"
    log_metrics "total_warnings" "$WARNING_COUNT"
    
    # 生成最终报告
    generate_status_report
    
    if [[ $exit_code -eq 0 && $ERROR_COUNT -eq 0 ]]; then
        LAST_SUCCESS_TIME=$(date '+%Y-%m-%d %H:%M:%S')
        log_success "脚本正常结束，运行时间: ${total_runtime}秒"
    else
        log_error "脚本异常结束，退出代码: $exit_code，错误数: $ERROR_COUNT"
        
        if [[ $CLEANUP_NEEDED == true ]]; then
            send_alert "脚本异常结束" "脚本因错误或信号而异常结束，请检查日志文件"
        fi
    fi
    
    exit $exit_code
}

# =============================================================================
# 主程序
# =============================================================================

main() {
    # 创建必要的目录
    mkdir -p "$LOG_DIR" "$WORK_DIR"
    
    # 显示启动信息
    log_info "==================== 定时任务开始 ===================="
    log_info "脚本: $SCRIPT_NAME"
    log_info "PID: $SCRIPT_PID"
    log_info "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "工作目录: $WORK_DIR"
    log_info "日志目录: $LOG_DIR"
    log_info "最大运行时间: $MAX_RUNTIME 秒"
    log_info "重试次数: $RETRY_COUNT"
    log_info "======================================================="
    
    # 获取执行锁
    acquire_lock
    
    # 启动监控
    start_timeout_monitor
    start_resource_monitor
    
    # 执行任务列表
    local tasks=(
        "系统健康检查:task_system_health_check"
        "网络连接检查:task_network_check"
        "日志清理:task_log_cleanup"
        "数据备份:task_data_backup"
    )
    
    log_info "开始执行 ${#tasks[@]} 个任务..."
    
    for task_info in "${tasks[@]}"; do
        local task_name="${task_info%:*}"
        local task_function="${task_info#*:}"
        
        if ! execute_with_retry "$task_name" "$task_function"; then
            log_error "关键任务失败: $task_name"
            # 根据任务重要性决定是否继续
            # 这里我们继续执行其他任务
        fi
        
        # 任务间隔
        sleep 2
    done
    
    log_success "所有任务执行完成"
    log_info "总计完成 $TASK_COUNT 个任务，$ERROR_COUNT 个错误，$WARNING_COUNT 个警告"
}

# =============================================================================
# 信号处理注册和脚本入口
# =============================================================================

# 注册信号处理器
trap 'handle_error $LINENO' ERR
trap handle_interrupt INT
trap handle_termination TERM
trap handle_status_request USR1
trap cleanup_resources EXIT

# 记录每个命令 (用于错误报告)
trap 'LAST_COMMAND=$BASH_COMMAND' DEBUG

# 检查运行环境
if [[ $EUID -eq 0 ]]; then
    log_warn "脚本以root权限运行"
fi

# 检查必要的命令
for cmd in date mkdir rm kill ps; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "缺少必要的命令: $cmd"
        exit 1
    fi
done

# 显示帮助信息
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat << EOF
定时任务监控脚本

用法: $0 [选项]

选项:
  -h, --help              显示此帮助信息
  --status               显示当前状态
  --test                 测试模式运行

环境变量:
  MAX_RUNTIME=N          最大运行时间(秒，默认: 3600)
  RETRY_COUNT=N          重试次数(默认: 3)
  RETRY_DELAY=N          重试间隔(秒，默认: 60)
  ALERT_EMAIL=email      告警邮箱地址
  ENABLE_MONITORING=0|1  启用/禁用监控(默认: 1)

文件位置:
  日志目录: $LOG_DIR
  工作目录: $WORK_DIR
  锁目录: $LOCK_DIR

信号处理:
  USR1: 显示状态报告
  INT/TERM: 安全退出

示例cron配置:
  # 每小时执行一次
  0 * * * * $0 >/dev/null 2>&1
  
  # 每天凌晨2点执行
  0 2 * * * $0 >/dev/null 2>&1
EOF
    exit 0
fi

# 状态查询
if [[ "${1:-}" == "--status" ]]; then
    if [[ -f "$LOCK_FILE" ]]; then
        local running_pid
        running_pid=$(cat "$LOCK_FILE")
        if kill -0 "$running_pid" 2>/dev/null; then
            echo "脚本正在运行 (PID: $running_pid)"
            kill -USR1 "$running_pid"
        else
            echo "发现僵尸锁文件，脚本未运行"
        fi
    else
        echo "脚本未运行"
    fi
    exit 0
fi

# 测试模式
if [[ "${1:-}" == "--test" ]]; then
    log_info "测试模式运行"
    MAX_RUNTIME=60
    RETRY_COUNT=1
    ENABLE_MONITORING=0
fi

# 执行主程序
main "$@"