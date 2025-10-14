#!/bin/bash

echo "=== 示例1: 详细的调试信息 ==="
trap 'echo "[$LINENO] 执行: $BASH_COMMAND"' DEBUG

name="张三"
age=25
echo "姓名: $name, 年龄: $age"

# 取消 trap
trap - DEBUG
echo -e "\n=== trap 已取消，下面的命令不会显示调试信息 ==="
city="北京"
echo "城市: $city"


echo -e "\n=== 示例2: 只在函数中启用 DEBUG ==="

# 普通函数（带调试）
function calculate() {
    trap 'echo "  [函数内-行号$LINENO] $BASH_COMMAND"' DEBUG  # 在函数中启用 DEBUG,函数外启用debug只会作用在函数外，函数内要启用debug必须重新定义
    
    local a=$1
    local b=$2
    local sum=$((a + b))
    local product=$((a * b))
    
    echo "  计算结果: $a + $b = $sum"
    echo "  计算结果: $a × $b = $product"
    
    # 函数结束时取消 trap
    trap - DEBUG
}

# 主程序代码（无调试信息）
echo "开始调用函数..."
calculate 5 3
echo "函数调用结束"



