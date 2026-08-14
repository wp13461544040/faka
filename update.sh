#!/bin/bash

# Faka发卡系统 - Docker快速更新脚本

set -e

INSTALL_DIR="/opt/faka"

echo "=========================================="
echo "   🔄 Faka发卡系统 - 更新脚本"
echo "=========================================="
echo ""

cd "$INSTALL_DIR"

# 检测docker-compose命令
if docker compose version &> /dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    DOCKER_COMPOSE_CMD="docker-compose"
fi

echo "1️⃣ 备份数据库..."
if [ -f "instance/faka.db" ]; then
    mkdir -p backups
    cp instance/faka.db backups/faka.db.backup.$(date +%Y%m%d_%H%M%S)
    echo "✅ 数据库已备份"
else
    echo "⚠️  未找到数据库文件"
fi

echo ""
echo "2️⃣ 拉取最新代码..."
git stash
git pull origin main || git pull origin master
git stash pop || true

echo ""
echo "3️⃣ 重新构建镜像..."
$DOCKER_COMPOSE_CMD build

echo ""
echo "4️⃣ 重启容器..."
$DOCKER_COMPOSE_CMD down
$DOCKER_COMPOSE_CMD up -d

echo ""
echo "5️⃣ 等待服务启动..."
sleep 5

echo ""
echo "6️⃣ 检查服务状态..."
$DOCKER_COMPOSE_CMD ps

echo ""
echo "✅ 更新完成!"
echo ""
echo "查看日志: cd $INSTALL_DIR && $DOCKER_COMPOSE_CMD logs -f"
echo ""
