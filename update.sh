#!/bin/bash

# Faka发卡系统 - 一键更新脚本

set -e

echo "=========================================="
echo "   🔄 Faka发卡系统 - 一键更新脚本"
echo "=========================================="
echo ""

# 检测部署方式
detect_deploy_method() {
    if [ -f "/.dockerenv" ] || [ "$(docker ps -q -f name=faka_system)" ]; then
        DEPLOY_METHOD="docker"
        echo "📦 检测到Docker部署"
    elif systemctl is-active --quiet faka; then
        DEPLOY_METHOD="systemd"
        echo "⚙️  检测到Systemd部署"
    else
        echo "❌ 未检测到运行中的服务"
        exit 1
    fi
    echo ""
}

# 备份数据库
backup_database() {
    echo "💾 备份数据库..."
    
    BACKUP_DIR="/opt/faka/backups"
    mkdir -p $BACKUP_DIR
    
    if [ -f "/opt/faka/instance/faka.db" ]; then
        BACKUP_FILE="$BACKUP_DIR/faka_$(date +%Y%m%d_%H%M%S).db"
        cp /opt/faka/instance/faka.db $BACKUP_FILE
        echo "✅ 数据库已备份到: $BACKUP_FILE"
    else
        echo "⚠️  数据库文件不存在,跳过备份"
    fi
    echo ""
}

# 拉取最新代码
pull_code() {
    echo "📥 拉取最新代码..."
    cd /opt/faka
    
    # 保存本地修改
    git stash
    
    # 拉取更新
    git pull origin main || git pull origin master
    
    # 恢复本地修改
    git stash pop || true
    
    echo "✅ 代码更新完成"
    echo ""
}

# 数据库迁移
migrate_database() {
    echo "💾 执行数据库迁移..."
    
    if [ "$DEPLOY_METHOD" = "docker" ]; then
        # Docker环境下迁移
        docker-compose exec -T faka python3 - <<'PYEOF'
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

# Docker更新
update_docker() {
    echo "🐳 更新Docker服务..."
    
    cd /opt/faka
    
    # 停止服务
    docker-compose down
    
    # 重新构建
    docker-compose build --no-cache
    
    # 启动服务
    docker-compose up -d
    
    # 执行数据库迁移
    sleep 5
    migrate_database
    
    echo "✅ Docker服务更新完成"
    echo ""
}

# Systemd更新
update_systemd() {
    echo "⚙️  更新Systemd服务..."
    
    cd /opt/faka
    
    # 激活虚拟环境
    source venv/bin/activate
    
    # 更新依赖
    pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
    
    # 执行数据库迁移
    migrate_database
    
    # 重启服务
    sudo systemctl restart faka
    
    echo "✅ Systemd服务更新完成"
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

# 显示结果
show_result() {
    echo ""
    echo "=========================================="
    echo "   🎉 更新完成!"
    echo "=========================================="
    echo ""
    echo "📊 查看服务状态:"
    
    if [ "$DEPLOY_METHOD" = "docker" ]; then
        echo "   docker-compose ps"
        echo ""
        docker-compose ps
    else
        echo "   sudo systemctl status faka"
        echo ""
        sudo systemctl status faka --no-pager
    fi
    
    echo ""
    echo "📖 更新日志:"
    if [ "$DEPLOY_METHOD" = "docker" ]; then
        echo "   docker-compose logs -f --tail=50"
    else
        echo "   sudo journalctl -u faka -f -n 50"
    fi
    echo ""
}

# 主流程
main() {
    # 检测部署方式
    detect_deploy_method
    
    # 备份数据库
    backup_database
    
    # 拉取最新代码
    pull_code
    
    # 执行更新
    if [ "$DEPLOY_METHOD" = "docker" ]; then
        update_docker
    else
        update_systemd
    fi
    
    # 测试服务
    test_service
    
    # 显示结果
    show_result
}

# 执行主流程
main
