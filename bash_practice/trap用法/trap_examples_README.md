# Shell Trap 命令实用案例集合

本目录包含了5个完整的Shell脚本，演示了`trap`命令在不同场景下的实际应用。每个脚本都可以直接运行，并包含详细的注释说明。

## 📁 案例文件列表

| 文件名 | 功能描述 | 使用场景 |
|--------|----------|----------|
| `trap_cleanup_demo.sh` | 自动清理临时资源 | 任何需要创建临时文件的脚本 |
| `trap_signal_handler.sh` | 优雅处理系统信号 | 长时间运行的服务脚本 |
| `trap_debug_tracer.sh` | 调试追踪和性能分析 | 脚本调试和性能优化 |
| `trap_multiprocess_manager.sh` | 多进程任务管理 | 并行处理和任务调度 |
| `trap_cron_monitor.sh` | 定时任务异常监控 | 定时任务和系统监控 |

## 🚀 快速开始

### 1. 赋予执行权限
```bash
chmod +x bash_practice/trap_*.sh
```

### 2. 运行示例
```bash
# 案例1: 临时资源清理演示
./bash_practice/trap_cleanup_demo.sh

# 案例2: 信号处理演示 (在另一个终端发送信号测试)
./bash_practice/trap_signal_handler.sh

# 案例3: 调试追踪演示
./bash_practice/trap_debug_tracer.sh

# 案例4: 多进程管理演示
./bash_practice/trap_multiprocess_manager.sh 20

# 案例5: 定时任务监控演示
./bash_practice/trap_cron_monitor.sh --test
```

## 📖 详细案例说明

### 案例1: 脚本退出时自动清理临时文件

**文件**: `trap_cleanup_demo.sh`

**核心功能**:
- 使用 `trap cleanup EXIT` 确保脚本退出时自动清理
- 管理临时文件、目录和锁文件
- 支持正常退出和异常退出的清理
- 彩色日志输出便于观察

**关键代码**:
```bash
# 注册清理函数到EXIT信号
trap cleanup EXIT

# 清理函数
cleanup() {
    local exit_code=$?
    # 清理临时文件
    for file in "${TEMP_FILES[@]}"; do
        [[ -f "$file" ]] && rm -f "$file"
    done
    # 清理临时目录
    for dir in "${TEMP_DIRS[@]}"; do
        [[ -d "$dir" ]] && rm -rf "$dir"
    done
}
```

**使用场景**:
- 数据处理脚本
- 备份脚本
- 任何创建临时资源的脚本

### 案例2: 捕获中断信号时的优雅处理

**文件**: `trap_signal_handler.sh`

**核心功能**:
- 处理多种系统信号 (INT, TERM, USR1, USR2, HUP)
- 优雅关闭长时间运行的任务
- 实时状态报告和配置重载
- 进程监控和管理

**关键代码**:
```bash
# 注册信号处理器
trap handle_sigint INT     # Ctrl+C
trap handle_sigterm TERM   # 优雅关闭
trap handle_sigusr1 USR1   # 状态报告
trap handle_sigusr2 USR2   # 重新加载配置

# 中断处理函数
handle_sigint() {
    warn "收到 SIGINT 信号 (Ctrl+C)"
    if [[ "$CURRENT_TASK" != "" ]]; then
        warn "等待当前任务完成后退出..."
        RUNNING=false
    else
        cleanup_and_exit 130
    fi
}
```

**测试命令**:
```bash
# 在另一个终端执行
kill -USR1 <PID>  # 查看状态
kill -USR2 <PID>  # 重载配置
kill -TERM <PID>  # 优雅关闭
```

**使用场景**:
- Web服务器脚本
- 监控守护进程
- 数据处理服务

### 案例3: 调试时追踪变量状态变化

**文件**: `trap_debug_tracer.sh`

**核心功能**:
- 使用 `trap DEBUG` 追踪每个命令执行
- 监控变量值变化过程
- 统计函数调用和性能数据
- 交互式调试控制

