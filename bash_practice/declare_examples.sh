#!/bin/bash
# declare 命令详细使用示例

echo "=== declare 命令使用方法演示 ==="

# 1. 基本变量声明
echo -e "\n1. 基本变量声明"
declare name="张三" #等同于name="张三"
declare age=25 #等同于age=25
echo "姓名: $name, 年龄: $age"

# 2. 整数变量 (-i)
echo -e "\n2. 整数变量声明 (-i)"
declare -i number=10
echo "初始值: $number"
number="20"
echo "赋值字符串'20': $number"
number="hello"  # 非数字会被转换为0
echo "赋值字符串'hello': $number"
number=5+3      # 可以进行算术运算
echo "赋值'5+3': $number"

# 3. 只读变量 (-r)
echo -e "\n3. 只读变量声明 (-r)"
declare -r CONSTANT="不可修改"
echo "常量值: $CONSTANT"
# CONSTANT="新值"  # 取消注释会报错

# 4. 数组变量 (-a)
echo -e "\n4. 索引数组声明 (-a)"
declare -a fruits=("苹果" "香蕉" "橙子")
echo "水果数组: ${fruits[@]}"
echo "第一个水果: ${fruits[0]}"
echo "数组长度: ${#fruits[@]}"

# 添加元素
fruits+=("葡萄")
echo "添加葡萄后: ${fruits[@]}"

# 5. 关联数组 (-A)
echo -e "\n5. 关联数组声明 (-A)"
declare -A student_scores
student_scores["张三"]=85
student_scores["李四"]=92
student_scores["王五"]=78

echo "学生成绩:"
for name in "${!student_scores[@]}"; do
    echo "  $name: ${student_scores[$name]}分"
done

# 6. 环境变量 (-x)
echo -e "\n6. 环境变量声明 (-x)"
declare -x MY_ENV_VAR="环境变量值"
echo "环境变量: $MY_ENV_VAR"
# 子进程可以访问这个变量

# 7. 大小写转换 (-u, -l)
echo -e "\n7. 大小写转换"
declare -u uppercase_var="hello world"
declare -l lowercase_var="HELLO WORLD"
echo "转大写: $uppercase_var"
echo "转小写: $lowercase_var"

# 8. 名称引用 (-n)
echo -e "\n8. 名称引用 (-n)"
original_var="原始值"
declare -n ref_var=original_var
echo "通过引用访问: $ref_var"
ref_var="通过引用修改的值"
echo "原变量值: $original_var"

# 9. 查看变量属性 (-p)
echo -e "\n9. 查看变量属性 (-p)"
declare -i test_int=42
declare -r test_readonly="只读"
declare -A test_assoc=([key1]="value1" [key2]="value2")

echo "整数变量属性:"
declare -p test_int

echo "只读变量属性:"
declare -p test_readonly

echo "关联数组属性:"
declare -p test_assoc

# 10. 组合选项使用
echo -e "\n10. 组合选项使用"
declare -irx MAX_CONNECTIONS=100  # 整数+只读+环境变量
echo "最大连接数: $MAX_CONNECTIONS"
declare -p MAX_CONNECTIONS

# 11. 函数中使用 nameref
echo -e "\n11. 函数中使用 nameref"

# 数组操作函数
array_operations() {
    local -n arr_ref=$1
    local operation=$2
    
    case $operation in
        "add")
            local value=$3
            arr_ref+=("$value")
            echo "添加元素: $value"
            ;;
        "sum")
            local sum=0
            for num in "${arr_ref[@]}"; do
                ((sum += num))
            done
            echo "数组总和: $sum"
            ;;
        "length")
            echo "数组长度: ${#arr_ref[@]}"
            ;;
        "reverse")
            local temp_array=()
            for ((i=${#arr_ref[@]}-1; i>=0; i--)); do
                temp_array+=("${arr_ref[i]}")
            done
            arr_ref=("${temp_array[@]}")
            echo "数组已反转"
            ;;
    esac
}

# 测试数组操作
numbers=(1 2 3 4 5)
echo "原始数组: ${numbers[@]}"

array_operations numbers "sum"
array_operations numbers "length"
array_operations numbers "add" 6
echo "添加后: ${numbers[@]}"
array_operations numbers "reverse"
echo "反转后: ${numbers[@]}"

# 12. 配置管理示例
echo -e "\n12. 配置管理示例"

# 声明配置结构
declare -A app_config
declare -r CONFIG_VERSION="1.0"
declare -i DEFAULT_PORT=8080

# 初始化配置
init_config() {
    local -n config_ref=$1
    
    config_ref["app_name"]="MyApp"
    config_ref["version"]="1.0.0"
    config_ref["debug"]="false"
    config_ref["port"]="$DEFAULT_PORT"
    config_ref["database_url"]="localhost:3306"
}

# 显示配置
show_config() {
    local -n config_ref=$1
    
    echo "应用配置 (版本: $CONFIG_VERSION):"
    for key in "${!config_ref[@]}"; do
        echo "  $key = ${config_ref[$key]}"
    done
}

# 更新配置
update_config() {
    local -n config_ref=$1
    local key=$2
    local value=$3
    
    if [[ -n "${config_ref[$key]}" ]]; then
        echo "更新配置: $key = $value"
        config_ref[$key]="$value"
    else
        echo "警告: 配置项 '$key' 不存在"
    fi
}

# 使用配置管理
init_config app_config
show_config app_config

update_config app_config "port" "9000"
update_config app_config "debug" "true"
echo -e "\n更新后的配置:"
show_config app_config

# 13. 类型检查函数
echo -e "\n13. 变量类型检查"

check_variable_type() {
    local var_name=$1
    local attr_info
    
    # 检查变量是否存在
    if ! declare -p "$var_name" &>/dev/null; then
        echo "变量 '$var_name' 不存在"
        return 1
    fi
    
    # 获取变量属性
    attr_info=$(declare -p "$var_name" 2>/dev/null)
    
    echo "变量 '$var_name' 的属性:"
    
    if [[ $attr_info =~ declare\ -[^\ ]*i ]]; then
        echo "  - 整数类型"
    fi
    
    if [[ $attr_info =~ declare\ -[^\ ]*r ]]; then
        echo "  - 只读"
    fi
    
    if [[ $attr_info =~ declare\ -[^\ ]*x ]]; then
        echo "  - 环境变量"
    fi
    
    if [[ $attr_info =~ declare\ -[^\ ]*a ]]; then
        echo "  - 索引数组"
    fi
    
    if [[ $attr_info =~ declare\ -[^\ ]*A ]]; then
        echo "  - 关联数组"
    fi
    
    if [[ $attr_info =~ declare\ -[^\ ]*n ]]; then
        echo "  - 名称引用"
    fi
}

# 测试类型检查
check_variable_type "number"
check_variable_type "CONSTANT"
check_variable_type "fruits"
check_variable_type "student_scores"
check_variable_type "ref_var"

echo -e "\n=== declare 命令演示完成 ==="