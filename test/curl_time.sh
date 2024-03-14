#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
YELLOW='\033[1;33m'

# 检查并安装依赖
check_install() {
    local need_clear=false
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}curl 未安装，正在尝试安装...${NC}"
        sudo apt-get install curl -y || sudo yum install curl -y || brew install curl || { echo "安装 curl 失败，请手动安装。"; exit 1; }
        need_clear=true
    fi
    if ! command -v bc &> /dev/null; then
        echo -e "${RED}bc 未安装，正在尝试安装...${NC}"
        sudo apt-get install bc -y || sudo yum install bc -y || brew install bc || { echo "安装 bc 失败，请手动安装。"; exit 1; }
        need_clear=true
    fi
    if ! command -v awk &> /dev/null; then
        echo -e "${RED}awk 未安装，但通常是系统内置的。如果确实缺少，请手动安装。${NC}"
        # 因为 awk 通常是预安装的，这里不自动尝试安装
    fi

    if [ "$need_clear" = true ]; then
        echo -e "${GREEN}安装完成，正在清空屏幕...${NC}"
        sleep 2 # 给用户时间看到安装完成的消息
        clear
    fi
}

# 初始化日志文件
logfile="curltime.log"
echo -e "网站\t\t平均时间(ms)" > $logfile

# 网站列表
sites=(
  "https://www.google.com"
  "https://www.facebook.com"
  "https://www.twitter.com"
  "https://www.youtube.com"
  "https://www.netflix.com"
  "https://chat.openai.com"
  "https://www.github.com"
)
# 检查并尝试安装 curl, bc, awk
check_install

test_time=5

# 遍历网站列表
for site in "${sites[@]}"
do
  echo -e "${GREEN}正在测试${NC} $site"
  total_time=0

  # 执行五次测量
  for ((i=1; i<=5; i++))
  do
    # 使用 curl 测量并获取时间，转换为毫秒
    time=$(curl -o /dev/null -s -w '%{time_total}' $site)
    time_ms=$(echo "$time * 1000" | bc)
    total_time=$(echo "$total_time+$time_ms" | bc)
    echo -e "尝试 $i: ${RED}$time_ms ms${NC}"
  done

  # 计算平均值
  average_time=$(echo "scale=2; $total_time / ${test_time}" | bc)
  echo -e "${GREEN}平均时间: $average_time ms${NC} for $site"
  echo "----------------------------------"

  # 更新日志文件
  printf "%s\t%s\n" $site $average_time >> $logfile
done

# 首先，找出所有网站名称中最长的一个，以确定打印宽度
max_length=0
for site in "${sites[@]}"; do
  if [ ${#site} -gt $max_length ]; then
    max_length=${#site}
  fi
done

# 为了美观，确保最小宽度至少为30个字符
if [ $max_length -lt 30 ]; then
  max_length=30
fi

# 计算网站名称的最大长度
max_site_length=30 # 设置一个基础长度，确保至少有30个字符的宽度
for site in "${sites[@]}"; do
  if [ ${#site} -gt $max_site_length ]; then
    max_site_length=${#site}
  fi
done

{
    echo "网站                          平均时间(ms)"
    echo "--------------------------------------------------"
    total=0
    count=0
    max_time=0
    declare -a times

    while IFS=$'\t' read -r site time_ms; do
        if [ "$site" != "网站" ]; then # 跳过标题行
            printf "%-30s %12.2f ms\n" "$site" "$time_ms"
            total=$(echo "$total + $time_ms" | bc)
            ((count++))
            times+=("$time_ms")
            if (( $(echo "$time_ms > $max_time" | bc -l) )); then
                max_time=$time_ms
            fi
        fi
    done < "$logfile"

    if [ "$count" -gt 0 ]; then
        average=$(echo "scale=2; $total / $count" | bc)
        echo "--------------------------------------------------"
        # 调整这里的格式化输出，确保与其他行对齐
        printf "%-30s %12.2f ms\n" "Total Avg" "$average"
    else
        echo "没有数据来计算平均时间。"
    fi
} > summary.log

cat summary.log