**关键代码**:
```bash
# DEBUG信号处理器 - 在每个命令执行前触发
trap debug_tracer DEBUG

debug_tracer() {
    local current_function="${FUNCNAME[1]:-main}"
    local line_number="${BASH_LINENO[0]}"
    local command="${BASH_COMMAND}"
    
    # 显示执行信息
    printf "${GRAY}[%04d]${NC} " "$COMMAND_COUNT"
    printf "${BLUE}%s${NC}:" "$(basename "$source_file")"
    printf "${YELLOW}%d${NC} " "$line_number"
    printf "${PURPLE}%s${NC}() " "$current_function"
    printf "${CYAN}%s${NC}\n" "$command"
}
```

**环境变量控制**:
```bash
DEBUG_ENABLED=1 ./trap_debug_tracer.sh     # 启用调试
TRACE_VARIABLES=0 ./trap_debug_tracer.sh   # 禁用变量追踪
TRACE_FUNCTIONS=0 ./trap_debug_tracer.sh   # 禁用函数追踪
```

**使用场景**:
- 复杂脚本调试
- 性能分析
- 学习Shell脚本执行流程

### 案例4: 多进程管理中的信号处理

**文件**: `trap_multiprocess_manager.sh`

**核心功能**:
- 管理多个工作进程的生命周期
- 任务队列调度和分配
- 进程监控和自动重启
- 优雅关闭所有子进程

**关键代码**:
```bash
# 优雅关闭处理
graceful_shutdown() {
    warn "收到关闭信号，开始优雅关闭..."
    RUNNING=false
    
    # 等待所有工作进程结束
    for worker_id in "${!WORKER_PIDS[@]}"; do
        local worker_pid="${WORKER_PIDS[$worker_id]}"
        if kill -0 "$worker_pid" 2>/dev/null; then
            # 发送终止信号给工作进程
            kill -TERM "$worker_pid" 2>/dev/null || true
        fi
    done
}

# 注册信号处理器
trap graceful_shutdown TERM INT
trap immediate_shutdown QUIT
trap status_report USR1
```

**配置参数**:
```bash
MAX_WORKERS=8 ./trap_multiprocess_manager.sh 100      # 8个工作进程处理100个任务
TASK_QUEUE_SIZE=50 ./trap_multiprocess_manager.sh     # 设置任务队列大小
```

**使用场景**:
- 批量数据处理
- 并行文件处理
- 分布式任务执行

### 案例5: 定时任务中的异常捕获

**文件**: `trap_cron_monitor.sh`

**核心功能**:
- 适用于cron环境的异常处理
- 任务执行重试机制
- 资源监控和告警通知
- 执行锁防止重复运行

**关键代码**:
```bash
# 错误处理函数
handle_error() {
    local exit_code=$?
    local line_number=$1
    
    log_error "脚本在第 $line_number 行发生错误"
    log_error "错误命令: $LAST_COMMAND"
    log_error "退出代码: $exit_code"
    
    # 发送告警邮件
    send_alert "脚本执行错误" "详细错误信息..." "high"
}

# 注册信号处理器
trap 'handle_error $LINENO' ERR
trap handle_interrupt INT
trap handle_termination TERM
trap 'LAST_COMMAND=$BASH_COMMAND' DEBUG
```

**Cron配置示例**:
```bash
# 每小时执行一次
0 * * * * /path/to/trap_cron_monitor.sh >/dev/null 2>&1

# 每天凌晨2点执行，启用邮件告警
0 2 * * * ALERT_EMAIL=admin@example.com /path/to/trap_cron_monitor.sh
```

**使用场景**:
- 系统维护脚本
- 数据备份任务
- 日志清理任务
- 健康检查脚本

## 🛠️ 高级用法和技巧

### 1. 组合使用多个信号
```bash
# 同时处理多个信号
trap 'cleanup_function' EXIT INT TERM

# 不同信号使用不同处理函数
trap 'handle_interrupt' INT
trap 'handle_termination' TERM
trap 'handle_user_signal' USR1
```

### 2. 条件性trap设置
```bash
# 根据条件设置不同的trap
if [[ "$ENVIRONMENT" == "production" ]]; then
    trap 'production_cleanup' EXIT
else
    trap 'development_cleanup' EXIT
fi
```

### 3. trap的继承和重置
```bash
# 保存原有的trap设置
OLD_TRAP=$(trap -p EXIT)

# 设置新的trap
trap 'my_cleanup' EXIT

# 恢复原有的trap
eval "$OLD_TRAP"

# 完全移除trap
trap - EXIT
```

