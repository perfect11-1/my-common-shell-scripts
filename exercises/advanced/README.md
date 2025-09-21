# 进阶练习题目

## 练习说明
这些进阶练习题目适合已经掌握Shell脚本基础语法的学习者，涉及更复杂的编程概念和实际应用场景。

## 练习1：进程管理和监控
**难度**: ⭐⭐⭐
**知识点**: 进程操作、信号处理、后台任务

### 题目
1. 编写脚本监控指定进程的CPU和内存使用率
2. 实现进程自动重启功能
3. 创建进程管理器，支持启动、停止、重启服务
4. 添加日志记录和警报功能

### 要求
- 使用ps、top等命令获取进程信息
- 实现信号处理机制
- 支持后台运行和守护进程
- 提供详细的日志记录

### 参考答案
```bash
#!/bin/bash

# 进程监控和管理脚本
SCRIPT_NAME="process_manager"
LOG_FILE="/var/log/${SCRIPT_NAME}.log"
PID_FILE="/var/run/${SCRIPT_NAME}.pid"

# 日志记录函数
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# 获取进程信息
get_process_info() {
    local process_name="$1"
    local pid=$(pgrep "$process_name" | head -1)
    
    if [ -n "$pid" ]; then
        local cpu_usage=$(ps -p "$pid" -o %cpu --no-headers)
        local mem_usage=$(ps -p "$pid" -o %mem --no-headers)
        local status=$(ps -p "$pid" -o stat --no-headers)
        
        echo "PID:$pid CPU:$cpu_usage% MEM:$mem_usage% STATUS:$status"
        return 0
    else
        echo "PROCESS_NOT_FOUND"
        return 1
    fi
}

# 监控进程
monitor_process() {
    local process_name="$1"
    local cpu_threshold="${2:-80}"
    local mem_threshold="${3:-80}"
    
    log_message "INFO" "开始监控进程: $process_name"
    
    while true; do
        local info=$(get_process_info "$process_name")
        
        if [ "$info" = "PROCESS_NOT_FOUND" ]; then
            log_message "WARNING" "进程 $process_name 未运行"
            
            # 尝试重启进程
            if restart_process "$process_name"; then
                log_message "INFO" "进程 $process_name 重启成功"
            else
                log_message "ERROR" "进程 $process_name 重启失败"
            fi
        else
            # 解析进程信息
            local cpu=$(echo "$info" | cut -d' ' -f2 | cut -d':' -f2 | cut -d'%' -f1)
            local mem=$(echo "$info" | cut -d' ' -f3 | cut -d':' -f2 | cut -d'%' -f1)
            
            # 检查资源使用率
            if (( $(echo "$cpu > $cpu_threshold" | bc -l) )); then
                log_message "WARNING" "进程 $process_name CPU使用率过高: ${cpu}%"
            fi
            
            if (( $(echo "$mem > $mem_threshold" | bc -l) )); then
                log_message "WARNING" "进程 $process_name 内存使用率过高: ${mem}%"
            fi
            
            log_message "DEBUG" "进程 $process_name 状态: $info"
        fi
        
        sleep 30
    done
}

# 重启进程
restart_process() {
    local process_name="$1"
    
    # 停止进程
    pkill "$process_name"
    sleep 2
    
    # 强制杀死进程
    pkill -9 "$process_name" 2>/dev/null
    
    # 启动进程（这里需要根据实际情况修改）
    case "$process_name" in
        "nginx")
            systemctl start nginx
            ;;
        "apache2")
            systemctl start apache2
            ;;
        *)
            log_message "ERROR" "不知道如何启动进程: $process_name"
            return 1
            ;;
    esac
    
    return 0
}

# 信号处理
cleanup() {
    log_message "INFO" "收到终止信号，正在清理..."
    rm -f "$PID_FILE"
    exit 0
}

trap cleanup SIGTERM SIGINT

# 主函数
main() {
    local process_name="$1"
    local cpu_threshold="$2"
    local mem_threshold="$3"
    
    if [ -z "$process_name" ]; then
        echo "用法: $0 <进程名> [CPU阈值] [内存阈值]"
        exit 1
    fi
    
    # 记录PID
    echo $$ > "$PID_FILE"
    
    # 开始监控
    monitor_process "$process_name" "$cpu_threshold" "$mem_threshold"
}

main "$@"
```

