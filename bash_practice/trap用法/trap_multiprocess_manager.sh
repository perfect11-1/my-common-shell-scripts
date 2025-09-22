#!/bin/bash

# =============================================================================
# 案例4: 多进程管理中的信号处理
# 功能: 演示如何使用trap管理多个子进程，实现进程池和任务调度
# 使用场景: 并行处理、任务队列、服务管理、批量数据处理
# =============================================================================

set -euo pipefail

# 进程管理配置
MAX_WORKERS=${MAX_WORKERS:-4}
TASK_QUEUE_SIZE=${TASK_QUEUE_SIZE:-20}
WORKER_TIMEOUT=${WORKER_TIMEOUT:-30}
HEARTBEAT_INTERVAL=${HEARTBEAT_INTERVAL:-5}

# 全局状态变量
declare -A WORKER_PIDS=()
declare -A WORKER_STATUS=()
declare -A WORKER_START_TIME=()
declare -A WORKER_TASK_COUNT=()
declare -a TASK_QUEUE=()
declare -a COMPLETED_TASKS=()
declare -a FAILED_TASKS=()

MANAGER_PID=$$
RUNNING=true
TOTAL_TASKS=0
PROCESSED_TASKS=0
FAILED_TASK_COUNT=0

# 文件路径
WORK_DIR="/tmp/multiprocess_demo_$$"
PID_FILE="$WORK_DIR/manager.pid"
LOG_FILE="$WORK_DIR/manager.log"
TASK_DIR="$WORK_DIR/tasks"
RESULT_DIR="$WORK_DIR/results"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# =============================================================================
# 日志和输出函数
# =============================================================================

log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[$timestamp] [MANAGER:$$] $*"
    echo -e "${BLUE}$message${NC}"
    echo "$message" >> "$LOG_FILE"
}

worker_log() {
    local worker_id="$1"
    shift
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[$timestamp] [WORKER:$worker_id] $*"
    echo -e "${CYAN}$message${NC}"
    echo "$message" >> "$LOG_FILE"
}

error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[$timestamp] [ERROR] $*"
    echo -e "${RED}$message${NC}" >&2
    echo "$message" >> "$LOG_FILE"
}

success() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[$timestamp] [SUCCESS] $*"
    echo -e "${GREEN}$message${NC}"
    echo "$message" >> "$LOG_FILE"
}

warn() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[$timestamp] [WARNING] $*"
    echo -e "${YELLOW}$message${NC}" >&2
    echo "$message" >> "$LOG_FILE"
}

# =============================================================================
# 进程管理函数
# =============================================================================

# 初始化工作环境
initialize_workspace() {
    mkdir -p "$WORK_DIR" "$TASK_DIR" "$RESULT_DIR"
    echo $$ > "$PID_FILE"
    
    log "工作空间初始化完成: $WORK_DIR"
    log "最大工作进程数: $MAX_WORKERS"
    log "任务队列大小: $TASK_QUEUE_SIZE"
}