### 4. 在函数中使用trap
```bash
function critical_operation() {
    # 函数级别的trap
    trap 'function_cleanup' RETURN
    
    # 执行关键操作
    # ...
    
    # 函数返回时会自动执行function_cleanup
}
```

## 🔧 调试和测试

### 查看当前设置的trap
```bash
# 查看所有trap设置
trap -l    # 列出所有信号
trap -p    # 显示当前所有trap设置
trap -p EXIT INT TERM    # 显示特定信号的trap设置
```

### 测试信号处理
```bash
# 启动脚本后，在另一个终端测试
kill -INT <PID>     # 发送中断信号
kill -TERM <PID>    # 发送终止信号
kill -USR1 <PID>    # 发送用户信号1
kill -USR2 <PID>    # 发送用户信号2
```

### 模拟异常情况
```bash
# 在脚本中添加测试代码
set -e                    # 遇到错误立即退出
false                     # 触发ERR trap
exit 1                    # 触发EXIT trap
kill -TERM $$            # 自己给自己发送信号
```

## 📚 最佳实践

### 1. 总是使用EXIT trap进行清理
```bash
# 好的做法
trap cleanup EXIT

cleanup() {
    # 清理所有资源
    rm -f "$TEMP_FILE"
    kill $BACKGROUND_PID 2>/dev/null || true
}
```

### 2. 处理信号时要考虑当前状态
```bash
handle_interrupt() {
    if [[ -n "$CRITICAL_OPERATION" ]]; then
        echo "等待关键操作完成..."
        SHOULD_EXIT=true
    else
        exit 130
    fi
}
```

### 3. 记录详细的错误信息
```bash
handle_error() {
    local exit_code=$?
    local line_number=$1
    
    {
        echo "错误时间: $(date)"
        echo "错误行号: $line_number"
        echo "退出代码: $exit_code"
        echo "当前函数: ${FUNCNAME[1]}"
        echo "调用栈:"
        local i=1
        while [[ ${FUNCNAME[i]} ]]; do
            echo "  [$i] ${FUNCNAME[i]} (${BASH_SOURCE[i]}:${BASH_LINENO[i-1]})"
            ((i++))
        done
    } >> error.log
}
```

### 4. 使用锁文件防止重复运行
```bash
acquire_lock() {
    local lock_file="/tmp/script.lock"
    
    if [[ -f "$lock_file" ]]; then
        local pid=$(cat "$lock_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo "脚本已在运行 (PID: $pid)"
            exit 1
        fi
    fi
    
    echo $$ > "$lock_file"
    trap "rm -f '$lock_file'" EXIT
}
```

## 🚨 注意事项

1. **信号处理的限制**:
   - `SIGKILL` (9) 和 `SIGSTOP` (19) 无法被捕获
   - 在信号处理函数中避免复杂操作
   - 信号处理函数应该尽快执行完毕

2. **EXIT trap的特殊性**:
   - EXIT trap在脚本退出时总是会执行
   - 包括正常退出、错误退出、信号退出
   - 在EXIT trap中不要调用exit命令

3. **调试模式的性能影响**:
   - DEBUG trap会在每个命令前执行，影响性能
   - 生产环境中应该禁用详细的调试追踪
   - 可以使用条件变量控制调试级别

4. **多进程环境的注意事项**:
   - 子进程不会继承父进程的trap设置
   - 需要在子进程中重新设置trap
   - 注意进程间的信号传递

## 📞 获取帮助

每个脚本都支持 `--help` 参数来显示详细的使用说明：

```bash
./trap_cleanup_demo.sh --help
./trap_signal_handler.sh --help
./trap_debug_tracer.sh --help
./trap_multiprocess_manager.sh --help
./trap_cron_monitor.sh --help
```

## 🔗 相关资源

- [Bash Manual - Signals and Jobs](https://www.gnu.org/software/bash/manual/bash.html#Job-Control)
- [Advanced Bash-Scripting Guide - Process Substitution](https://tldp.org/LDP/abs/html/process-sub.html)
- [Linux Signal Man Page](https://man7.org/linux/man-pages/man7/signal.7.html)

---

这些案例展示了trap命令在实际Shell脚本开发中的强大功能。通过学习和实践这些例子，你可以编写出更加健壮和可靠的Shell脚本。