#!/bin/bash

echo "========================================"
echo "  卡密系统 - 一键安装脚本"
echo "========================================"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ 请使用root权限运行此脚本${NC}"
    echo "使用方法: sudo bash install.sh"
    exit 1
fi

# 检查系统
echo -e "${BLUE}检查系统环境...${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
    echo -e "${GREEN}✅ 系统: $OS $VER${NC}"
else
    echo -e "${RED}❌ 无法识别系统类型${NC}"
    exit 1
fi
echo ""

# 安装Docker
echo -e "${YELLOW}1. 安装Docker...${NC}"
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✅ Docker已安装${NC}"
    docker --version
else
    echo "正在安装Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl start docker
    systemctl enable docker
    echo -e "${GREEN}✅ Docker安装完成${NC}"
fi
echo ""

# 安装Docker Compose
echo -e "${YELLOW}2. 安装Docker Compose...${NC}"
if command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}✅ Docker Compose已安装${NC}"
    docker-compose --version
else
    echo "正在安装Docker Compose..."
    apt-get update
    apt-get install -y docker-compose
    echo -e "${GREEN}✅ Docker Compose安装完成${NC}"
fi
echo ""

# 配置Docker镜像加速
echo -e "${YELLOW}3. 配置Docker镜像加速...${NC}"
read -p "是否配置Docker中国镜像加速? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.ccs.tencentyun.com"
  ]
}
EOF
    systemctl daemon-reload
    systemctl restart docker
    echo -e "${GREEN}✅ 镜像加速配置完成${NC}"
else
    echo -e "${YELLOW}⚠️  跳过镜像加速配置${NC}"
fi
echo ""

# 克隆项目
echo -e "${YELLOW}4. 下载项目代码...${NC}"
INSTALL_DIR="/opt/faka"

if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}⚠️  目录已存在: $INSTALL_DIR${NC}"
    read -p "是否删除并重新安装? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf $INSTALL_DIR
    else
        echo -e "${RED}❌ 安装已取消${NC}"
        exit 1
    fi
fi

echo "正在克隆项目..."
read -p "请输入Git仓库地址 (按回车使用默认): " GIT_REPO
if [ -z "$GIT_REPO" ]; then
    GIT_REPO="https://github.com/你的用户名/faka.git"
fi

git clone $GIT_REPO $INSTALL_DIR
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 项目克隆失败${NC}"
    exit 1
fi
cd $INSTALL_DIR
echo -e "${GREEN}✅ 项目下载完成${NC}"
echo ""

# 配置服务
echo -e "${YELLOW}5. 配置服务...${NC}"
read -p "使用中国镜像? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    COMPOSE_FILE="docker-compose.china.yml"
else
    COMPOSE_FILE="docker-compose.yml"
fi

# 启动服务
echo -e "${YELLOW}6. 启动服务...${NC}"
docker-compose -f $COMPOSE_FILE up -d --build
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 服务启动失败${NC}"
    exit 1
fi
echo -e "${GREEN}✅ 服务启动成功${NC}"
echo ""

# 等待服务就绪
echo -e "${YELLOW}7. 等待服务就绪...${NC}"
sleep 5

# 获取服务器IP
SERVER_IP=$(hostname -I | awk '{print $1}')

# 配置防火墙
echo -e "${YELLOW}8. 配置防火墙...${NC}"
if command -v ufw &> /dev/null; then
    ufw allow 3019/tcp
    echo -e "${GREEN}✅ UFW防火墙已配置${NC}"
elif command -v iptables &> /dev/null; then
    iptables -A INPUT -p tcp --dport 3019 -j ACCEPT
    echo -e "${GREEN}✅ iptables防火墙已配置${NC}"
else
    echo -e "${YELLOW}⚠️  未检测到防火墙，请手动开放3019端口${NC}"
fi
echo ""

# 显示结果
echo ""
echo "========================================"
echo -e "${GREEN}🎉 安装完成！${NC}"
echo "========================================"
echo ""
echo "访问信息："
echo "  - 首页: http://$SERVER_IP:3019"
echo "  - 管理后台: http://$SERVER_IP:3019/july"
echo ""
echo "下一步："
echo "  1. 访问首页，系统会自动跳转到初始化页面"
echo "  2. 创建管理员账号"
echo "  3. 登录管理后台"
echo "  4. 导入卡密内容，生成卡密"
echo ""
echo "常用命令："
echo "  - 查看日志: docker-compose -f $COMPOSE_FILE logs -f"
echo "  - 重启服务: docker-compose -f $COMPOSE_FILE restart"
echo "  - 停止服务: docker-compose -f $COMPOSE_FILE down"
echo "  - 升级系统: ./deploy-upgrade.sh"
echo ""
echo "文档位置："
echo "  - 项目目录: $INSTALL_DIR"
echo "  - 部署文档: $INSTALL_DIR/DEPLOY.md"
echo "  - 项目说明: $INSTALL_DIR/README.md"
echo ""
echo "安全提醒："
echo "  ⚠️  请尽快修改管理员密码"
echo "  ⚠️  建议配置HTTPS和域名"
echo "  ⚠️  定期备份数据库"
echo ""
