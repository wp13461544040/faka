#!/bin/bash

echo "========================================"
echo "  卡密系统 - 一键部署升级"
echo "========================================"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ 请使用root权限运行此脚本${NC}"
    echo "使用方法: sudo bash deploy-upgrade.sh"
    exit 1
fi

# 停止现有服务
echo -e "${YELLOW}1. 停止现有服务...${NC}"
if docker ps | grep -q faka-app; then
    docker-compose -f docker-compose.china.yml down
    echo -e "${GREEN}✅ 服务已停止${NC}"
else
    echo -e "${YELLOW}⚠️  未检测到运行中的服务${NC}"
fi
echo ""

# 拉取最新代码
echo -e "${YELLOW}2. 拉取最新代码...${NC}"
git fetch origin
git reset --hard origin/main
echo -e "${GREEN}✅ 代码已更新${NC}"
echo ""

# 数据库升级
echo -e "${YELLOW}3. 执行数据库升级...${NC}"
if [ -f "upgrade.py" ]; then
    python3 upgrade.py <<EOF
y
EOF
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 数据库升级成功${NC}"
    else
        echo -e "${RED}❌ 数据库升级失败${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  未找到升级脚本，跳过数据库升级${NC}"
fi
echo ""

# 构建并启动服务
echo -e "${YELLOW}4. 构建并启动服务...${NC}"
docker-compose -f docker-compose.china.yml up -d --build
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 服务启动成功${NC}"
else
    echo -e "${RED}❌ 服务启动失败${NC}"
    exit 1
fi
echo ""

# 等待服务就绪
echo -e "${YELLOW}5. 等待服务就绪...${NC}"
sleep 5

# 检查服务状态
if docker ps | grep -q faka-app; then
    echo -e "${GREEN}✅ 服务运行正常${NC}"
    echo ""
    docker-compose -f docker-compose.china.yml ps
else
    echo -e "${RED}❌ 服务未正常启动${NC}"
    echo ""
    echo "查看日志："
    docker-compose -f docker-compose.china.yml logs --tail=50
    exit 1
fi

echo ""
echo "========================================"
echo -e "${GREEN}🎉 部署升级完成！${NC}"
echo "========================================"
echo ""
echo "服务信息："
echo "  - 访问地址: http://$(hostname -I | awk '{print $1}'):3019"
echo "  - 管理后台: http://$(hostname -I | awk '{print $1}'):3019/july"
echo ""
echo "常用命令："
echo "  - 查看日志: docker-compose -f docker-compose.china.yml logs -f"
echo "  - 重启服务: docker-compose -f docker-compose.china.yml restart"
echo "  - 停止服务: docker-compose -f docker-compose.china.yml down"
echo ""
