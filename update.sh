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

# 检测是否使用中国镜像
if [ -f "docker-compose.china.yml" ]; then
    COMPOSE_FILE="docker-compose.china.yml"
else
    COMPOSE_FILE="docker-compose.yml"
fi

echo "使用配置文件: $COMPOSE_FILE"
echo ""

echo "1️⃣ 停止服务..."
$DOCKER_COMPOSE_CMD -f $COMPOSE_FILE down
echo "✅ 服务已停止"

echo ""
echo "2️⃣ 备份数据库..."
if [ -f "instance/faka.db" ]; then
    mkdir -p backups
    cp instance/faka.db backups/faka.db.backup.$(date +%Y%m%d_%H%M%S)
    echo "✅ 数据库已备份到 backups/"
else
    echo "⚠️  未找到数据库文件"
fi

echo ""
echo "3️⃣ 拉取最新代码..."
git stash
git pull origin main || git pull origin master
git stash pop 2>/dev/null || true
echo "✅ 代码已更新"

echo ""
echo "4️⃣ 数据库升级..."
if [ -f "upgrade.py" ]; then
    if command -v python3 &> /dev/null; then
        echo "y" | python3 upgrade.py
        echo "✅ 数据库升级完成"
    else
        echo "⚠️  未找到python3，跳过数据库升级"
    fi
else
    echo "⚠️  未找到升级脚本，跳过数据库升级"
fi

echo ""
echo "5️⃣ 重新构建镜像..."
$DOCKER_COMPOSE_CMD -f $COMPOSE_FILE build --no-cache
echo "✅ 镜像构建完成"

echo ""
echo "6️⃣ 启动服务..."
$DOCKER_COMPOSE_CMD -f $COMPOSE_FILE up -d
echo "✅ 服务已启动"

echo ""
echo "7️⃣ 等待服务就绪..."
sleep 5

echo ""
echo "8️⃣ 检查服务状态..."
$DOCKER_COMPOSE_CMD -f $COMPOSE_FILE ps

echo ""
echo "=========================================="
echo "   ✅ 更新完成!"
echo "=========================================="
echo ""
echo "📋 常用命令:"
echo "  查看日志: cd $INSTALL_DIR && $DOCKER_COMPOSE_CMD -f $COMPOSE_FILE logs -f"
echo "  重启服务: cd $INSTALL_DIR && $DOCKER_COMPOSE_CMD -f $COMPOSE_FILE restart"
echo "  停止服务: cd $INSTALL_DIR && $DOCKER_COMPOSE_CMD -f $COMPOSE_FILE down"
echo ""
echo "💾 数据库备份位置: $INSTALL_DIR/backups/"
echo ""
