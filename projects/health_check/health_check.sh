#!/bin/bash

# 服务器健康检查系统
# 作者: Shell脚本学习项目
# 版本: 1.0

set -euo pipefail

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config/health_check.conf"
LOG_FILE="$SCRIPT_DIR/logs/health_check.log"
REPORT_FILE="$SCRIPT_DIR/reports/health_report.html"
TEMPLATE_FILE="$SCRIPT_DIR/templates/report.html.template"
DATA_FILE="$SCRIPT_DIR/data/health_data.json"

# 默认配置
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=90
SERVICES="nginx mysql ssh"
ALERT_EMAIL="admin@example.com"
CHECK_INTERVAL=300
HOSTNAME=$(hostname)

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

# 检查CPU使用率
check_cpu() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local status="OK"
    
    if (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l) )); then
        status="WARNING"
        log_message "WARNING" "CPU使用率过高: ${cpu_usage}%"
    fi
    
    echo "{\"metric\":\"cpu\",\"value\":$cpu_usage,\"threshold\":$CPU_THRESHOLD,\"status\":\"$status\"}"
}

# 检查内存使用率
check_memory() {
    local memory_usage=$(free | awk 'NR==2{printf "%.2f", $3*100/$2}')
    local status="OK"
    
    if (( $(echo "$memory_usage > $MEMORY_THRESHOLD" | bc -l) )); then
        status="WARNING"
        log_message "WARNING" "内存使用率过高: ${memory_usage}%"
    fi
    
    echo "{\"metric\":\"memory\",\"value\":$memory_usage,\"threshold\":$MEMORY_THRESHOLD,\"status\":\"$status\"}"
}

# 检查磁盘使用率
check_disk() {
    local disk_usage=$(df / | awk 'NR==2{print $5}' | cut -d'%' -f1)
    local status="OK"
    
    if [ "$disk_usage" -gt "$DISK_THRESHOLD" ]; then
        status="WARNING"
        log_message "WARNING" "磁盘使用率过高: ${disk_usage}%"
    fi
    
    echo "{\"metric\":\"disk\",\"value\":$disk_usage,\"threshold\":$DISK_THRESHOLD,\"status\":\"$status\"}"
}

# 检查服务状态
check_services() {
    local services_status="["
    local first=true
    
    for service in $SERVICES; do
        if [ "$first" = false ]; then
            services_status+=","
        fi
        first=false
        
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            services_status+="{\"service\":\"$service\",\"status\":\"running\"}"
            log_message "INFO" "服务 $service 运行正常"
        else
            services_status+="{\"service\":\"$service\",\"status\":\"stopped\"}"
            log_message "ERROR" "服务 $service 已停止"
        fi
    done
    
    services_status+="]"
    echo "$services_status"
}

# 检查网络连通性
check_network() {
    local hosts=("google.com" "github.com")
    local network_status="["
    local first=true
    
    for host in "${hosts[@]}"; do
        if [ "$first" = false ]; then
            network_status+=","
        fi
        first=false
        
        if ping -c 1 -W 5 "$host" > /dev/null 2>&1; then
            network_status+="{\"host\":\"$host\",\"status\":\"reachable\"}"
            log_message "INFO" "网络连接正常: $host"
        else
            network_status+="{\"host\":\"$host\",\"status\":\"unreachable\"}"
            log_message "ERROR" "网络连接失败: $host"
        fi
    done
    
    network_status+="]"
    echo "$network_status"
}

# 生成健康数据
generate_health_data() {
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    local cpu_data=$(check_cpu)
    local memory_data=$(check_memory)
    local disk_data=$(check_disk)
    local services_data=$(check_services)
    local network_data=$(check_network)
    
    cat << EOF
{
    "timestamp": "$timestamp",
    "hostname": "$HOSTNAME",
    "system": {
        "cpu": $cpu_data,
        "memory": $memory_data,
        "disk": $disk_data
    },
    "services": $services_data,
    "network": $network_data
}
EOF
}

