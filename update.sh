#!/bin/bash

# Faka发卡系统 - 自动更新脚本
# 支持Docker和Systemd两种部署方式

set -e

echo "=========================================="
echo "   🚀 Faka发卡系统 - 自动更新脚本"
echo "=========================================="
echo ""

# 检测项目目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "📂 项目路径: $SCRIPT_DIR"
echo ""

# 备份数据库
backup_database() {
    echo "💾 备份数据库..."
    BACKUP_DIR="./backups"
    mkdir -p "$BACKUP_DIR"
    
    if [ -f "faka.db" ]; then
        BACKUP_FILE="$BACKUP_DIR/faka_$(date +%Y%m%d_%H%M%S).db"
        cp faka.db "$BACKUP_FILE"
        echo "✅ 数据库已备份到: $BACKUP_FILE"
    elif [ -f "data/faka.db" ]; then
        BACKUP_FILE="$BACKUP_DIR/faka_$(date +%Y%m%d_%H%M%S).db"
        cp data/faka.db "$BACKUP_FILE"
        echo "✅ 数据库已备份到: $BACKUP_FILE"
    else
        echo "⚠️  未找到数据库文件,跳过备份"
    fi
    echo ""
}

# 拉取最新代码
update_code() {
    echo "📥 拉取最新代码..."
    
    # 保存本地修改(如果有)
    if [ -n "$(git status --porcelain)" ]; then
        echo "⚠️  检测到本地修改,正在暂存..."
        git stash
        STASHED=true
    fi
    
    # 拉取最新代码
    git pull origin main
    
    # 恢复本地修改
    if [ "$STASHED" = true ]; then
        echo "♻️  恢复本地修改..."
        git stash pop || echo "⚠️  自动恢复失败,请手动处理冲突"
    fi
    
    echo "✅ 代码更新完成"
    echo ""
}

# 检测部署方式
detect_deployment() {
    if [ -f "docker-compose.yml" ] && command -v docker-compose &> /dev/null; then
        if sudo docker-compose ps | grep -q "Up"; then
            echo "🐳 检测到Docker部署方式"
            DEPLOY_TYPE="docker"
            return
        fi
    fi
    
    if sudo systemctl is-active --quiet faka; then
        echo "⚙️  检测到Systemd部署方式"
        DEPLOY_TYPE="systemd"
        return
    fi
    
    echo "❌ 未检测到运行中的服务"
    echo "请先部署系统: bash deploy.sh"
    exit 1
}

# Docker方式更新
update_docker() {
    echo "🐳 使用Docker方式更新..."
    echo ""
    
    echo "1️⃣ 停止服务..."
    sudo docker-compose down
    
    echo "2️⃣ 重新构建镜像..."
    sudo docker-compose build --no-cache
    
    echo "3️⃣ 启动服务..."
    sudo docker-compose up -d
    
    echo "4️⃣ 等待服务启动..."
    sleep 5
    
    echo "5️⃣ 检查运行状态..."
    sudo docker-compose ps
    
    echo ""
    echo "✅ Docker更新完成!"
    echo "📊 查看日志: sudo docker-compose logs -f"
}

# Systemd方式更新
update_systemd() {
    echo "⚙️  使用Systemd方式更新..."
    echo ""
    
    echo "1️⃣ 停止服务..."
    sudo systemctl stop faka
    
    echo "2️⃣ 激活虚拟环境..."
    source venv/bin/activate
    
    echo "3️⃣ 更新依赖..."
    pip install -r requirements.txt --upgrade -i https://pypi.tuna.tsinghua.edu.cn/simple
    
    echo "4️⃣ 启动服务..."
    sudo systemctl start faka
    
    echo "5️⃣ 等待服务启动..."
    sleep 3
    
    echo "6️⃣ 检查运行状态..."
    sudo systemctl status faka --no-pager
    
    echo ""
    echo "✅ Systemd更新完成!"
    echo "📊 查看日志: sudo journalctl -u faka -f"
}

# 测试服务
test_service() {
    echo ""
    echo "🧪 测试服务..."
    
    sleep 2
    
    if curl -s http://localhost:3019 > /dev/null; then
        echo "✅ 服务运行正常!"
    else
        echo "⚠️  服务可能未正常启动,请检查日志"
    fi
}

# 显示访问信息
show_info() {
    echo ""
    echo "=========================================="
    echo "   ✅ 更新完成!"
    echo "=========================================="
    echo ""
    echo "📱 访问地址:"
    echo "   用户端: http://你的IP:3019"
    echo "   管理端: http://你的IP:3019/july"
    echo ""
    echo "📊 常用命令:"
    
    if [ "$DEPLOY_TYPE" = "docker" ]; then
        echo "   查看日志: sudo docker-compose logs -f"
        echo "   重启服务: sudo docker-compose restart"
        echo "   停止服务: sudo docker-compose down"
    else
        echo "   查看日志: sudo journalctl -u faka -f"
        echo "   重启服务: sudo systemctl restart faka"
        echo "   停止服务: sudo systemctl stop faka"
    fi
    
    echo ""
    echo "💾 数据库备份位置: $SCRIPT_DIR/backups/"
    echo ""
}

# 主流程
main() {
    # 确认更新
    echo "⚠️  更新前请确保:"
    echo "   1. 已通知用户系统将暂时维护"
    echo "   2. 数据库将自动备份"
    echo "   3. 更新过程约需1-3分钟"
    echo ""
    read -p "是否继续更新? (y/n): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ 已取消更新"
        exit 0
    fi
    
    echo ""
    
    # 备份数据库
    backup_database
    
    # 检测部署方式
    detect_deployment
    
    # 拉取最新代码
    update_code
    
    # 根据部署方式更新
    if [ "$DEPLOY_TYPE" = "docker" ]; then
        update_docker
    else
        update_systemd
    fi
    
    # 测试服务
    test_service
    
    # 显示信息
    show_info
}

# 执行主流程
main
