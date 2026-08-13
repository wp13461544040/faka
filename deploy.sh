#!/bin/bash

# Faka发卡系统 - 一键部署脚本 (支持数据库迁移)
# 支持Docker和直接部署两种方式

set -e

echo "=========================================="
echo "   🚀 Faka发卡系统 - 一键部署脚本"
echo "=========================================="
echo ""

# 检测系统
check_system() {
    echo "🔍 检测系统环境..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
        echo "   系统: $OS $VER"
    else
        echo "❌ 无法检测系统版本"
        exit 1
    fi
    
    if [ "$OS" != "ubuntu" ] && [ "$OS" != "debian" ]; then
        echo "⚠️  本脚本仅支持Ubuntu/Debian系统"
        read -p "是否继续? (y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    echo ""
}

# 选择部署方式
choose_method() {
    echo "📦 请选择部署方式:"
    echo "   1) Docker部署 (推荐,环境隔离)"
    echo "   2) 直接部署 (性能更好)"
    echo ""
    read -p "请输入选择 (1/2): " -n 1 -r
    echo ""
    
    case $REPLY in
        1)
            DEPLOY_METHOD="docker"
            echo "✅ 已选择: Docker部署"
            ;;
        2)
            DEPLOY_METHOD="systemd"
            echo "✅ 已选择: 直接部署"
            ;;
        *)
            echo "❌ 无效选择"
            exit 1
            ;;
    esac
    echo ""
}

# 安装Docker
install_docker() {
    echo "🐳 安装Docker..."
    
    if command -v docker &> /dev/null; then
        echo "   Docker已安装: $(docker --version)"
    else
        echo "   正在安装Docker..."
        
        # 使用阿里云镜像
        curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io
        
        # 配置镜像加速
        sudo mkdir -p /etc/docker
        sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://dockerproxy.com",
    "https://docker.mirrors.ustc.edu.cn"
  ]
}
EOF
        
        sudo systemctl daemon-reload
        sudo systemctl restart docker
        sudo systemctl enable docker
    fi
    
    if command -v docker-compose &> /dev/null; then
        echo "   docker-compose已安装: $(docker-compose --version)"
    else
        echo "   正在安装docker-compose..."
        sudo apt install -y docker-compose
    fi
    
    echo "✅ Docker安装完成"
    echo ""
}

# 安装Python环境
install_python() {
    echo "🐍 安装Python环境..."
    
    sudo apt update
    sudo apt install -y python3 python3-pip python3-venv
    
    echo "✅ Python安装完成"
    echo ""
}

# 数据库迁移
migrate_database() {
    echo "💾 执行数据库迁移..."
    
    if [ "$DEPLOY_METHOD" = "docker" ]; then
        # Docker环境下迁移
        sudo docker-compose exec -T faka python3 - <<'PYEOF'
import sqlite3
import os

db_path = 'instance/faka.db'
if not os.path.exists('instance'):
    os.makedirs('instance')

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# 检查字段是否存在
cursor.execute("PRAGMA table_info(card)")
columns = [col[1] for col in cursor.fetchall()]

if 'is_listed' not in columns:
    print("添加 is_listed 字段...")
    cursor.execute("ALTER TABLE card ADD COLUMN is_listed INTEGER DEFAULT 1")
    conn.commit()
    print("✅ 字段添加成功!")
else:
    print("✅ is_listed 字段已存在,无需迁移")

conn.close()
PYEOF
    else
        # 直接部署环境下迁移
        cd /opt/faka
        source venv/bin/activate
        python3 - <<'PYEOF'
import sqlite3
import os

db_path = 'instance/faka.db'
if not os.path.exists('instance'):
    os.makedirs('instance')

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# 检查字段是否存在
cursor.execute("PRAGMA table_info(card)")
columns = [col[1] for col in cursor.fetchall()]

if 'is_listed' not in columns:
    print("添加 is_listed 字段...")
    cursor.execute("ALTER TABLE card ADD COLUMN is_listed INTEGER DEFAULT 1")
    conn.commit()
    print("✅ 字段添加成功!")
else:
    print("✅ is_listed 字段已存在,无需迁移")

conn.close()
PYEOF
    fi
    
    echo "✅ 数据库迁移完成"
    echo ""
}

# Docker部署
deploy_docker() {
    echo "🐳 开始Docker部署..."
    echo ""
    
    cd /opt/faka
    
    # 构建并启动
    sudo docker-compose up -d --build
    
    echo ""
    echo "⏳ 等待服务启动..."
    sleep 10
    
    # 执行数据库迁移
    migrate_database
    
    # 检查状态
    sudo docker-compose ps
    
    echo ""
    echo "✅ Docker部署完成!"
}