# 创建工作进程
create_worker() {
    local worker_id="$1"
    
    # 工作进程函数
    worker_process() {
        local id="$1"
        local task_count=0
        
        # 工作进程的信号处理
        worker_cleanup() {
            worker_log "$id" "工作进程退出，已处理 $task_count 个任务"
            exit 0
        }
        
        worker_interrupt() {
            worker_log "$id" "收到中断信号，正在安全退出..."
            exit 130
        }
        
        trap worker_cleanup EXIT
        trap worker_interrupt INT TERM
        
        worker_log "$id" "工作进程启动"
        
        # 工作循环
        while true; do
            # 检查是否有任务
            local task_file="$TASK_DIR/task_${id}_$(date +%s%N).task"
            
            # 等待任务分配
            while [[ ! -f "$task_file" && ! -f "$WORK_DIR/shutdown" ]]; do
                sleep 0.1
            done
            
            # 检查是否需要关闭
            if [[ -f "$WORK_DIR/shutdown" ]]; then
                worker_log "$id" "收到关闭信号"
                break
            fi
            
            # 处理任务
            if [[ -f "$task_file" ]]; then
                local task_data
                task_data=$(cat "$task_file")
                rm -f "$task_file"
                
                worker_log "$id" "开始处理任务: $task_data"
                
                # 模拟任务处理
                local start_time=$(date +%s)
                local success=true
                
                # 根据任务类型执行不同的处理逻辑
                case "$task_data" in
                    "cpu_intensive:"*)
                        # CPU密集型任务
                        local iterations=${task_data#cpu_intensive:}
                        local result=0
                        for ((i=0; i<iterations; i++)); do
                            result=$((result + i * i))
                        done
                        echo "CPU任务结果: $result" > "$RESULT_DIR/result_${id}_${start_time}.txt"
                        ;;
                    "io_intensive:"*)
                        # I/O密集型任务
                        local file_count=${task_data#io_intensive:}
                        for ((i=0; i<file_count; i++)); do
                            echo "数据行 $i" >> "$RESULT_DIR/io_result_${id}_${start_time}.txt"
                            sleep 0.01
                        done
                        ;;
                    "network_simulation:"*)
                        # 网络模拟任务
                        local delay=${task_data#network_simulation:}
                        sleep "$delay"
                        echo "网络任务完成" > "$RESULT_DIR/network_result_${id}_${start_time}.txt"
                        ;;
                    "error_task")
                        # 模拟错误任务
                        worker_log "$id" "模拟任务失败"
                        success=false
                        ;;
                    *)
                        # 默认任务
                        sleep 1
                        echo "默认任务完成: $task_data" > "$RESULT_DIR/default_result_${id}_${start_time}.txt"
                        ;;
                esac
                
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                
                if [[ "$success" == true ]]; then
                    worker_log "$id" "任务完成: $task_data (耗时: ${duration}s)"
                    echo "SUCCESS:$task_data:$duration" > "$WORK_DIR/completed_${id}_${start_time}.result"
                else
                    worker_log "$id" "任务失败: $task_data"
                    echo "FAILED:$task_data:$duration" > "$WORK_DIR/failed_${id}_${start_time}.result"
                fi
                
                ((task_count++))
            fi
        done
    }
    
    # 启动工作进程
    worker_process "$worker_id" &
    local worker_pid=$!
    
    WORKER_PIDS["$worker_id"]=$worker_pid
    WORKER_STATUS["$worker_id"]="running"
    WORKER_START_TIME["$worker_id"]=$(date +%s)
    WORKER_TASK_COUNT["$worker_id"]=0
    
    log "启动工作进程 $worker_id (PID: $worker_pid)"
}

# 分配任务给工作进程
assign_task() {
    local task="$1"
    
    # 寻找空闲的工作进程
    for worker_id in "${!WORKER_PIDS[@]}"; do
        local worker_pid="${WORKER_PIDS[$worker_id]}"
        
        # 检查进程是否还在运行
        if ! kill -0 "$worker_pid" 2>/dev/null; then
            warn "工作进程 $worker_id (PID: $worker_pid) 已停止"
            unset WORKER_PIDS["$worker_id"]
            unset WORKER_STATUS["$worker_id"]
            continue
        fi
        
        # 检查是否有空闲的工作进程
        local task_file="$TASK_DIR/task_${worker_id}_$(date +%s%N).task"
        if [[ ! -f "$task_file" ]]; then
            echo "$task" > "$task_file"
            log "任务已分配给工作进程 $worker_id: $task"
            return 0
        fi
    done
    
    # 没有空闲进程，任务放回队列
    return 1
}

# 监控工作进程状态
monitor_workers() {
    local active_workers=0
    
    for worker_id in "${!WORKER_PIDS[@]}"; do
        local worker_pid="${WORKER_PIDS[$worker_id]}"
        
        if kill -0 "$worker_pid" 2>/dev/null; then
            ((active_workers++))
            WORKER_STATUS["$worker_id"]="running"
        else
            warn "检测到工作进程 $worker_id 异常退出"
            WORKER_STATUS["$worker_id"]="stopped"
            
            # 重启工作进程
            if [[ "$RUNNING" == true ]]; then
                log "重启工作进程 $worker_id"
                unset WORKER_PIDS["$worker_id"]
                create_worker "$worker_id"
            fi
        fi
    done
    
    return $active_workers
}

# 收集任务结果
collect_results() {
    # 收集完成的任务
    for result_file in "$WORK_DIR"/completed_*.result; do
        [[ -f "$result_file" ]] || continue
        
        local result_data
        result_data=$(cat "$result_file")
        COMPLETED_TASKS+=("$result_data")
        rm -f "$result_file"
        ((PROCESSED_TASKS++))
    done
    
    # 收集失败的任务
    for result_file in "$WORK_DIR"/failed_*.result; do
        [[ -f "$result_file" ]] || continue
        
        local result_data
        result_data=$(cat "$result_file")
        FAILED_TASKS+=("$result_data")
        rm -f "$result_file"
        ((FAILED_TASK_COUNT++))
        ((PROCESSED_TASKS++))
    done
}

# =============================================================================
# 信号处理函数
# =============================================================================

