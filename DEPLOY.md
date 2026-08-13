# 🚀 Faka发卡系统 - Ubuntu服务器部署指南

## 📋 系统要求

- Ubuntu 20.04 / 22.04 或更高版本
- Python 3.8+
- Docker & Docker Compose (推荐)
- 最小配置: 1核CPU + 512MB内存

---

## 🎯 部署方式选择

### 方式1: Docker部署 (推荐⭐)
- ✅ 一键部署,环境隔离
- ✅ 自动重启,稳定可靠
- ✅ 适合新手

### 方式2: 直接部署
- ✅ 性能最优
- ✅ 资源占用小
- ⚠️ 需要手动配置环境

---

## 🐳 方式1: Docker部署 (推荐)

### 步骤1: 安装Docker

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 安装Docker Compose
sudo apt install docker-compose -y

# 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker

# 验证安装
docker --version
docker-compose --version
```

### 步骤2: 拉取项目

```bash
# 安装git
sudo apt install git -y

# 克隆项目
cd /opt
sudo git clone https://github.com/wp13461544040/faka.git
cd faka

# 设置权限
sudo chmod -R 755 /opt/faka
```

### 步骤3: 配置端口

编辑 `docker-compose.yml`:

```bash
sudo nano docker-compose.yml
```

修改端口映射(如果3019被占用):
```yaml
ports:
  - "8080:3019"  # 改成你想要的端口
```

按 `Ctrl+O` 保存, `Ctrl+X` 退出

### 步骤4: 启动服务

```bash
# 构建并启动
sudo docker-compose up -d

# 查看日志
sudo docker-compose logs -f

# 查看运行状态
sudo docker-compose ps
```

### 步骤5: 验证部署

```bash
# 测试服务
curl http://localhost:3019

# 如果看到HTML输出,说明部署成功!
```

浏览器访问: `http://你的服务器IP:3019`

### Docker常用命令

```bash
# 停止服务
sudo docker-compose down

# 重启服务
sudo docker-compose restart

# 更新代码
cd /opt/faka
sudo git pull
sudo docker-compose up -d --build

# 查看日志
sudo docker-compose logs -f

# 清理容器
sudo docker-compose down -v
```

---

## 🔧 方式2: 直接部署

### 步骤1: 安装Python环境

```bash
# 安装Python3和pip
sudo apt update
sudo apt install python3 python3-pip python3-venv -y

# 验证版本
python3 --version
pip3 --version
```

### 步骤2: 部署项目

```bash
# 克隆项目
cd /opt
sudo git clone https://github.com/wp13461544040/faka.git
cd faka

# 创建虚拟环境
python3 -m venv venv
source venv/bin/activate

# 安装依赖
pip install -r requirements.txt

# 测试运行
python app.py
```

按 `Ctrl+C` 停止测试

### 步骤3: 配置Systemd服务

创建服务文件:

```bash
sudo nano /etc/systemd/system/faka.service
```

写入以下内容:

```ini
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
```

保存并启动:

```bash
# 重载systemd
sudo systemctl daemon-reload

# 启动服务
sudo systemctl start faka

# 设置开机自启
sudo systemctl enable faka

# 查看状态
sudo systemctl status faka

# 查看日志
sudo journalctl -u faka -f
```

### Systemd常用命令

```bash
# 启动
sudo systemctl start faka

# 停止
sudo systemctl stop faka

# 重启
sudo systemctl restart faka

# 查看状态
sudo systemctl status faka

# 查看日志
sudo journalctl -u faka -n 50

# 实时查看日志
sudo journalctl -u faka -f
```

---

## 🌐 配置Nginx反向代理 (可选)

### 步骤1: 安装Nginx

```bash
sudo apt install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx
```

### 步骤2: 配置站点

```bash
sudo nano /etc/nginx/sites-available/faka
```

写入配置:

```nginx
server {
    listen 80;
    server_name your-domain.com;  # 改成你的域名或IP

    location / {
        proxy_pass http://127.0.0.1:3019;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

启用站点:

```bash
# 创建软链接
sudo ln -s /etc/nginx/sites-available/faka /etc/nginx/sites-enabled/

# 测试配置
sudo nginx -t

# 重启Nginx
sudo systemctl restart nginx
```

现在可以通过域名访问: `http://your-domain.com`

### 步骤3: 配置SSL证书 (推荐)

```bash
# 安装Certbot
sudo apt install certbot python3-certbot-nginx -y

# 自动配置SSL
sudo certbot --nginx -d your-domain.com

# 自动续期
sudo certbot renew --dry-run
```

完成后通过HTTPS访问: `https://your-domain.com`

---

