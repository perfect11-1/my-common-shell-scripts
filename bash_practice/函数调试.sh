#!/bin/bash

# 调试函数
debug_function() {
    local func_name="${FUNCNAME[1]}" # 获取当前函数的名称
    local line_no="${BASH_LINENO[0]}" # 获取当前行号
    
    
echo -e "\033[32m当前[DEBUG] 函数名为: $func_name, 调用该函数的行号为: $line_no, 函数入参为: $*\033[0m" >&2
}

# 带调试的函数
calculate_sum() {
    debug_function "$@"
    
    local sum=0
    for num in "$@"; do
        sum=$((sum + num))
    done
    
    echo $sum
}

# 启用调试
set -x
result=$(calculate_sum 1 2 3 4 5)
set +x

echo "总和: $result"


