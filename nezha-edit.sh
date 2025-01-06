#!/bin/bash

# 定义配置文件路径
CONFIG_FILE="/opt/nezha/agent/config.yml"

# 定义新的 client_secret 和 server 值
NEW_CLIENT_SECRET="qs4fEaLg5geBf6Mv0Piisp8y245wklxl"
NEW_SERVER="nezha.040115.xyz:8848"

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
  echo "错误：配置文件 $CONFIG_FILE 不存在！"
  exit 1
fi

# 使用 sed 命令修改 client_secret 和 server
sed -i "s/^client_secret: .*/client_secret: $NEW_CLIENT_SECRET/" "$CONFIG_FILE"
sed -i "s/^server: .*/server: $NEW_SERVER/" "$CONFIG_FILE"

# 检查修改是否成功
if [ $? -eq 0 ]; then
  echo "配置文件 $CONFIG_FILE 修改成功。"
  echo "新的 client_secret: $NEW_CLIENT_SECRET"
  echo "新的 server: $NEW_SERVER"
else
  echo "错误：修改配置文件 $CONFIG_FILE 失败！"
  exit 1
fi

# 重启 nezha-agent 服务
echo "正在重启 nezha-agent 服务..."
sudo systemctl restart nezha-agent

# 检查服务是否重启成功
if [ $? -eq 0 ]; then
  echo "nezha-agent 服务重启成功。"
else
  echo "错误：重启 nezha-agent 服务失败！"
  exit 1
fi

exit 0
