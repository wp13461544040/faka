#!/bin/bash

echo "========================================"
echo "  配置Docker中国镜像加速"
echo "========================================"
echo ""

# 创建docker配置目录
sudo mkdir -p /etc/docker

# 配置镜像加速器
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.ccs.tencentyun.com"
  ]
}
EOF

echo ""
echo "✅ 镜像配置已写入 /etc/docker/daemon.json"
echo ""

# 重启Docker服务
echo "正在重启Docker服务..."
sudo systemctl daemon-reload
sudo systemctl restart docker

echo ""
echo "✅ Docker服务已重启"
echo ""
echo "验证配置:"
docker info | grep -A 10 "Registry Mirrors"

echo ""
echo "========================================"
echo "  配置完成！"
echo "========================================"