# 优雅关闭处理
graceful_shutdown() {
    warn "收到关闭信号，开始优雅关闭..."
    RUNNING=false
    
    # 创建关闭标志文件
    touch "$WORK_DIR/shutdown"
    
    log "等待工作进程完成当前任务..."
    
    # 等待所有工作进程结束
    local timeout=30
    local waited=0
    
    while [[ $waited -lt $timeout ]]; do
        local active_count=0
        
        for worker_id in "${!WORKER_PIDS[@]}"; do
            local worker_pid="${WORKER_PIDS[$worker_id]}"
            if kill -0 "$worker_pid" 2>/dev/null; then
                ((active_count++))
            fi
        done
        
        if [[ $active_count -eq 0 ]]; then
            break
        fi
        
        log "等待 $active_count 个工作进程结束... (${waited}s/${timeout}s)"
        sleep 2
        ((waited += 2))
    done
    
    # 强制终止剩余进程
    for worker_id in "${!WORKER_PIDS[@]}"; do
        local worker_pid="${WORKER_PIDS[$worker_id]}"
        if kill -0 "$worker_pid" 2>/dev/null; then
            warn "强制终止工作进程 $worker_id (PID: $worker_pid)"
            kill -TERM "$worker_pid" 2>/dev/null || true
        fi
    done
    
    # 最后的清理
    cleanup_and_exit 0
}

# 立即停止处理
immediate_shutdown() {
    error "收到立即停止信号！"
    RUNNING=false
    
    # 立即终止所有工作进程
    for worker_id in "${!WORKER_PIDS[@]}"; do
        local worker_pid="${WORKER_PIDS[$worker_id]}"
        if kill -0 "$worker_pid" 2>/dev/null; then
            error "立即终止工作进程 $worker_id (PID: $worker_pid)"
            kill -KILL "$worker_pid" 2>/dev/null || true
        fi
    done
    
    cleanup_and_exit 1
}

# 状态报告处理
status_report() {
    log "收到状态报告请求"
    show_status_report
}

# 重新加载配置
reload_config() {
    log "收到配置重载请求"
    
    # 这里可以重新读取配置文件
    log "配置重载完成"
}

# =============================================================================
# 状态显示函数
# =============================================================================

show_status_report() {
    collect_results
    
    echo
    echo -e "${WHITE}==================== 进程管理器状态报告 ====================${NC}"
    echo -e "${CYAN}管理器PID:${NC} $MANAGER_PID"
    echo -e "${CYAN}运行状态:${NC} $([ "$RUNNING" = true ] && echo "运行中" || echo "正在关闭")"
    echo -e "${CYAN}工作目录:${NC} $WORK_DIR"
    
    echo
    echo -e "${CYAN}任务统计:${NC}"
    echo -e "  总任务数: $TOTAL_TASKS"
    echo -e "  已处理: $PROCESSED_TASKS"
    echo -e "  队列中: ${#TASK_QUEUE[@]}"
    echo -e "  成功: $((PROCESSED_TASKS - FAILED_TASK_COUNT))"
    echo -e "  失败: $FAILED_TASK_COUNT"
    
    echo
    echo -e "${CYAN}工作进程状态:${NC}"
    for worker_id in "${!WORKER_PIDS[@]}"; do
        local worker_pid="${WORKER_PIDS[$worker_id]}"
        local status="${WORKER_STATUS[$worker_id]}"
        local start_time="${WORKER_START_TIME[$worker_id]}"
        local current_time=$(date +%s)
        local runtime=$((current_time - start_time))
        
        printf "  工作进程 %s: PID=%s, 状态=%s, 运行时间=%ds\n" \
               "$worker_id" "$worker_pid" "$status" "$runtime"
    done
    
    echo -e "${WHITE}=========================================================${NC}"
    echo
}

# =============================================================================
# 任务生成和管理
# =============================================================================

# 生成测试任务
generate_test_tasks() {
    local task_count="$1"
    
    log "生成 $task_count 个测试任务"
    
    for ((i=1; i<=task_count; i++)); do
        local task_type=$((RANDOM % 4))
        local task=""
        
        case $task_type in
            0)
                task="cpu_intensive:$((RANDOM % 1000 + 100))"
                ;;
            1)
                task="io_intensive:$((RANDOM % 50 + 10))"
                ;;
            2)
                task="network_simulation:$((RANDOM % 3 + 1))"
                ;;
            3)
                if [[ $((RANDOM % 10)) -eq 0 ]]; then
                    task="error_task"
                else
                    task="normal_task_$i"
                fi
                ;;
        esac
        
        TASK_QUEUE+=("$task")
        ((TOTAL_TASKS++))
    done
    
    log "任务生成完成，队列中有 ${#TASK_QUEUE[@]} 个任务"
}