# 直接部署
deploy_systemd() {
    echo "⚙️  开始直接部署..."
    echo ""
    
    cd /opt/faka
    
    # 创建虚拟环境
    echo "1️⃣ 创建Python虚拟环境..."
    python3 -m venv venv
    source venv/bin/activate
    
    # 安装依赖
    echo "2️⃣ 安装Python依赖..."
    pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
    
    # 执行数据库迁移
    echo "3️⃣ 执行数据库迁移..."
    migrate_database
    
    # 创建systemd服务
    echo "4️⃣ 创建系统服务..."
    sudo tee /etc/systemd/system/faka.service <<-'EOF'
[Unit]
Description=Faka Card System
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/faka
Environment="PATH=/opt/faka/venv/bin"
ExecStart=/opt/faka/venv/bin/python /opt/faka/app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # 启动服务
    echo "5️⃣ 启动服务..."
    sudo systemctl daemon-reload
    sudo systemctl start faka
    sudo systemctl enable faka
    
    echo ""
    echo "⏳ 等待服务启动..."
    sleep 5
    
    # 检查状态
    sudo systemctl status faka --no-pager
    
    echo ""
    echo "✅ 直接部署完成!"
}

# 配置防火墙
setup_firewall() {
    echo ""
    echo "🔒 配置防火墙..."
    
    if command -v ufw &> /dev/null; then
        sudo ufw allow 3019
        echo "✅ 已开放3019端口"
    else
        echo "⚠️  未检测到ufw,请手动开放3019端口"
    fi
    echo ""
}

# 测试服务
test_service() {
    echo "🧪 测试服务..."
    
    sleep 3
    
    if curl -s http://localhost:3019 > /dev/null; then
        echo "✅ 服务运行正常!"
    else
        echo "⚠️  服务可能未正常启动,请检查日志"
    fi
    echo ""
}

# 显示完成信息
show_result() {
    SERVER_IP=$(curl -s ifconfig.me || echo "你的服务器IP")
    
    echo ""
    echo "=========================================="
    echo "   🎉 部署完成!"
    echo "=========================================="
    echo ""
    echo "📱 访问地址:"
    echo "   用户提取: http://$SERVER_IP:3019"
    echo "   管理后台: http://$SERVER_IP:3019/july"
    echo ""
    echo "🔐 首次访问:"
    echo "   1. 访问管理后台创建管理员账号"
    echo "   2. 登录后台开始使用"
    echo ""
    echo "✨ 新功能:"
    echo "   - 卡密上架/下架管理"
    echo "   - 批量操作支持"
    echo "   - 状态筛选功能"
    echo ""
    echo "📊 常用命令:"
    
    if [ "$DEPLOY_METHOD" = "docker" ]; then
        echo "   查看日志: sudo docker-compose logs -f"
        echo "   重启服务: sudo docker-compose restart"
        echo "   停止服务: sudo docker-compose down"
        echo "   更新系统: bash update.sh"
    else
        echo "   查看日志: sudo journalctl -u faka -f"
        echo "   重启服务: sudo systemctl restart faka"
        echo "   停止服务: sudo systemctl stop faka"
        echo "   更新系统: bash update.sh"
    fi
    
    echo ""
    echo "📖 详细文档: https://github.com/wp13461544040/faka"
    echo ""
}

# 主流程
main() {
    # 检测系统
    check_system
    
    # 选择部署方式
    choose_method
    
    # 更新系统
    echo "📦 更新系统包..."
    sudo apt update
    sudo apt install -y curl git
    echo ""
    
    # 安装环境
    if [ "$DEPLOY_METHOD" = "docker" ]; then
        install_docker
    else
        install_python
    fi
    
    # 克隆或更新项目
    if [ ! -d "/opt/faka" ]; then
        echo "📥 下载项目代码..."
        cd /opt
        sudo git clone https://github.com/wp13461544040/faka.git
        echo ""
    else
        echo "📂 项目已存在: /opt/faka"
        echo "📥 拉取最新代码..."
        cd /opt/faka
        sudo git pull origin main || sudo git pull origin master
        echo ""
    fi
    
    # 执行部署
    if [ "$DEPLOY_METHOD" = "docker" ]; then
        deploy_docker
    else
        deploy_systemd
    fi
    
    # 配置防火墙
    setup_firewall
    
    # 测试服务
    test_service
    
    # 显示结果
    show_result
}

# 执行主流程
main
