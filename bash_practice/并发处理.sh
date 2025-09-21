#!/bin/bash

: "
# 后台并行处理
process_file() {
    local file=$1
    echo "处理文件: $file"
    # 模拟处理时间
    sleep 3
    echo "完成处理: $file"
}

# 并行处理多个文件
for file in *.md; do
    process_file "$file" &  # 后台执行
done

wait  # 等待所有后台任务完成
echo "所有文件处理完成"
"

# 限制并发数量
process_file() {
    local file=$1
    echo "处理文件: $file"
    # 模拟处理时间
    sleep 3
    echo "完成处理: $file"
}
max_jobs=3
job_count=0

for file in *.md; do
    if [[ $job_count -ge $max_jobs ]]; then
        wait -n  # 等待任意一个任务完成
        ((job_count--))
    fi
    
    process_file "$file" &
    ((job_count++))
done

wait  # 等待剩余任务完成