# 任务调度循环
task_scheduler() {
    log "任务调度器启动"
    
    while [[ "$RUNNING" == true ]]; do
        # 收集结果
        collect_results
        
        # 监控工作进程
        monitor_workers
        
        # 分配任务
        if [[ ${#TASK_QUEUE[@]} -gt 0 ]]; then
            local task="${TASK_QUEUE[0]}"
            
            if assign_task "$task"; then
                # 任务分配成功，从队列中移除
                TASK_QUEUE=("${TASK_QUEUE[@]:1}")
            fi
        fi
        
        # 检查是否所有任务都完成
        if [[ ${#TASK_QUEUE[@]} -eq 0 && $PROCESSED_TASKS -eq $TOTAL_TASKS ]]; then
            log "所有任务已完成"
            break
        fi
        
        sleep 0.5
    done
    
    log "任务调度器结束"
}

# =============================================================================
# 清理函数
# =============================================================================

cleanup_and_exit() {
    local exit_code=${1:-0}
    
    log "开始清理资源..."
    
    # 收集最终结果
    collect_results
    
    # 显示最终统计
    echo
    echo -e "${GREEN}==================== 最终统计 ====================${NC}"
    echo -e "${CYAN}总任务数:${NC} $TOTAL_TASKS"
    echo -e "${CYAN}成功完成:${NC} $((PROCESSED_TASKS - FAILED_TASK_COUNT))"
    echo -e "${CYAN}失败任务:${NC} $FAILED_TASK_COUNT"
    echo -e "${CYAN}处理率:${NC} $(( TOTAL_TASKS > 0 ? (PROCESSED_TASKS * 100) / TOTAL_TASKS : 0 ))%"
    
    if [[ ${#COMPLETED_TASKS[@]} -gt 0 ]]; then
        echo -e "${CYAN}成功任务示例:${NC}"
        for ((i=0; i<5 && i<${#COMPLETED_TASKS[@]}; i++)); do
            echo "  ${COMPLETED_TASKS[i]}"
        done
    fi
    
    if [[ ${#FAILED_TASKS[@]} -gt 0 ]]; then
        echo -e "${CYAN}失败任务:${NC}"
        for task in "${FAILED_TASKS[@]}"; do
            echo "  $task"
        done
    fi
    
    echo -e "${GREEN}=================================================${NC}"
    
    # 清理工作目录
    if [[ -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR"
        log "工作目录已清理: $WORK_DIR"
    fi
    
    success "多进程管理器已退出 (退出码: $exit_code)"
    exit $exit_code
}

# =============================================================================
# 主程序
# =============================================================================

main() {
    # 显示程序信息
    cat << EOF

${PURPLE}================================================================================
                           多进程任务管理器
================================================================================${NC}

${CYAN}功能特性:${NC}
- 多进程并行任务处理
- 动态进程池管理
- 任务队列调度
- 进程监控和自动重启
- 优雅关闭和信号处理

${CYAN}配置参数:${NC}
- 最大工作进程: $MAX_WORKERS
- 任务队列大小: $TASK_QUEUE_SIZE
- 工作进程超时: $WORKER_TIMEOUT 秒
- 心跳检测间隔: $HEARTBEAT_INTERVAL 秒

${CYAN}控制命令 (在另一个终端执行):${NC}
- kill -USR1 $$  # 显示状态报告
- kill -USR2 $$  # 重新加载配置
- kill -TERM $$  # 优雅关闭
- kill -INT $$   # 中断 (Ctrl+C)

${CYAN}工作目录:${NC} $WORK_DIR

${PURPLE}================================================================================${NC}

EOF

    # 初始化
    initialize_workspace
    
    # 注册信号处理器
    trap graceful_shutdown TERM INT
    trap immediate_shutdown QUIT
    trap status_report USR1
    trap reload_config USR2
    trap cleanup_and_exit EXIT
    
    # 启动工作进程
    log "启动 $MAX_WORKERS 个工作进程..."
    for ((i=1; i<=MAX_WORKERS; i++)); do
        create_worker "$i"
        sleep 0.1
    done
    
    # 生成测试任务
    local task_count=${1:-50}
    generate_test_tasks "$task_count"
    
    # 启动任务调度器
    task_scheduler
    
    log "所有任务处理完成"
}

# =============================================================================
# 脚本入口
# =============================================================================

# 检查参数
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "用法: $0 [任务数量]"
    echo "环境变量:"
    echo "  MAX_WORKERS=N         最大工作进程数 (默认: 4)"
    echo "  TASK_QUEUE_SIZE=N     任务队列大小 (默认: 20)"
    echo "  WORKER_TIMEOUT=N      工作进程超时秒数 (默认: 30)"
    echo "  HEARTBEAT_INTERVAL=N  心跳检测间隔秒数 (默认: 5)"
    exit 0
fi

# 检查是否已有实例运行
if pgrep -f "$(basename "$0")" | grep -v $$ > /dev/null; then
    error "检测到其他实例正在运行"
    exit 1
fi

# 执行主程序
main "${1:-50}"