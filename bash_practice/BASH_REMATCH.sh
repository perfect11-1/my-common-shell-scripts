#!/bin/bash
log_line="2023-12-25 14:30:25 [ERROR] Database connection failed"

if [[ $log_line =~ ^([0-9-]+)\ ([0-9:]+)\ \[([A-Z]+)\]\ (.+)$ ]]; then
    date="${BASH_REMATCH[1]}"
    time="${BASH_REMATCH[2]}"
    level="${BASH_REMATCH[3]}"
    message="${BASH_REMATCH[4]}"
    
    echo "日期: $date"
    echo "时间: $time"
    echo "级别: $level"
    echo "消息: $message"
fi

: '
BASH_REMATCH[0] = "2023-12-25 14:30:25 [ERROR] Database connection failed"  # 完整匹配
BASH_REMATCH[1] = "2023-12-25"                    # 第1个捕获组
BASH_REMATCH[2] = "14:30:25"                      # 第2个捕获组
BASH_REMATCH[3] = "ERROR"                         # 第3个捕获组
BASH_REMATCH[4] = "Database connection failed"    # 第4个捕获组
'

#shell默认只支持整数运算，浮点数需要使用bc命令
# 基本除法（整数）
echo "10/3" | bc
# 输出：3

# 浮点除法
echo "10/3" | bc -l
# 输出：3.33333333333333333333

# 指定精度
echo "scale=2; 10/3" | bc -l
# 输出：3.33

