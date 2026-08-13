#!/bin/bash
# Docker镜像一键更新脚本

echo "=========================================="
echo "   🐳 Faka - Docker镜像更新"
echo "=========================================="
echo ""

cd /opt/faka

echo "🛑 停止旧容器..."
sudo docker-compose down

echo ""
echo "📥 拉取最新镜像..."
sudo docker pull ghcr.io/wp13461544040/faka:latest

echo ""
echo "📝 更新配置..."
cat > docker-compose.yml <<EOF
version: '3.8'

services:
  faka:
    image: ghcr.io/wp13461544040/faka:latest
    container_name: faka_system
    ports:
      - "3019:3019"
    volumes:
      - ./instance:/app/instance
      - ./uploads:/app/uploads
    environment:
      - FLASK_ENV=production
    restart: unless-stopped
EOF

echo "✅ 配置已更新"
echo ""

echo "🚀 启动新容器..."
sudo docker-compose up -d

echo ""
echo "⏳ 等待服务启动..."
sleep 10

echo ""
echo "💾 执行数据库迁移..."
sudo docker-compose exec -T faka python3 <<'PYEOF'
import sqlite3
import os

db_path = 'instance/faka.db'
os.makedirs('instance', exist_ok=True)

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

try:
    cursor.execute("PRAGMA table_info(card)")
    columns = [col[1] for col in cursor.fetchall()]
    
    if 'is_listed' not in columns:
        print("✨ 添加 is_listed 字段...")
        cursor.execute("ALTER TABLE card ADD COLUMN is_listed INTEGER DEFAULT 1")
        conn.commit()
        print("✅ 数据库迁移成功!")
    else:
        print("✅ 数据库已是最新版本")
except Exception as e:
    print(f"ℹ️  {e}")

conn.close()
PYEOF

echo ""
echo "📊 服务状态:"
sudo docker-compose ps

echo ""
echo "=========================================="
echo "   🎉 更新完成!"
echo "=========================================="
echo ""
echo "访问: http://$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'):3019"
echo ""
echo "查看日志: sudo docker-compose logs -f"
echo ""
