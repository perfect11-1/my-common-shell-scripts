#!/bin/bash

# =============================================================================
# 案例2: 捕获中断信号(如Ctrl+C)时的优雅处理
# 功能: 演示如何优雅地处理各种系统信号，实现平滑关闭
# 使用场景: 长时间运行的服务脚本、监控脚本、数据处理脚本
# =============================================================================

set -euo pipefail

# 全局状态变量
RUNNING=true
CURRENT_TASK=""
TASK_COUNT=0
START_TIME=$(date +%s)
PID_FILE="/tmp/signal_demo_$$.pid"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志函数
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}[$timestamp]${NC} $*"
}

warn() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[$timestamp] [WARNING]${NC} $*" >&2
}

error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[$timestamp] [ERROR]${NC} $*" >&2
}

success() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[$timestamp] [SUCCESS]${NC} $*"
}

info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${CYAN}[$timestamp] [INFO]${NC} $*"
}

# =============================================================================
# 信号处理函数
# =============================================================================

# SIGINT处理 (Ctrl+C)
handle_sigint() {
    echo  # 换行，因为Ctrl+C会在同一行
    warn "收到 SIGINT 信号 (Ctrl+C)"
    
    if [[ "$CURRENT_TASK" != "" ]]; then
        warn "当前正在执行: $CURRENT_TASK"
        warn "等待当前任务完成后退出..."
        RUNNING=false
    else
        warn "立即退出程序"
        cleanup_and_exit 130
    fi
}

# SIGTERM处理 (优雅关闭)
handle_sigterm() {
    warn "收到 SIGTERM 信号 (优雅关闭请求)"
    warn "开始优雅关闭流程..."
    RUNNING=false
}

# SIGUSR1处理 (用户自定义信号1 - 状态报告)
handle_sigusr1() {
    info "收到 SIGUSR1 信号 - 生成状态报告"
    show_status_report
}

# SIGUSR2处理 (用户自定义信号2 - 重新加载配置)
handle_sigusr2() {
    info "收到 SIGUSR2 信号 - 重新加载配置"
    reload_configuration
}

# SIGHUP处理 (挂起信号 - 通常用于重启服务)
handle_sighup() {
    info "收到 SIGHUP 信号 - 重启服务"
    warn "模拟服务重启..."
    # 在实际应用中，这里可能会重新加载配置或重启服务
    sleep 2
    success "服务重启完成"
}

# =============================================================================
# 辅助函数
# =============================================================================

# 显示状态报告
show_status_report() {
    local current_time=$(date +%s)
    local runtime=$((current_time - START_TIME))
    local hours=$((runtime / 3600))
    local minutes=$(((runtime % 3600) / 60))
    local seconds=$((runtime % 60))
    
    echo
    echo -e "${PURPLE}==================== 状态报告 ====================${NC}"
    echo -e "${CYAN}进程ID:${NC} $$"
    echo -e "${CYAN}运行时间:${NC} ${hours}h ${minutes}m ${seconds}s"
    echo -e "${CYAN}已完成任务:${NC} $TASK_COUNT"
    echo -e "${CYAN}当前任务:${NC} ${CURRENT_TASK:-"空闲"}"
    echo -e "${CYAN}运行状态:${NC} $([ "$RUNNING" = true ] && echo "运行中" || echo "准备退出")"
    echo -e "${CYAN}PID文件:${NC} $PID_FILE"
    echo -e "${PURPLE}=================================================${NC}"
    echo
}

# 重新加载配置
reload_configuration() {
    info "正在重新加载配置..."
    
    # 模拟配置重载过程
    local config_items=("数据库连接" "缓存设置" "日志级别" "监控参数" "安全策略")
    
    for item in "${config_items[@]}"; do
        echo -e "  ${CYAN}重载:${NC} $item"
        sleep 0.5
    done
    
    success "配置重载完成"
}

# 清理并退出
cleanup_and_exit() {
    local exit_code=${1:-0}
    
    info "开始清理资源..."
    
    # 清理PID文件
    if [[ -f "$PID_FILE" ]]; then
        rm -f "$PID_FILE"
        info "已删除PID文件: $PID_FILE"
    fi
    
    # 显示最终统计
    local end_time=$(date +%s)
    local total_runtime=$((end_time - START_TIME))
    
    echo
    echo -e "${GREEN}==================== 退出统计 ====================${NC}"
    echo -e "${CYAN}总运行时间:${NC} ${total_runtime}秒"
    echo -e "${CYAN}完成任务数:${NC} $TASK_COUNT"
    echo -e "${CYAN}退出代码:${NC} $exit_code"
    echo -e "${GREEN}=================================================${NC}"
    
    success "程序已安全退出"
    exit $exit_code
}

