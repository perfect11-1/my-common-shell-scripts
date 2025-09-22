#!/bin/bash

# =============================================================================
# 案例3: 调试时追踪变量状态变化
# 功能: 使用trap DEBUG来追踪脚本执行过程中的变量变化和函数调用
# 使用场景: 脚本调试、性能分析、执行流程追踪
# =============================================================================

# 调试配置
DEBUG_ENABLED=${DEBUG_ENABLED:-1}
TRACE_VARIABLES=${TRACE_VARIABLES:-1}
TRACE_FUNCTIONS=${TRACE_FUNCTIONS:-1}
TRACE_PERFORMANCE=${TRACE_PERFORMANCE:-1}
MAX_TRACE_DEPTH=${MAX_TRACE_DEPTH:-10}

# 调试状态变量
declare -A VARIABLE_HISTORY
declare -A FUNCTION_CALLS
declare -A PERFORMANCE_DATA
TRACE_DEPTH=0
LAST_COMMAND=""
COMMAND_COUNT=0

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m'

# =============================================================================
# 调试追踪函数
# =============================================================================

# DEBUG信号处理器 - 在每个命令执行前触发
debug_tracer() {
    # 跳过trap本身的调用
    [[ "${BASH_COMMAND}" =~ ^debug_tracer ]] && return
    
    # 检查调试是否启用
    [[ $DEBUG_ENABLED -eq 0 ]] && return
    
    # 防止无限递归
    [[ $TRACE_DEPTH -gt $MAX_TRACE_DEPTH ]] && return
    
    ((TRACE_DEPTH++))
    ((COMMAND_COUNT++))
    
    local current_function="${FUNCNAME[1]:-main}"
    local line_number="${BASH_LINENO[0]}"
    local source_file="${BASH_SOURCE[1]:-$0}"
    local command="${BASH_COMMAND}"
    
    # 记录性能数据
    if [[ $TRACE_PERFORMANCE -eq 1 ]]; then
        PERFORMANCE_DATA["${current_function}_start_$(date +%s%N)"]="$command"
    fi
    
    # 显示执行信息
    printf "${GRAY}[%04d]${NC} " "$COMMAND_COUNT"
    printf "${BLUE}%s${NC}:" "$(basename "$source_file")"
    printf "${YELLOW}%d${NC} " "$line_number"
    printf "${PURPLE}%s${NC}() " "$current_function"
    printf "${CYAN}%s${NC}\n" "$command"
    
    # 追踪函数调用
    if [[ $TRACE_FUNCTIONS -eq 1 && "$command" =~ ^[a-zA-Z_][a-zA-Z0-9_]*\( ]]; then
        local func_name="${command%%(*}"
        FUNCTION_CALLS["$func_name"]=$((${FUNCTION_CALLS["$func_name"]:-0} + 1))
        printf "  ${GREEN}→ 函数调用:${NC} %s (第%d次)\n" "$func_name" "${FUNCTION_CALLS["$func_name"]}"
    fi
    
    # 追踪变量赋值
    if [[ $TRACE_VARIABLES -eq 1 && "$command" =~ ^[a-zA-Z_][a-zA-Z0-9_]*= ]]; then
        local var_name="${command%%=*}"
        local old_value="${VARIABLE_HISTORY["$var_name"]:-<未设置>}"
        
        # 执行命令后获取新值 (这里我们延迟到命令执行后)
        printf "  ${YELLOW}→ 变量赋值:${NC} %s (旧值: %s)\n" "$var_name" "$old_value"
    fi
    
    LAST_COMMAND="$command"
    ((TRACE_DEPTH--))
}

# 变量变化追踪器
trace_variable_change() {
    local var_name="$1"
    local new_value="${!var_name:-}"
    local old_value="${VARIABLE_HISTORY["$var_name"]:-<未设置>}"
    
    if [[ "$new_value" != "$old_value" ]]; then
        printf "  ${GREEN}✓ 变量更新:${NC} %s: '%s' → '%s'\n" "$var_name" "$old_value" "$new_value"
        VARIABLE_HISTORY["$var_name"]="$new_value"
    fi
}

# 函数执行时间追踪
trace_function_performance() {
    local func_name="$1"
    local start_time="$2"
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 )) # 转换为毫秒
    
    printf "  ${PURPLE}⏱ 函数耗时:${NC} %s() 执行了 %d ms\n" "$func_name" "$duration"
}

# =============================================================================
# 调试控制函数
# =============================================================================

# 启用调试追踪
enable_debug_trace() {
    DEBUG_ENABLED=1
    trap debug_tracer DEBUG
    echo -e "${GREEN}✓ 调试追踪已启用${NC}"
}

