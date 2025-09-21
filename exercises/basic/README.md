# 基础练习题目

## 练习说明
这些练习题目旨在帮助初学者掌握Shell脚本的基础语法和常用功能。每个练习都包含题目描述、要求和参考答案。

## 练习1：Hello World和基本输出
**难度**: ⭐
**知识点**: echo命令、变量、字符串处理

### 题目
1. 编写脚本输出"Hello, World!"
2. 创建一个变量存储你的名字，并输出"Hello, [你的名字]!"
3. 获取当前日期和时间，格式化输出

### 要求
- 使用echo命令输出
- 正确使用变量
- 使用date命令获取时间

### 参考答案
```bash
#!/bin/bash

# 1. 基本输出
echo "Hello, World!"

# 2. 使用变量
name="张三"
echo "Hello, $name!"

# 3. 日期时间
current_date=$(date '+%Y-%m-%d %H:%M:%S')
echo "当前时间: $current_date"
```

## 练习2：用户输入和交互
**难度**: ⭐
**知识点**: read命令、用户交互、输入验证

### 题目
1. 提示用户输入姓名和年龄
2. 验证年龄是否为数字
3. 根据年龄判断用户是否成年
4. 输出个性化的问候信息

### 要求
- 使用read命令获取用户输入
- 验证输入的有效性
- 使用条件判断

### 参考答案
```bash
#!/bin/bash

# 获取用户输入
echo "请输入您的姓名:"
read name

echo "请输入您的年龄:"
read age

# 验证年龄是否为数字
if ! [[ "$age" =~ ^[0-9]+$ ]]; then
    echo "错误: 年龄必须是数字"
    exit 1
fi

# 判断是否成年
if [ "$age" -ge 18 ]; then
    echo "您好 $name，您已经成年了！"
else
    echo "您好 $name，您还未成年。"
fi

echo "欢迎使用我们的系统！"
```

## 练习3：文件和目录操作
**难度**: ⭐⭐
**知识点**: 文件测试、目录操作、文件权限

### 题目
1. 检查指定文件是否存在
2. 如果文件不存在，创建该文件
3. 检查文件权限并修改为可执行
4. 列出当前目录下的所有.txt文件

### 要求
- 使用文件测试操作符
- 正确处理文件权限
- 使用通配符匹配文件

### 参考答案
```bash
#!/bin/bash

filename="test.txt"

# 检查文件是否存在
if [ -f "$filename" ]; then
    echo "文件 $filename 已存在"
else
    echo "文件 $filename 不存在，正在创建..."
    touch "$filename"
    echo "文件创建成功"
fi

# 检查文件权限
if [ -x "$filename" ]; then
    echo "文件已具有执行权限"
else
    echo "添加执行权限..."
    chmod +x "$filename"
fi

# 列出所有.txt文件
echo "当前目录下的.txt文件:"
for file in *.txt; do
    if [ -f "$file" ]; then
        echo "  $file"
    fi
done
```

## 练习4：数组操作
**难度**: ⭐⭐
**知识点**: 数组定义、遍历、操作

### 题目
1. 创建一个包含水果名称的数组
2. 遍历数组并输出每个元素
3. 计算数组长度
4. 在数组中查找特定元素

### 要求
- 正确定义和使用数组
- 使用循环遍历数组
- 实现数组搜索功能

### 参考答案
```bash
#!/bin/bash

# 定义水果数组
fruits=("苹果" "香蕉" "橙子" "葡萄" "草莓")

# 输出数组长度
echo "水果数组长度: ${#fruits[@]}"

# 遍历数组
echo "所有水果:"
for i in "${!fruits[@]}"; do
    echo "  $((i+1)). ${fruits[i]}"
done

# 查找特定元素
search_fruit="香蕉"
found=false

for fruit in "${fruits[@]}"; do
    if [ "$fruit" = "$search_fruit" ]; then
        found=true
        break
    fi
done

if [ "$found" = true ]; then
    echo "找到了 $search_fruit"
else
    echo "没有找到 $search_fruit"
fi
```

## 练习5：循环和计算
**难度**: ⭐⭐
**知识点**: for循环、while循环、数学运算

### 题目
1. 使用for循环计算1到100的和
2. 使用while循环实现猜数字游戏
3. 计算斐波那契数列的前10项

### 要求
- 熟练使用不同类型的循环
- 正确进行数学运算
- 实现简单的游戏逻辑

