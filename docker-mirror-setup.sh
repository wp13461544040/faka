#!/bin/bash

# Docker镜像加速配置脚本 - 国内服务器专用

echo "=========================================="
echo "   🚀 配置Docker镜像加速"
echo "=========================================="
echo ""

# 检查是否为root
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行: sudo bash $0"
    exit 1
fi

echo "📝 配置Docker镜像加速..."

# 创建daemon.json
mkdir -p /etc/docker

cat > /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://dockerproxy.com",
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

echo "✅ 配置文件已创建: /etc/docker/daemon.json"
echo ""

echo "🔄 重启Docker服务..."
systemctl daemon-reload
systemctl restart docker

if systemctl is-active --quiet docker; then
    echo "✅ Docker服务重启成功"
else
    echo "❌ Docker服务重启失败"
    exit 1
fi

echo ""
echo "🧪 验证配置..."
docker info | grep -A 10 "Registry Mirrors" || echo "配置已生效"

echo ""
echo "=========================================="
echo "   🎉 配置完成!"
echo "=========================================="
echo ""
echo "现在可以重新运行部署脚本:"
echo "  cd /opt/faka"
echo "  bash deploy.sh"
echo ""
