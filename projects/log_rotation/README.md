# 项目2：日志轮转工具

## 项目概述
开发一个智能的日志轮转工具，能够自动管理系统和应用程序日志文件，防止磁盘空间耗尽，并提供灵活的配置选项。

## 项目目标
- 自动轮转日志文件
- 支持多种轮转策略（按大小、按时间）
- 日志压缩和归档
- 旧日志自动清理
- 支持多种日志格式
- 配置文件管理
- 轮转后执行自定义命令

## 项目结构
```
log_rotation/
├── README.md
├── log_rotator.sh           # 主轮转脚本
├── config/
│   ├── log_rotation.conf    # 主配置文件
│   └── logrotate.d/         # 各应用配置目录
│       ├── nginx.conf
│       ├── apache.conf
│       └── application.conf
├── scripts/
│   ├── compress.sh          # 压缩脚本
│   ├── cleanup.sh           # 清理脚本
│   └── notify.sh            # 通知脚本
├── logs/
│   └── log_rotator.log      # 轮转工具日志
└── archive/
    └── # 归档日志存储目录
```

## 功能要求

### 1. 轮转策略
- **按大小轮转**: 当日志文件超过指定大小时轮转
- **按时间轮转**: 按日、周、月定期轮转
- **混合策略**: 同时满足大小和时间条件
- **立即轮转**: 手动触发轮转

### 2. 文件管理
- 自动重命名日志文件
- 支持多种命名格式
- 创建新的空日志文件
- 保持文件权限和所有者

### 3. 压缩和归档
- 支持gzip、bzip2、xz压缩
- 可配置压缩延迟
- 归档到指定目录
- 压缩级别可调

### 4. 清理策略
- 按保留天数清理
- 按保留文件数量清理
- 按总大小限制清理
- 支持白名单保护

### 5. 后处理操作
- 轮转后重启服务
- 发送通知邮件
- 执行自定义脚本
- 更新符号链接

## 实现步骤

### 第一步：基础框架
1. 创建主脚本结构
2. 实现配置文件解析
3. 设置日志记录系统
4. 创建基本的文件操作函数

### 第二步：轮转逻辑
1. 实现文件大小检查
2. 实现时间检查逻辑
3. 创建文件轮转函数
4. 添加错误处理机制

### 第三步：压缩和归档
1. 实现压缩功能
2. 创建归档管理
3. 添加压缩格式支持
4. 实现异步压缩

### 第四步：清理机制
1. 实现自动清理功能
2. 添加清理策略
3. 创建安全检查
4. 实现清理报告

### 第五步：集成和优化
1. 添加服务集成
2. 实现通知系统
3. 性能优化
4. 全面测试

## 技术要点

### 配置文件格式
```bash
# 全局配置
GLOBAL_COMPRESS=true
GLOBAL_COMPRESS_FORMAT="gzip"
GLOBAL_RETENTION_DAYS=30
GLOBAL_MAX_SIZE="100M"

# 应用特定配置
/var/log/nginx/*.log {
    size 50M
    daily
    rotate 7
    compress
    delaycompress
    postrotate
        systemctl reload nginx
    endscript
}
```

### 轮转策略实现
```bash
# 检查文件大小
check_file_size() {
    local file="$1"
    local max_size="$2"
    
    if [ -f "$file" ]; then
        local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file")
        local max_bytes=$(parse_size "$max_size")
        
        if [ "$file_size" -gt "$max_bytes" ]; then
            return 0  # 需要轮转
        fi
    fi
    
    return 1  # 不需要轮转
}

# 检查时间条件
check_time_condition() {
    local file="$1"
    local frequency="$2"
    
    case "$frequency" in
        "daily")
            # 检查是否跨天
            ;;
        "weekly")
            # 检查是否跨周
            ;;
        "monthly")
            # 检查是否跨月
            ;;
    esac
}
```

### 压缩实现
```bash
# 压缩日志文件
compress_log() {
    local file="$1"
    local format="$2"
    local level="$3"
    
    case "$format" in
        "gzip")
            gzip -"$level" "$file"
            ;;
        "bzip2")
            bzip2 -"$level" "$file"
            ;;
        "xz")
            xz -"$level" "$file"
            ;;
    esac
}
```

## 配置示例

### Nginx日志轮转配置
```bash
/var/log/nginx/access.log {
    size 100M
    daily
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 nginx nginx
    postrotate
        systemctl reload nginx
    endscript
}
```

### Apache日志轮转配置
```bash
/var/log/apache2/*.log {
    size 50M
    weekly
    rotate 12
    compress
    delaycompress
    notifempty
    create 644 www-data www-data
    postrotate
        systemctl reload apache2
    endscript
}
```

## 高级功能

### 1. 智能压缩
- 根据文件类型选择最佳压缩算法
- 压缩率监控和优化
- 并行压缩支持

### 2. 远程归档
- 支持FTP/SFTP上传
- 云存储集成（AWS S3、阿里云OSS）
- 增量备份

### 3. 监控集成
- 轮转状态监控
- 磁盘空间监控
- 性能指标收集

### 4. Web界面
- 配置管理界面
- 轮转状态查看
- 日志文件浏览

## 测试用例

### 1. 功能测试
- 大小轮转测试
- 时间轮转测试
- 压缩功能测试
- 清理功能测试

### 2. 边界测试
- 极大文件处理
- 磁盘空间不足
- 权限不足情况
- 并发访问测试

### 3. 性能测试
- 大量文件处理
- 压缩性能测试
- 内存使用测试
- CPU使用测试

## 评估标准
- 功能完整性（35%）
- 配置灵活性（20%）
- 性能表现（20%）
- 错误处理（15%）
- 代码质量（10%）

## 提交要求
1. 完整的源代码
2. 配置文件示例
3. 安装和配置文档
4. 测试用例和结果
5. 性能测试报告