### 参考答案
```bash
#!/bin/bash

# 1. 计算1到100的和
sum=0
for i in {1..100}; do
    sum=$((sum + i))
done
echo "1到100的和: $sum"

# 2. 猜数字游戏
echo "猜数字游戏 (1-100):"
target=$((RANDOM % 100 + 1))
attempts=0

while true; do
    echo "请输入您的猜测:"
    read guess
    
    attempts=$((attempts + 1))
    
    if [ "$guess" -eq "$target" ]; then
        echo "恭喜！您猜对了！数字是 $target"
        echo "您用了 $attempts 次尝试"
        break
    elif [ "$guess" -lt "$target" ]; then
        echo "太小了！"
    else
        echo "太大了！"
    fi
done

# 3. 斐波那契数列
echo "斐波那契数列前10项:"
a=0
b=1
echo -n "$a $b "

for i in {3..10}; do
    c=$((a + b))
    echo -n "$c "
    a=$b
    b=$c
done
echo
```

## 练习6：函数定义和使用
**难度**: ⭐⭐
**知识点**: 函数定义、参数传递、返回值

### 题目
1. 编写一个计算两个数字之和的函数
2. 编写一个检查文件是否存在的函数
3. 编写一个生成随机密码的函数

### 要求
- 正确定义函数
- 处理函数参数
- 使用函数返回值

### 参考答案
```bash
#!/bin/bash

# 1. 计算两个数字之和
add_numbers() {
    local num1=$1
    local num2=$2
    local result=$((num1 + num2))
    echo $result
}

# 2. 检查文件是否存在
check_file_exists() {
    local filename=$1
    if [ -f "$filename" ]; then
        return 0  # 文件存在
    else
        return 1  # 文件不存在
    fi
}

# 3. 生成随机密码
generate_password() {
    local length=${1:-8}  # 默认长度8
    local password=$(tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c $length)
    echo $password
}

# 测试函数
echo "测试加法函数:"
result=$(add_numbers 15 25)
echo "15 + 25 = $result"

echo "测试文件检查函数:"
if check_file_exists "test.txt"; then
    echo "test.txt 存在"
else
    echo "test.txt 不存在"
fi

echo "生成随机密码:"
password=$(generate_password 12)
echo "随机密码: $password"
```

## 练习7：字符串处理
**难度**: ⭐⭐
**知识点**: 字符串操作、模式匹配、替换

### 题目
1. 统计字符串中的字符数量
2. 将字符串转换为大写和小写
3. 提取文件名和扩展名
4. 替换字符串中的特定内容

### 要求
- 使用字符串操作符
- 掌握模式匹配
- 实现字符串替换

### 参考答案
```bash
#!/bin/bash

text="Hello World! This is a Test String."
filename="document.pdf"

# 1. 统计字符数量
echo "原始字符串: $text"
echo "字符串长度: ${#text}"

# 2. 大小写转换
echo "转换为大写: ${text^^}"
echo "转换为小写: ${text,,}"

# 3. 提取文件名和扩展名
basename="${filename%.*}"
extension="${filename##*.}"
echo "文件名: $basename"
echo "扩展名: $extension"

# 4. 字符串替换
new_text="${text/World/Universe}"
echo "替换后: $new_text"

# 替换所有匹配项
text_with_spaces="a b c d e"
no_spaces="${text_with_spaces// /_}"
echo "替换空格: $no_spaces"
```

## 练习8：命令行参数处理
**难度**: ⭐⭐
**知识点**: 位置参数、选项解析、参数验证

### 题目
1. 创建一个接受文件名参数的脚本
2. 添加帮助选项(-h或--help)
3. 实现详细模式(-v或--verbose)
4. 验证参数的有效性

### 要求
- 正确处理命令行参数
- 实现选项解析
- 提供用户友好的帮助信息

### 参考答案
```bash
#!/bin/bash

# 默认设置
verbose=false
filename=""

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项] <文件名>

选项:
    -h, --help      显示此帮助信息
    -v, --verbose   启用详细模式

示例:
    $0 test.txt
    $0 -v document.pdf
    $0 --help
EOF
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            verbose=true
            shift
            ;;
        -*)
            echo "未知选项: $1"
            show_help
            exit 1
            ;;
        *)
            filename="$1"
            shift
            ;;
    esac
done

# 验证参数
if [ -z "$filename" ]; then
    echo "错误: 请指定文件名"
    show_help
    exit 1
fi

# 主要逻辑
if [ "$verbose" = true ]; then
    echo "详细模式已启用"
    echo "处理文件: $filename"
fi

if [ -f "$filename" ]; then
    echo "文件 $filename 存在"
    if [ "$verbose" = true ]; then
        echo "文件大小: $(stat -c%s "$filename") 字节"
        echo "修改时间: $(stat -c%y "$filename")"
    fi
else
    echo "文件 $filename 不存在"
fi
```

## 练习总结

完成这些基础练习后，你应该掌握：
- Shell脚本基本语法
- 变量和数组的使用
- 条件判断和循环结构
- 函数定义和调用
- 文件和目录操作
- 字符串处理技巧
- 命令行参数处理

## 下一步
完成基础练习后，可以继续进行[进阶练习](../advanced/README.md)，学习更复杂的Shell脚本技巧。