## 练习2：日志分析和报告生成
**难度**: ⭐⭐⭐
**知识点**: 正则表达式、文本处理、数据分析

### 题目
1. 分析Web服务器访问日志
2. 统计访问量、错误率、热门页面
3. 生成HTML格式的分析报告
4. 实现异常检测和警报

### 要求
- 使用awk、sed、grep等工具处理日志
- 实现复杂的数据统计和分析
- 生成可视化的HTML报告
- 支持多种日志格式

### 参考答案
```bash
#!/bin/bash

# 日志分析脚本
LOG_FILE="$1"
REPORT_FILE="log_analysis_report.html"
TEMP_DIR="/tmp/log_analysis_$$"

# 创建临时目录
mkdir -p "$TEMP_DIR"

# 清理函数
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# 分析访问日志
analyze_access_log() {
    local log_file="$1"
    
    echo "分析访问日志: $log_file"
    
    # 总访问量
    local total_requests=$(wc -l < "$log_file")
    
    # 独立IP统计
    local unique_ips=$(awk '{print $1}' "$log_file" | sort | uniq | wc -l)
    
    # 状态码统计
    awk '{print $9}' "$log_file" | sort | uniq -c | sort -nr > "$TEMP_DIR/status_codes.txt"
    
    # 热门页面
    awk '{print $7}' "$log_file" | sort | uniq -c | sort -nr | head -10 > "$TEMP_DIR/top_pages.txt"
    
    # 访问量最大的IP
    awk '{print $1}' "$log_file" | sort | uniq -c | sort -nr | head -10 > "$TEMP_DIR/top_ips.txt"
    
    # 每小时访问量
    awk '{print $4}' "$log_file" | cut -c 14-15 | sort | uniq -c > "$TEMP_DIR/hourly_stats.txt"
    
    # 错误统计
    awk '$9 >= 400 {print $9}' "$log_file" | sort | uniq -c | sort -nr > "$TEMP_DIR/errors.txt"
    
    # 用户代理统计
    awk -F'"' '{print $6}' "$log_file" | sort | uniq -c | sort -nr | head -5 > "$TEMP_DIR/user_agents.txt"
    
    # 保存基本统计信息
    cat > "$TEMP_DIR/basic_stats.txt" << EOF
总访问量: $total_requests
独立IP数: $unique_ips
分析时间: $(date)
日志文件: $log_file
EOF
}

# 生成HTML报告
generate_html_report() {
    cat > "$REPORT_FILE" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>日志分析报告</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #333; color: white; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f2f2f2; }
        .chart { width: 100%; height: 300px; background-color: #f9f9f9; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Web服务器日志分析报告</h1>
EOF

    # 添加基本统计信息
    echo "        <div>" >> "$REPORT_FILE"
    while IFS= read -r line; do
        echo "        <p>$line</p>" >> "$REPORT_FILE"
    done < "$TEMP_DIR/basic_stats.txt"
    echo "        </div>" >> "$REPORT_FILE"
    
    cat >> "$REPORT_FILE" << 'EOF'
    </div>
    
    <div class="section">
        <h2>HTTP状态码统计</h2>
        <table>
            <tr><th>状态码</th><th>次数</th><th>百分比</th></tr>
EOF

    # 添加状态码统计
    local total=$(awk '{sum+=$1} END {print sum}' "$TEMP_DIR/status_codes.txt")
    while read -r count code; do
        local percentage=$(echo "scale=2; $count * 100 / $total" | bc)
        echo "            <tr><td>$code</td><td>$count</td><td>${percentage}%</td></tr>" >> "$REPORT_FILE"
    done < "$TEMP_DIR/status_codes.txt"
    
    cat >> "$REPORT_FILE" << 'EOF'
        </table>
    </div>
    
    <div class="section">
        <h2>热门页面 (前10)</h2>
        <table>
            <tr><th>页面</th><th>访问次数</th></tr>
EOF

    # 添加热门页面
    while read -r count page; do
        echo "            <tr><td>$page</td><td>$count</td></tr>" >> "$REPORT_FILE"
    done < "$TEMP_DIR/top_pages.txt"
    
    cat >> "$REPORT_FILE" << 'EOF'
        </table>
    </div>
    
    <div class="section">
        <h2>访问量最大的IP (前10)</h2>
        <table>
            <tr><th>IP地址</th><th>访问次数</th></tr>
EOF

    # 添加热门IP
    while read -r count ip; do
        echo "            <tr><td>$ip</td><td>$count</td></tr>" >> "$REPORT_FILE"
    done < "$TEMP_DIR/top_ips.txt"
    
    cat >> "$REPORT_FILE" << 'EOF'
        </table>
    </div>
    
    <div class="section">
        <h2>每小时访问量统计</h2>
        <table>
            <tr><th>小时</th><th>访问次数</th></tr>
EOF

    # 添加每小时统计
    while read -r count hour; do
        echo "            <tr><td>${hour}:00</td><td>$count</td></tr>" >> "$REPORT_FILE"
    done < "$TEMP_DIR/hourly_stats.txt"
    
    cat >> "$REPORT_FILE" << 'EOF'
        </table>
    </div>
</body>
</html>
EOF

    echo "HTML报告已生成: $REPORT_FILE"
}

# 异常检测
detect_anomalies() {
    local log_file="$1"
    
    echo "执行异常检测..."
    
    # 检测大量404错误
    local error_404_count=$(awk '$9 == 404' "$log_file" | wc -l)
    local total_requests=$(wc -l < "$log_file")
    local error_rate=$(echo "scale=2; $error_404_count * 100 / $total_requests" | bc)
    
    if (( $(echo "$error_rate > 5" | bc -l) )); then
        echo "警告: 404错误率过高 (${error_rate}%)"
    fi
    
    # 检测可疑IP
    awk '{print $1}' "$log_file" | sort | uniq -c | sort -nr | head -5 | while read -r count ip; do
        if [ "$count" -gt 1000 ]; then
            echo "警告: IP $ip 访问次数异常 ($count 次)"
        fi
    done
    
    # 检测大量5xx错误
    local server_errors=$(awk '$9 >= 500 && $9 < 600' "$log_file" | wc -l)
    local server_error_rate=$(echo "scale=2; $server_errors * 100 / $total_requests" | bc)
    
    if (( $(echo "$server_error_rate > 1" | bc -l) )); then
        echo "警告: 服务器错误率过高 (${server_error_rate}%)"
    fi
}

# 主函数
main() {
    if [ $# -eq 0 ]; then
        echo "用法: $0 <日志文件>"
        exit 1
    fi
    
    local log_file="$1"
    
    if [ ! -f "$log_file" ]; then
        echo "错误: 日志文件不存在: $log_file"
        exit 1
    fi
    
    echo "开始分析日志文件: $log_file"
    
    # 分析日志
    analyze_access_log "$log_file"
    
    # 生成报告
    generate_html_report
    
    # 异常检测
    detect_anomalies "$log_file"
    
    echo "分析完成！"
}

main "$@"
```