# 禁用调试追踪
disable_debug_trace() {
    DEBUG_ENABLED=0
    trap - DEBUG
    echo -e "${RED}✗ 调试追踪已禁用${NC}"
}

# 显示调试统计
show_debug_stats() {
    echo
    echo -e "${PURPLE}==================== 调试统计 ====================${NC}"
    echo -e "${CYAN}总命令数:${NC} $COMMAND_COUNT"
    
    if [[ ${#FUNCTION_CALLS[@]} -gt 0 ]]; then
        echo -e "${CYAN}函数调用统计:${NC}"
        for func in "${!FUNCTION_CALLS[@]}"; do
            printf "  %s: %d次\n" "$func" "${FUNCTION_CALLS[$func]}"
        done
    fi
    
    if [[ ${#VARIABLE_HISTORY[@]} -gt 0 ]]; then
        echo -e "${CYAN}变量最终值:${NC}"
        for var in "${!VARIABLE_HISTORY[@]}"; do
            printf "  %s = '%s'\n" "$var" "${VARIABLE_HISTORY[$var]}"
        done
    fi
    
    echo -e "${PURPLE}=================================================${NC}"
    echo
}

# =============================================================================
# 示例函数 - 用于演示调试追踪
# =============================================================================

# 数学计算函数
calculate_fibonacci() {
    local n=$1
    local start_time=$(date +%s%N)
    
    if [[ $n -le 1 ]]; then
        echo $n
        return
    fi
    
    local a=0
    local b=1
    local result
    
    for ((i=2; i<=n; i++)); do
        result=$((a + b))
        a=$b
        b=$result
        
        # 追踪变量变化
        trace_variable_change "a"
        trace_variable_change "b"
        trace_variable_change "result"
    done
    
    echo $result
    trace_function_performance "calculate_fibonacci" "$start_time"
}

# 字符串处理函数
process_string() {
    local input="$1"
    local start_time=$(date +%s%N)
    
    # 转换为大写
    local uppercase="${input^^}"
    trace_variable_change "uppercase"
    
    # 计算长度
    local length=${#input}
    trace_variable_change "length"
    
    # 反转字符串
    local reversed=""
    for ((i=${#input}-1; i>=0; i--)); do
        reversed+="${input:$i:1}"
    done
    trace_variable_change "reversed"
    
    # 返回结果
    echo "原始: $input | 大写: $uppercase | 长度: $length | 反转: $reversed"
    trace_function_performance "process_string" "$start_time"
}

# 数组操作函数
array_operations() {
    local start_time=$(date +%s%N)
    
    # 创建数组
    local numbers=(1 2 3 4 5)
    trace_variable_change "numbers"
    
    # 计算总和
    local sum=0
    for num in "${numbers[@]}"; do
        sum=$((sum + num))
        trace_variable_change "sum"
    done
    
    # 查找最大值
    local max=${numbers[0]}
    for num in "${numbers[@]}"; do
        if [[ $num -gt $max ]]; then
            max=$num
            trace_variable_change "max"
        fi
    done
    
    echo "数组: ${numbers[*]} | 总和: $sum | 最大值: $max"
    trace_function_performance "array_operations" "$start_time"
}

# 文件操作函数
file_operations() {
    local start_time=$(date +%s%N)
    local temp_file="/tmp/debug_test_$$.txt"
    
    # 创建临时文件
    echo "测试内容" > "$temp_file"
    trace_variable_change "temp_file"
    
    # 读取文件
    local content
    content=$(cat "$temp_file")
    trace_variable_change "content"
    
    # 获取文件大小
    local file_size
    file_size=$(wc -c < "$temp_file")
    trace_variable_change "file_size"
    
    # 清理
    rm -f "$temp_file"
    
    echo "文件内容: '$content' | 大小: $file_size 字节"
    trace_function_performance "file_operations" "$start_time"
}

# =============================================================================
# 交互式调试控制
# =============================================================================

interactive_debug_menu() {
    while true; do
        echo
        echo -e "${BLUE}==================== 调试控制菜单 ====================${NC}"
        echo "1. 启用/禁用调试追踪"
        echo "2. 启用/禁用变量追踪"
        echo "3. 启用/禁用函数追踪"
        echo "4. 启用/禁用性能追踪"
        echo "5. 显示调试统计"
        echo "6. 清除调试历史"
        echo "7. 执行测试函数"
        echo "0. 退出菜单"
        echo -e "${BLUE}====================================================${NC}"
        
        read -p "请选择操作 (0-7): " choice
        
        case $choice in
            1)
                if [[ $DEBUG_ENABLED -eq 1 ]]; then
                    disable_debug_trace
                else
                    enable_debug_trace
                fi
                ;;
            2)
                TRACE_VARIABLES=$((1 - TRACE_VARIABLES))
                echo -e "变量追踪: $([ $TRACE_VARIABLES -eq 1 ] && echo "${GREEN}启用${NC}" || echo "${RED}禁用${NC}")"
                ;;
            3)
                TRACE_FUNCTIONS=$((1 - TRACE_FUNCTIONS))
                echo -e "函数追踪: $([ $TRACE_FUNCTIONS -eq 1 ] && echo "${GREEN}启用${NC}" || echo "${RED}禁用${NC}")"
                ;;
            4)
                TRACE_PERFORMANCE=$((1 - TRACE_PERFORMANCE))
                echo -e "性能追踪: $([ $TRACE_PERFORMANCE -eq 1 ] && echo "${GREEN}启用${NC}" || echo "${RED}禁用${NC}")"
                ;;
            5)
                show_debug_stats
                ;;
            6)
                VARIABLE_HISTORY=()
                FUNCTION_CALLS=()
                PERFORMANCE_DATA=()
                COMMAND_COUNT=0
                echo -e "${GREEN}✓ 调试历史已清除${NC}"
                ;;
            7)
                echo "选择要执行的测试函数:"
                echo "  a) 斐波那契计算"
                echo "  b) 字符串处理"
                echo "  c) 数组操作"
                echo "  d) 文件操作"
                read -p "请选择 (a-d): " test_choice
                
                case $test_choice in
                    a) 
                        read -p "输入斐波那契数列项数: " n
                        result=$(calculate_fibonacci "$n")
                        echo "结果: $result"
                        ;;
                    b)
                        read -p "输入要处理的字符串: " str
                        process_string "$str"
                        ;;
                    c)
                        array_operations
                        ;;
                    d)
                        file_operations
                        ;;
                    *)
                        echo "无效选择"
                        ;;
                esac
                ;;
            0)
                break
                ;;
            *)
                echo "无效选择，请重试"
                ;;
        esac
    done
}