# 生成HTML报告
generate_html_report() {
    local health_data="$1"
    
    mkdir -p "$(dirname "$REPORT_FILE")"
    
    if [ ! -f "$TEMPLATE_FILE" ]; then
        create_html_template
    fi
    
    # 提取数据
    local timestamp=$(echo "$health_data" | jq -r '.timestamp')
    local cpu_value=$(echo "$health_data" | jq -r '.system.cpu.value')
    local cpu_status=$(echo "$health_data" | jq -r '.system.cpu.status')
    local memory_value=$(echo "$health_data" | jq -r '.system.memory.value')
    local memory_status=$(echo "$health_data" | jq -r '.system.memory.status')
    local disk_value=$(echo "$health_data" | jq -r '.system.disk.value')
    local disk_status=$(echo "$health_data" | jq -r '.system.disk.status')
    
    # 生成服务状态HTML
    local services_html=""
    local services_count=$(echo "$health_data" | jq '.services | length')
    for ((i=0; i<services_count; i++)); do
        local service_name=$(echo "$health_data" | jq -r ".services[$i].service")
        local service_status=$(echo "$health_data" | jq -r ".services[$i].status")
        local status_class="status-ok"
        if [ "$service_status" != "running" ]; then
            status_class="status-error"
        fi
        services_html+="<div class=\"metric\"><h4>$service_name</h4><p class=\"$status_class\">$service_status</p></div>"
    done
    
    # 替换模板变量
    sed -e "s/{{HOSTNAME}}/$HOSTNAME/g" \
        -e "s/{{TIMESTAMP}}/$timestamp/g" \
        -e "s/{{CPU_VALUE}}/$cpu_value/g" \
        -e "s/{{CPU_STATUS}}/$cpu_status/g" \
        -e "s/{{MEMORY_VALUE}}/$memory_value/g" \
        -e "s/{{MEMORY_STATUS}}/$memory_status/g" \
        -e "s/{{DISK_VALUE}}/$disk_value/g" \
        -e "s/{{DISK_STATUS}}/$disk_status/g" \
        -e "s/{{SERVICES_HTML}}/$services_html/g" \
        "$TEMPLATE_FILE" > "$REPORT_FILE"
    
    log_message "INFO" "HTML报告已生成: $REPORT_FILE"
}

# 创建HTML模板
create_html_template() {
    mkdir -p "$(dirname "$TEMPLATE_FILE")"
    
    cat > "$TEMPLATE_FILE" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>服务器健康检查报告</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { background-color: #333; color: white; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
        .section { background-color: white; padding: 20px; margin-bottom: 20px; border-radius: 5px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
        .metric { display: inline-block; margin: 10px; padding: 15px; background-color: #f8f9fa; border-radius: 5px; min-width: 150px; }
        .status-ok { color: #28a745; }
        .status-warning { color: #ffc107; }
        .status-error { color: #dc3545; }
        .progress-bar { width: 100%; height: 20px; background-color: #e9ecef; border-radius: 10px; overflow: hidden; }
        .progress-fill { height: 100%; background-color: #007bff; transition: width 0.3s ease; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>服务器健康检查报告</h1>
            <p>主机: {{HOSTNAME}} | 检查时间: {{TIMESTAMP}}</p>
        </div>
        
        <div class="section">
            <h2>系统资源</h2>
            <div class="metric">
                <h4>CPU使用率</h4>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: {{CPU_VALUE}}%"></div>
                </div>
                <p class="status-{{CPU_STATUS}}">{{CPU_VALUE}}%</p>
            </div>
            <div class="metric">
                <h4>内存使用率</h4>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: {{MEMORY_VALUE}}%"></div>
                </div>
                <p class="status-{{MEMORY_STATUS}}">{{MEMORY_VALUE}}%</p>
            </div>
            <div class="metric">
                <h4>磁盘使用率</h4>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: {{DISK_VALUE}}%"></div>
                </div>
                <p class="status-{{DISK_STATUS}}">{{DISK_VALUE}}%</p>
            </div>
        </div>
        
        <div class="section">
            <h2>服务状态</h2>
            {{SERVICES_HTML}}
        </div>
    </div>
</body>
</html>
EOF
}

# 发送警报邮件
send_alert() {
    local subject="$1"
    local message="$2"
    
    if command -v mail > /dev/null; then
        echo "$message" | mail -s "$subject" "$ALERT_EMAIL"
        log_message "INFO" "警报邮件已发送: $subject"
    else
        log_message "WARNING" "mail命令不可用，无法发送邮件警报"
    fi
}

# 主函数
main() {
    log_message "INFO" "开始健康检查"
    
    # 加载配置
    load_config
    
    # 生成健康数据
    local health_data=$(generate_health_data)
    
    # 保存数据
    mkdir -p "$(dirname "$DATA_FILE")"
    echo "$health_data" > "$DATA_FILE"
    
    # 生成HTML报告
    generate_html_report "$health_data"
    
    # 检查是否需要发送警报
    local cpu_status=$(echo "$health_data" | jq -r '.system.cpu.status')
    local memory_status=$(echo "$health_data" | jq -r '.system.memory.status')
    local disk_status=$(echo "$health_data" | jq -r '.system.disk.status')
    
    if [ "$cpu_status" != "OK" ] || [ "$memory_status" != "OK" ] || [ "$disk_status" != "OK" ]; then
        local alert_message="服务器健康检查发现异常:
主机: $HOSTNAME
时间: $(date)

详细信息请查看报告: $REPORT_FILE"
        
        send_alert "服务器健康检查警报" "$alert_message"
    fi
    
    log_message "INFO" "健康检查完成"
}

# 运行主函数
main "$@"