## 练习3：系统备份和恢复
**难度**: ⭐⭐⭐⭐
**知识点**: 文件系统、压缩、加密、网络传输

### 题目
1. 实现增量备份系统
2. 支持多种压缩格式
3. 添加加密功能保护备份数据
4. 实现远程备份和恢复
5. 创建备份验证和完整性检查

### 要求
- 支持完整备份和增量备份
- 实现数据压缩和加密
- 支持本地和远程存储
- 提供备份验证机制
- 实现自动化备份调度

### 参考答案
```bash
#!/bin/bash

# 系统备份和恢复脚本
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/backup.conf"
LOG_FILE="/var/log/backup.log"
BACKUP_INDEX="/var/lib/backup/index.db"

# 默认配置
BACKUP_TYPE="incremental"
COMPRESSION="gzip"
ENCRYPTION="false"
REMOTE_BACKUP="false"
RETENTION_DAYS=30

# 加载配置
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

# 日志记录
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# 创建备份索引
create_backup_index() {
    local source_dir="$1"
    local index_file="$2"
    
    find "$source_dir" -type f -exec stat -c "%n|%s|%Y" {} \; > "$index_file"
}

# 比较备份索引
compare_backup_index() {
    local old_index="$1"
    local new_index="$2"
    local changed_files="$3"
    
    if [ ! -f "$old_index" ]; then
        # 首次备份，所有文件都是新的
        cp "$new_index" "$changed_files"
        return 0
    fi
    
    # 找出变化的文件
    comm -13 <(sort "$old_index") <(sort "$new_index") | cut -d'|' -f1 > "$changed_files"
}

# 压缩文件
compress_backup() {
    local source="$1"
    local target="$2"
    local compression="$3"
    
    case "$compression" in
        "gzip")
            tar -czf "$target" -C "$(dirname "$source")" "$(basename "$source")"
            ;;
        "bzip2")
            tar -cjf "$target" -C "$(dirname "$source")" "$(basename "$source")"
            ;;
        "xz")
            tar -cJf "$target" -C "$(dirname "$source")" "$(basename "$source")"
            ;;
        "none")
            tar -cf "$target" -C "$(dirname "$source")" "$(basename "$source")"
            ;;
        *)
            log_message "ERROR" "不支持的压缩格式: $compression"
            return 1
            ;;
    esac
}

# 加密备份
encrypt_backup() {
    local source="$1"
    local target="$2"
    local password="$3"
    
    if [ "$ENCRYPTION" = "true" ]; then
        openssl enc -aes-256-cbc -salt -in "$source" -out "$target" -pass pass:"$password"
        rm -f "$source"
    else
        mv "$source" "$target"
    fi
}

# 执行完整备份
full_backup() {
    local source_dir="$1"
    local backup_dir="$2"
    local backup_name="$3"
    
    log_message "INFO" "开始完整备份: $source_dir"
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$backup_dir/${backup_name}_full_${timestamp}"
    local temp_dir="/tmp/backup_$$"
    
    mkdir -p "$temp_dir"
    mkdir -p "$backup_dir"
    
    # 创建备份
    if compress_backup "$source_dir" "$temp_dir/backup.tar.gz" "$COMPRESSION"; then
        # 加密备份
        encrypt_backup "$temp_dir/backup.tar.gz" "${backup_file}.tar.gz.enc" "$BACKUP_PASSWORD"
        
        # 创建索引
        create_backup_index "$source_dir" "${backup_file}.index"
        
        # 计算校验和
        sha256sum "${backup_file}.tar.gz.enc" > "${backup_file}.sha256"
        
        log_message "INFO" "完整备份完成: ${backup_file}.tar.gz.enc"
    else
        log_message "ERROR" "完整备份失败"
        return 1
    fi
    
    rm -rf "$temp_dir"
}

# 执行增量备份
incremental_backup() {
    local source_dir="$1"
    local backup_dir="$2"
    local backup_name="$3"
    
    log_message "INFO" "开始增量备份: $source_dir"
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$backup_dir/${backup_name}_inc_${timestamp}"
    local temp_dir="/tmp/backup_$$"
    local current_index="$temp_dir/current.index"
    local changed_files="$temp_dir/changed.txt"
    
    mkdir -p "$temp_dir"
    mkdir -p "$backup_dir"
    
    # 创建当前索引
    create_backup_index "$source_dir" "$current_index"
    
    # 找到最新的索引文件
    local latest_index=$(ls -t "$backup_dir"/*.index 2>/dev/null | head -1)
    
    # 比较索引，找出变化的文件
    compare_backup_index "$latest_index" "$current_index" "$changed_files"
    
    local changed_count=$(wc -l < "$changed_files")
    
    if [ "$changed_count" -eq 0 ]; then
        log_message "INFO" "没有文件变化，跳过增量备份"
        rm -rf "$temp_dir"
        return 0
    fi
    
    log_message "INFO" "发现 $changed_count 个变化的文件"
    
    # 创建增量备份
    local backup_temp="$temp_dir/incremental"
    mkdir -p "$backup_temp"
    
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            local rel_path="${file#$source_dir/}"
            local dest_dir="$backup_temp/$(dirname "$rel_path")"
            mkdir -p "$dest_dir"
            cp "$file" "$dest_dir/"
        fi
    done < "$changed_files"
    
    # 压缩增量备份
    if compress_backup "$backup_temp" "$temp_dir/backup.tar.gz" "$COMPRESSION"; then
        # 加密备份
        encrypt_backup "$temp_dir/backup.tar.gz" "${backup_file}.tar.gz.enc" "$BACKUP_PASSWORD"
        
        # 保存当前索引
        cp "$current_index" "${backup_file}.index"
        
        # 计算校验和
        sha256sum "${backup_file}.tar.gz.enc" > "${backup_file}.sha256"
        
        log_message "INFO" "增量备份完成: ${backup_file}.tar.gz.enc"
    else
        log_message "ERROR" "增量备份失败"
        return 1
    fi
    
    rm -rf "$temp_dir"
}

# 验证备份
verify_backup() {
    local backup_file="$1"
    local checksum_file="${backup_file}.sha256"
    
    if [ ! -f "$checksum_file" ]; then
        log_message "WARNING" "校验和文件不存在: $checksum_file"
        return 1
    fi
    
    log_message "INFO" "验证备份: $backup_file"
    
    if sha256sum -c "$checksum_file"; then
        log_message "INFO" "备份验证成功"
        return 0
    else
        log_message "ERROR" "备份验证失败"
        return 1
    fi
}

# 清理旧备份
cleanup_old_backups() {
    local backup_dir="$1"
    local retention_days="$2"
    
    log_message "INFO" "清理 $retention_days 天前的备份"
    
    find "$backup_dir" -name "*.tar.gz.enc" -mtime +$retention_days -delete
    find "$backup_dir" -name "*.index" -mtime +$retention_days -delete
    find "$backup_dir" -name "*.sha256" -mtime +$retention_days -delete
}

# 远程备份
remote_backup() {
    local local_file="$1"
    local remote_host="$2"
    local remote_path="$3"
    
    log_message "INFO" "上传备份到远程服务器: $remote_host"
    
    if scp "$local_file" "$remote_host:$remote_path"; then
        log_message "INFO" "远程备份成功"
        return 0
    else
        log_message "ERROR" "远程备份失败"
        return 1
    fi
}

# 主函数
main() {
    local action="$1"
    local source_dir="$2"
    local backup_dir="$3"
    local backup_name="${4:-backup}"
    
    # 加载配置
    load_config
    
    case "$action" in
        "full")
            full_backup "$source_dir" "$backup_dir" "$backup_name"
            ;;
        "incremental")
            incremental_backup "$source_dir" "$backup_dir" "$backup_name"
            ;;
        "verify")
            verify_backup "$source_dir"
            ;;
        "cleanup")
            cleanup_old_backups "$source_dir" "$RETENTION_DAYS"
            ;;
        *)
            echo "用法: $0 {full|incremental|verify|cleanup} <源目录> <备份目录> [备份名称]"
            exit 1
            ;;
    esac
    
    # 清理旧备份
    if [ "$action" = "full" ] || [ "$action" = "incremental" ]; then
        cleanup_old_backups "$backup_dir" "$RETENTION_DAYS"
    fi
}

main "$@"
```

## 练习4：网络服务监控
**难度**: ⭐⭐⭐⭐
**知识点**: 网络编程、服务监控、性能测试

### 题目
1. 监控多个网络服务的可用性
2. 测量服务响应时间和性能
3. 实现服务健康检查
4. 创建监控仪表板
5. 添加警报和通知功能

### 要求
- 支持HTTP、HTTPS、TCP、UDP服务监控
- 实现性能指标收集
- 提供Web界面显示监控状态
- 支持多种通知方式
- 实现历史数据存储和分析

## 练习总结

完成这些进阶练习后，你将掌握：
- 复杂的系统管理任务
- 高级文本处理和数据分析
- 网络编程和服务监控
- 系统安全和备份策略
- 性能优化和故障排除

## 下一步
完成进阶练习后，可以尝试[综合项目练习](../projects/README.md)，将所学知识应用到实际项目中。