## 🔒 安全配置

### 1. 配置防火墙

```bash
# 安装UFW
sudo apt install ufw -y

# 允许SSH
sudo ufw allow 22

# 允许HTTP/HTTPS
sudo ufw allow 80
sudo ufw allow 443

# 允许应用端口(如果不用Nginx)
sudo ufw allow 3019

# 启用防火墙
sudo ufw enable

# 查看状态
sudo ufw status
```

### 2. 修改默认管理员账号

首次访问: `http://你的IP:3019/july`

系统会要求设置管理员账号,请设置强密码!

**默认登录路径**: `/july` (已隐藏,不会在首页显示)

### 3. 修改登录路径 (可选)

编辑 `app.py`:

```bash
sudo nano /opt/faka/app.py
```

找到:
```python
@app.route('/july', methods=['GET', 'POST'])
```

改成你想要的路径:
```python
@app.route('/your-secret-path', methods=['GET', 'POST'])
```

保存后重启服务

### 4. 备份数据库

```bash
# 创建备份目录
mkdir -p /opt/faka/backups

# 备份数据库
cp /opt/faka/faka.db /opt/faka/backups/faka_$(date +%Y%m%d_%H%M%S).db

# 设置定时备份(每天凌晨3点)
(crontab -l 2>/dev/null; echo "0 3 * * * cp /opt/faka/faka.db /opt/faka/backups/faka_\$(date +\%Y\%m\%d).db") | crontab -
```

---

## 📊 监控与维护

### 查看系统资源

```bash
# 查看内存使用
free -h

# 查看磁盘使用
df -h

# 查看进程
htop  # 需要先安装: sudo apt install htop
```

### 查看应用日志

**Docker方式**:
```bash
sudo docker-compose logs -f --tail=100
```

**Systemd方式**:
```bash
sudo journalctl -u faka -f -n 100
```

### 更新系统

**Docker方式**:
```bash
cd /opt/faka
sudo git pull
sudo docker-compose down
sudo docker-compose up -d --build
```

**Systemd方式**:
```bash
cd /opt/faka
sudo git pull
source venv/bin/activate
pip install -r requirements.txt
sudo systemctl restart faka
```

---

## 🐛 常见问题

### 问题1: 端口被占用

```bash
# 查看端口占用
sudo netstat -tulpn | grep 3019

# 或使用lsof
sudo lsof -i :3019

# 杀死占用进程
sudo kill -9 <PID>
```

### 问题2: 权限不足

```bash
# 修复文件权限
sudo chown -R $USER:$USER /opt/faka
sudo chmod -R 755 /opt/faka
```

### 问题3: 数据库错误

```bash
# 删除数据库重新初始化
cd /opt/faka
rm faka.db
sudo systemctl restart faka  # 或 docker-compose restart
```

### 问题4: Python依赖问题

```bash
# 重新安装依赖
cd /opt/faka
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt --force-reinstall
```

### 问题5: Docker镜像构建失败

```bash
# 清理Docker缓存
sudo docker system prune -a

# 重新构建
sudo docker-compose build --no-cache
sudo docker-compose up -d
```

---

## 📝 使用流程

### 管理员首次使用

1. 访问: `http://你的IP:3019/july`
2. 设置管理员账号和密码
3. 登录后台
4. 导入卡密内容(文件或JSON)
5. 自动生成卡密列表
6. 批量复制发给用户

### 用户使用

1. 访问: `http://你的IP:3019`
2. 输入卡密
3. 提取内容
4. 卡密自动标记为已使用

### 自定义复制模板

在管理后台的"复制模板"输入框中:

```
卡密：{key}\n兑换地址：http://你的域名.com\n有效期：永久
```

复制时自动替换 `{key}` 为实际卡密

---

## 🔄 完整部署示例 (Docker方式)

```bash
# 1. 更新系统
sudo apt update && sudo apt upgrade -y

# 2. 安装Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo apt install docker-compose -y

# 3. 克隆项目
cd /opt
sudo git clone https://github.com/wp13461544040/faka.git
cd faka

# 4. 启动服务
sudo docker-compose up -d

# 5. 查看日志
sudo docker-compose logs -f

# 6. 配置防火墙
sudo ufw allow 3019
sudo ufw enable

# 完成! 访问 http://你的IP:3019
```

---

## 📞 技术支持

- **GitHub**: https://github.com/wp13461544040/faka
- **问题反馈**: 提交Issue到GitHub
- **文档更新**: 参考项目README.md

---

## 📄 开源协议

MIT License - 可自由使用、修改、商用

⚠️ **免责声明**: 本项目仅供学习交流,使用者需自行承担法律责任