# =============================================================================
# 注册信号处理器
# =============================================================================

# 注册各种信号的处理函数
trap handle_sigint INT     # Ctrl+C
trap handle_sigterm TERM   # 优雅关闭
trap handle_sigusr1 USR1   # 状态报告
trap handle_sigusr2 USR2   # 重新加载配置
trap handle_sighup HUP     # 重启信号

# EXIT信号用于最终清理
trap 'cleanup_and_exit $?' EXIT

# =============================================================================
# 模拟工作任务
# =============================================================================

# 执行一个模拟任务
execute_task() {
    local task_name="$1"
    local duration="$2"
    
    CURRENT_TASK="$task_name"
    info "开始执行任务: $task_name (预计 ${duration}秒)"
    
    # 模拟任务执行，支持中断检查
    for ((i=1; i<=duration; i++)); do
        if [[ "$RUNNING" != true ]]; then
            warn "任务被中断: $task_name"
            return 1
        fi
        
        echo -e "  ${CYAN}进度:${NC} $task_name [$i/$duration]"
        sleep 1
    done
    
    CURRENT_TASK=""
    ((TASK_COUNT++))
    success "任务完成: $task_name"
    return 0
}

# =============================================================================
# 主程序
# =============================================================================

main() {
    # 创建PID文件
    echo $$ > "$PID_FILE"
    
    # 显示程序信息
    cat << EOF

${PURPLE}================================================================================
                           信号处理演示程序
================================================================================${NC}

${CYAN}程序功能:${NC}
- 演示各种信号的处理方式
- 支持优雅关闭和状态查询
- 模拟长时间运行的服务

${CYAN}支持的信号:${NC}
- ${YELLOW}SIGINT (Ctrl+C)${NC}  : 中断程序，等待当前任务完成
- ${YELLOW}SIGTERM${NC}          : 优雅关闭程序
- ${YELLOW}SIGUSR1${NC}          : 显示状态报告
- ${YELLOW}SIGUSR2${NC}          : 重新加载配置
- ${YELLOW}SIGHUP${NC}           : 重启服务

${CYAN}测试命令 (在另一个终端执行):${NC}
- kill -USR1 $$  # 查看状态
- kill -USR2 $$  # 重载配置
- kill -HUP $$   # 重启服务
- kill -TERM $$  # 优雅关闭
- kill -INT $$   # 中断 (或直接按 Ctrl+C)

${CYAN}进程ID:${NC} $$
${CYAN}PID文件:${NC} $PID_FILE

${PURPLE}================================================================================${NC}

EOF

    info "程序启动完成，开始执行任务循环..."
    
    # 任务列表
    local tasks=(
        "数据备份:8"
        "日志分析:6"
        "系统监控:4"
        "性能检测:5"
        "安全扫描:7"
        "报告生成:3"
    )
    
    local task_index=0
    
    # 主循环
    while [[ "$RUNNING" = true ]]; do
        # 获取当前任务
        local current_task_info="${tasks[$task_index]}"
        local task_name="${current_task_info%:*}"
        local task_duration="${current_task_info#*:}"
        
        # 执行任务
        if execute_task "$task_name" "$task_duration"; then
            info "等待下一个任务..."
            sleep 2
        fi
        
        # 循环任务列表
        task_index=$(((task_index + 1) % ${#tasks[@]}))
        
        # 检查是否需要退出
        if [[ "$RUNNING" != true ]]; then
            warn "收到退出信号，完成当前任务后退出"
            break
        fi
    done
    
    info "主循环结束，程序即将退出"
}

# =============================================================================
# 脚本入口
# =============================================================================

# 检查是否已有实例在运行
if pgrep -f "$(basename "$0")" | grep -v $$ > /dev/null; then
    error "检测到其他实例正在运行"
    echo "使用以下命令查看运行中的实例:"
    echo "  ps aux | grep $(basename "$0")"
    exit 1
fi

# 执行主程序
main "$@"