# =============================================================================
# 主程序
# =============================================================================

main() {
    # 显示程序信息
    cat << EOF

${PURPLE}================================================================================
                           Shell 调试追踪演示
================================================================================${NC}

${CYAN}功能特性:${NC}
- 使用 trap DEBUG 追踪每个命令的执行
- 监控变量值的变化过程
- 统计函数调用次数和性能
- 提供交互式调试控制

${CYAN}调试选项:${NC}
- DEBUG_ENABLED=$DEBUG_ENABLED (总开关)
- TRACE_VARIABLES=$TRACE_VARIABLES (变量追踪)
- TRACE_FUNCTIONS=$TRACE_FUNCTIONS (函数追踪)  
- TRACE_PERFORMANCE=$TRACE_PERFORMANCE (性能追踪)

${CYAN}使用方法:${NC}
可以通过环境变量控制调试行为:
  DEBUG_ENABLED=0 $0        # 禁用调试
  TRACE_VARIABLES=0 $0      # 禁用变量追踪

${PURPLE}================================================================================${NC}

EOF

    # 启用调试追踪
    enable_debug_trace
    
    # 演示一些基本操作
    echo -e "${GREEN}开始演示基本操作...${NC}"
    
    # 简单变量操作
    local demo_var="Hello"
    trace_variable_change "demo_var"
    
    demo_var="Hello World"
    trace_variable_change "demo_var"
    
    local number=42
    trace_variable_change "number"
    
    number=$((number * 2))
    trace_variable_change "number"
    
    # 执行一些示例函数
    echo -e "${GREEN}执行示例函数...${NC}"
    calculate_fibonacci 8
    process_string "Debug Test"
    array_operations
    
    # 显示统计信息
    show_debug_stats
    
    # 进入交互模式
    echo -e "${GREEN}进入交互式调试菜单...${NC}"
    interactive_debug_menu
    
    echo -e "${GREEN}调试演示结束${NC}"
}

# =============================================================================
# 清理函数
# =============================================================================

cleanup() {
    disable_debug_trace
    show_debug_stats
    echo -e "${GREEN}程序已退出${NC}"
}

trap cleanup EXIT

# =============================================================================
# 脚本入口
# =============================================================================

# 检查参数
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "用法: $0 [选项]"
    echo "环境变量:"
    echo "  DEBUG_ENABLED=0|1     启用/禁用调试追踪"
    echo "  TRACE_VARIABLES=0|1   启用/禁用变量追踪"
    echo "  TRACE_FUNCTIONS=0|1   启用/禁用函数追踪"
    echo "  TRACE_PERFORMANCE=0|1 启用/禁用性能追踪"
    echo "  MAX_TRACE_DEPTH=N     最大追踪深度"
    exit 0
fi

# 执行主程序
main "$@"