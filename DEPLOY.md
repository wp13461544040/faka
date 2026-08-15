# 一键部署升级指南

## 快速开始

### 一键部署升级命令

```bash
curl -fsSL https://raw.githubusercontent.com/你的用户名/faka/main/deploy-upgrade.sh | sudo bash
```

或者手动执行：

```bash
# 1. 克隆或进入项目目录
cd /opt
git clone https://github.com/你的用户名/faka.git
cd faka

# 2. 赋予执行权限
chmod +x deploy-upgrade.sh

# 3. 执行部署升级
sudo ./deploy-upgrade.sh
```

---

## 首次部署（全新安装）

### 方法1：使用一键脚本

```bash
# 下载并执行安装脚本
curl -fsSL https://raw.githubusercontent.com/你的用户名/faka/main/install.sh | sudo bash
```

### 方法2：手动安装

#### 1. 安装依赖

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装Docker
curl -fsSL https://get.docker.com | sudo sh

# 安装Docker Compose
sudo apt install -y docker-compose

# 配置Docker镜像加速（中国用户）
chmod +x docker-mirror-setup.sh
sudo ./docker-mirror-setup.sh
```

#### 2. 克隆项目

```bash
cd /opt
sudo git clone https://github.com/你的用户名/faka.git
cd faka
```

#### 3. 启动服务

```bash
# 使用中国镜像
sudo docker-compose -f docker-compose.china.yml up -d

# 或使用国际镜像
sudo docker-compose up -d
```

#### 4. 访问系统

- 首页：http://服务器IP:3019
- 管理后台：http://服务器IP:3019/july

首次访问会自动跳转到初始化页面，创建管理员账号。

---

## 升级现有系统

### 自动升级（推荐）

```bash
cd /opt/faka
sudo ./deploy-upgrade.sh
```

### 手动升级

```bash
# 1. 停止服务
sudo docker-compose -f docker-compose.china.yml down

# 2. 备份数据
sudo cp -r instance instance.backup.$(date +%Y%m%d_%H%M%S)

# 3. 拉取最新代码
sudo git pull origin main

# 4. 数据库升级
python3 upgrade.py

# 5. 重新构建并启动
sudo docker-compose -f docker-compose.china.yml up -d --build
```

---

## 升级脚本说明

`deploy-upgrade.sh` 会自动执行以下步骤：

1. ✅ 停止现有服务
2. ✅ 拉取最新代码
3. ✅ 自动备份并升级数据库
4. ✅ 重新构建Docker镜像
5. ✅ 启动服务并验证

---

## 常用命令

### 服务管理

```bash
# 启动服务
sudo docker-compose -f docker-compose.china.yml up -d

# 停止服务
sudo docker-compose -f docker-compose.china.yml down

# 重启服务
sudo docker-compose -f docker-compose.china.yml restart

# 查看状态
sudo docker-compose -f docker-compose.china.yml ps

# 查看日志
sudo docker-compose -f docker-compose.china.yml logs -f

# 查看最近50行日志
sudo docker-compose -f docker-compose.china.yml logs --tail=50
```

### 数据库管理

```bash
# 手动数据库升级
python3 upgrade.py

# 数据库备份
sudo cp -r instance instance.backup.$(date +%Y%m%d_%H%M%S)

# 数据库恢复（替换日期时间）
sudo cp -r instance.backup.20260815_120000 instance
```

### 容器管理

```bash
# 进入容器
sudo docker exec -it faka-app bash

# 查看容器资源使用
sudo docker stats faka-app

# 清理未使用的镜像
sudo docker system prune -a
```

---

## 防火墙配置

### UFW（Ubuntu默认）

```bash
# 允许3019端口
sudo ufw allow 3019/tcp

# 查看状态
sudo ufw status
```

### iptables

```bash
# 允许3019端口
sudo iptables -A INPUT -p tcp --dport 3019 -j ACCEPT

# 保存规则
sudo netfilter-persistent save
```

---

## 反向代理配置（可选）

### Nginx

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:3019;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Caddy

```caddy
your-domain.com {
    reverse_proxy localhost:3019
}
```

---

## 自动备份（推荐）

### 创建备份脚本

```bash
sudo nano /opt/faka/backup.sh
```

内容：

```bash
#!/bin/bash
BACKUP_DIR="/opt/faka-backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR
cp -r /opt/faka/instance $BACKUP_DIR/instance.$DATE

# 保留最近30天的备份
find $BACKUP_DIR -type d -name "instance.*" -mtime +30 -exec rm -rf {} \;
```

### 设置定时任务

```bash
# 编辑crontab
sudo crontab -e

# 添加每天凌晨2点自动备份
0 2 * * * /bin/bash /opt/faka/backup.sh
```

---

## 性能优化

### Docker资源限制

```yaml
# 在docker-compose.china.yml中添加
services:
  faka:
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
```

### 数据库优化

对于大量卡密的情况，建议定期清理：

```sql
-- 删除30天前已使用的卡密
DELETE FROM card WHERE is_used = 1 AND used_at < datetime('now', '-30 days');
```

---

## 监控和日志

### 日志文件位置

```bash
# Docker容器日志
sudo docker logs faka-app

# 应用日志（如果有）
sudo docker exec faka-app tail -f /app/logs/app.log
```

### 监控服务状态

```bash
# 创建监控脚本
sudo nano /opt/faka/monitor.sh
```

内容：

```bash
#!/bin/bash
if ! docker ps | grep -q faka-app; then
    echo "服务已停止，正在重启..."
    cd /opt/faka
    docker-compose -f docker-compose.china.yml up -d
    echo "服务已重启于 $(date)" >> /var/log/faka-monitor.log
fi
```

设置定时检查：

```bash
sudo crontab -e
# 每5分钟检查一次
*/5 * * * * /bin/bash /opt/faka/monitor.sh
```

---

## 故障排查

### 服务无法启动

```bash
# 查看详细日志
sudo docker-compose -f docker-compose.china.yml logs

# 检查端口占用
sudo netstat -tulpn | grep 3019

# 检查Docker状态
sudo systemctl status docker
```

### 数据库升级失败

```bash
# 查看备份文件
ls -la instance/faka.db.backup_*

# 恢复备份
cp instance/faka.db.backup_最新时间戳 instance/faka.db

# 重新升级
python3 upgrade.py
```

### 访问缓慢

```bash
# 检查资源使用
sudo docker stats faka-app

# 检查磁盘空间
df -h

# 清理Docker缓存
sudo docker system prune -a
```

---

## 安全建议

1. **修改默认端口**：在 docker-compose.china.yml 中修改端口映射
2. **使用HTTPS**：配置Nginx/Caddy反向代理+SSL证书
3. **定期备份**：设置自动备份脚本
4. **强密码**：管理员账号使用复杂密码
5. **防火墙**：只开放必要端口
6. **定期更新**：保持系统和依赖最新

---

## 卸载

```bash
# 停止并删除容器
sudo docker-compose -f docker-compose.china.yml down -v

# 删除项目文件（谨慎操作）
sudo rm -rf /opt/faka

# 删除Docker镜像
sudo docker rmi faka-app
```

---

## 技术支持

- 文档：查看 README.md
- 问题：提交 GitHub Issues
- 升级：查看 UPDATE_LOG.md

---

**重要提醒**：
- 升级前务必备份数据库
- 生产环境建议先在测试环境验证
- 保留至少一个备份文件直到确认升级成功
