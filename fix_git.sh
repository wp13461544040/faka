#!/bin/bash
# 修复Git连接问题 - 使用国内镜像

echo "🔧 修复Git连接..."

cd /opt/faka

# 改回HTTPS
sudo git remote set-url origin https://github.com/wp13461544040/faka.git

# 配置镜像加速
git config --global url."https://ghproxy.com/https://github.com".insteadOf "https://github.com"

# 测试连接
echo "📥 拉取最新代码..."
sudo git pull

echo "✅ 完成!"
