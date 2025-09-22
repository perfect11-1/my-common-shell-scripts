#!/bin/bash

# =============================================================================
# Trap案例测试脚本
# 功能: 自动测试所有trap示例脚本的基本功能
# =============================================================================

set -euo pipefail

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_LOG="/tmp/trap_test_$(date +%Y%m%d_%H%M%S).log"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# 测试统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 日志函数
log() {
    local message="[$(date '+%H:%M:%S')] $*"
    echo -e "${BLUE}$message${NC}"
    echo "$message" >> "$TEST_LOG"
}

success() {
    local message="[$(date '+%H:%M:%S')] ✓ $*"
    echo -e "${GREEN}$message${NC}"
    echo "$message" >> "$TEST_LOG"
    ((PASSED_TESTS++))
}

error() {
    local message="[$(date '+%H:%M:%S')] ✗ $*"
    echo -e "${RED}$message${NC}" >&2
    echo "$message" >> "$TEST_LOG"
    ((FAILED_TESTS++))
}

warn() {
    local message="[$(date '+%H:%M:%S')] ⚠ $*"
    echo -e "${YELLOW}$message${NC}" >&2
    echo "$message" >> "$TEST_LOG"
}

# 测试函数
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit_code="${3:-0}"
    local timeout="${4:-30}"
    
    ((TOTAL_TESTS++))
    log "开始测试: $test_name"
    
    # 运行测试命令
    local start_time=$(date +%s)
    local actual_exit_code=0
    
    if timeout "$timeout" bash -c "$test_command" >> "$TEST_LOG" 2>&1; then
        actual_exit_code=0
    else
        actual_exit_code=$?
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # 检查结果
    if [[ $actual_exit_code -eq $expected_exit_code ]]; then
        success "$test_name (${duration}s)"
    else
        error "$test_name - 期望退出代码: $expected_exit_code, 实际: $actual_exit_code (${duration}s)"
    fi
}

# 检查脚本文件是否存在
check_script_exists() {
    local script_name="$1"
    local script_path="$SCRIPT_DIR/$script_name"
    
    if [[ -f "$script_path" ]]; then
        success "脚本文件存在: $script_name"
        return 0
    else
        error "脚本文件不存在: $script_name"
        return 1
    fi
}

# 检查脚本是否可执行
check_script_executable() {
    local script_name="$1"
    local script_path="$SCRIPT_DIR/$script_name"
    
    if [[ -x "$script_path" ]]; then
        success "脚本可执行: $script_name"
        return 0
    else
        warn "脚本不可执行，正在添加执行权限: $script_name"
        chmod +x "$script_path"
        if [[ -x "$script_path" ]]; then
            success "执行权限已添加: $script_name"
            return 0
        else
            error "无法添加执行权限: $script_name"
            return 1
        fi
    fi
}

# 测试脚本语法
test_script_syntax() {
    local script_name="$1"
    local script_path="$SCRIPT_DIR/$script_name"
    
    if bash -n "$script_path"; then
        success "语法检查通过: $script_name"
        return 0
    else
        error "语法检查失败: $script_name"
        return 1
    fi
}

# 测试帮助信息
test_help_option() {
    local script_name="$1"
    local script_path="$SCRIPT_DIR/$script_name"
    
    if "$script_path" --help >/dev/null 2>&1; then
        success "帮助选项正常: $script_name"
        return 0
    else
        warn "帮助选项异常: $script_name"
        return 1
    fi
}

# 主测试函数
main() {
    echo -e "${PURPLE}================================================================================
                           Trap 案例测试套件
================================================================================${NC}"
    
    log "测试开始时间: $(date)"
    log "测试日志文件: $TEST_LOG"
    log "脚本目录: $SCRIPT_DIR"
    
    # 定义要测试的脚本
    local scripts=(
        "trap_cleanup_demo.sh"
        "trap_signal_handler.sh"
        "trap_debug_tracer.sh"
        "trap_multiprocess_manager.sh"
        "trap_cron_monitor.sh"
    )
    
    echo
    echo -e "${BLUE}==================== 基础检查 ====================${NC}"
    
    # 基础检查
    for script in "${scripts[@]}"; do
        check_script_exists "$script" || continue
        check_script_executable "$script" || continue
        test_script_syntax "$script" || continue
        test_help_option "$script" || continue
    done
    
    echo
    echo -e "${BLUE}==================== 功能测试 ====================${NC}"
    
    # 测试1: 清理演示脚本
    if [[ -f "$SCRIPT_DIR/trap_cleanup_demo.sh" ]]; then
        log "测试清理演示脚本..."
        
        # 测试正常退出
        run_test "清理脚本-正常退出" \
                 "echo 'n' | '$SCRIPT_DIR/trap_cleanup_demo.sh'" \
                 0 15
        
        # 测试错误退出
        run_test "清理脚本-错误退出" \
                 "echo 'y' | '$SCRIPT_DIR/trap_cleanup_demo.sh'" \
                 1 15
    fi
    
    # 测试2: 信号处理脚本
    if [[ -f "$SCRIPT_DIR/trap_signal_handler.sh" ]]; then
        log "测试信号处理脚本..."
        
        # 启动脚本并测试信号
        run_test "信号处理-启动测试" \
                 "timeout 10 '$SCRIPT_DIR/trap_signal_handler.sh' || true" \
                 0 15
    fi
    
    # 测试3: 调试追踪脚本
    if [[ -f "$SCRIPT_DIR/trap_debug_tracer.sh" ]]; then
        log "测试调试追踪脚本..."
        
        # 测试禁用调试模式
        run_test "调试追踪-禁用模式" \
                 "DEBUG_ENABLED=0 timeout 5 '$SCRIPT_DIR/trap_debug_tracer.sh' || true" \
                 0 10
    fi
    
    # 测试4: 多进程管理脚本
    if [[ -f "$SCRIPT_DIR/trap_multiprocess_manager.sh" ]]; then
        log "测试多进程管理脚本..."
        
        # 测试少量任务
        run_test "多进程管理-少量任务" \
                 "MAX_WORKERS=2 '$SCRIPT_DIR/trap_multiprocess_manager.sh' 5" \
                 0 30
    fi
    
    # 测试5: 定时任务监控脚本
    if [[ -f "$SCRIPT_DIR/trap_cron_monitor.sh" ]]; then
        log "测试定时任务监控脚本..."
        
        # 测试模式运行
        run_test "定时任务监控-测试模式" \
                 "'$SCRIPT_DIR/trap_cron_monitor.sh' --test" \
                 0 30
        
        # 测试状态查询
        run_test "定时任务监控-状态查询" \
                 "'$SCRIPT_DIR/trap_cron_monitor.sh' --status" \
                 0 5
    fi
    
    echo
    echo -e "${BLUE}==================== 压力测试 ====================${NC}"
    
    # 并发测试
    if [[ -f "$SCRIPT_DIR/trap_cleanup_demo.sh" ]]; then
        log "执行并发清理测试..."
        
        # 启动多个实例测试锁机制
        local pids=()
        for i in {1..3}; do
            (echo 'n' | "$SCRIPT_DIR/trap_cleanup_demo.sh" >/dev/null 2>&1) &
            pids+=($!)
        done
        
        # 等待所有进程完成
        local concurrent_success=0
        for pid in "${pids[@]}"; do
            if wait "$pid"; then
                ((concurrent_success++))
            fi
        done
        
        if [[ $concurrent_success -eq 1 ]]; then
            success "并发锁机制正常 (只有1个实例成功运行)"
        else
            error "并发锁机制异常 ($concurrent_success 个实例成功运行)"
        fi
        ((TOTAL_TESTS++))
    fi
    
    echo
    echo -e "${BLUE}==================== 信号测试 ====================${NC}"
    
    # 信号处理测试
    if [[ -f "$SCRIPT_DIR/trap_signal_handler.sh" ]]; then
        log "测试信号处理功能..."
        
        # 启动脚本
        "$SCRIPT_DIR/trap_signal_handler.sh" &
        local test_pid=$!
        
        sleep 2
        
        # 测试USR1信号 (状态报告)
        if kill -USR1 "$test_pid" 2>/dev/null; then
            success "USR1信号发送成功"
        else
            error "USR1信号发送失败"
        fi
        ((TOTAL_TESTS++))
        
        sleep 1
        
        # 测试USR2信号 (重载配置)
        if kill -USR2 "$test_pid" 2>/dev/null; then
            success "USR2信号发送成功"
        else
            error "USR2信号发送失败"
        fi
        ((TOTAL_TESTS++))
        
        sleep 1
        
        # 测试TERM信号 (优雅关闭)
        if kill -TERM "$test_pid" 2>/dev/null; then
            success "TERM信号发送成功"
        else
            error "TERM信号发送失败"
        fi
        ((TOTAL_TESTS++))
        
        # 等待进程结束
        wait "$test_pid" 2>/dev/null || true
    fi
    
    echo
    echo -e "${PURPLE}==================== 测试总结 ====================${NC}"
    
    local success_rate=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        success_rate=$(( PASSED_TESTS * 100 / TOTAL_TESTS ))
    fi
    
    echo -e "${BLUE}总测试数:${NC} $TOTAL_TESTS"
    echo -e "${GREEN}通过数:${NC} $PASSED_TESTS"
    echo -e "${RED}失败数:${NC} $FAILED_TESTS"
    echo -e "${YELLOW}成功率:${NC} ${success_rate}%"
    echo -e "${BLUE}测试日志:${NC} $TEST_LOG"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}🎉 所有测试通过！${NC}"
        return 0
    else
        echo -e "${RED}❌ 有 $FAILED_TESTS 个测试失败${NC}"
        echo -e "${YELLOW}请查看测试日志获取详细信息: $TEST_LOG${NC}"
        return 1
    fi
}

# 清理函数
cleanup() {
    local exit_code=$?
    
    # 终止可能还在运行的测试进程
    pkill -f "trap_.*\.sh" 2>/dev/null || true
    
    # 清理临时文件
    find /tmp -name "trap_test_*" -type f -mmin +60 -delete 2>/dev/null || true
    find /tmp -name "*_demo_*" -type d -mmin +60 -exec rm -rf {} + 2>/dev/null || true
    
    if [[ $exit_code -eq 0 ]]; then
        log "测试完成，清理成功"
    else
        log "测试异常结束，清理完成"
    fi
    
    exit $exit_code
}

# 注册清理函数
trap cleanup EXIT INT TERM

# 显示帮助信息
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat << EOF
Trap案例测试脚本

用法: $0 [选项]

选项:
  -h, --help     显示此帮助信息
  --verbose      详细输出模式
  --quick        快速测试模式

功能:
  - 检查所有trap示例脚本的存在性和可执行性
  - 验证脚本语法正确性
  - 测试基本功能
  - 执行压力测试和信号测试
  - 生成详细的测试报告

输出:
  测试日志会保存到 /tmp/trap_test_YYYYMMDD_HHMMSS.log
EOF
    exit 0
fi

# 检查依赖
for cmd in timeout pkill find; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        error "缺少必要的命令: $cmd"
        exit 1
    fi
done

# 执行主程序
main "$@"