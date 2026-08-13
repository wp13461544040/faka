# 🎫 Faka - 简易发卡系统

一个轻量级的卡密发放与管理系统,支持文件上传、JSON数据导入、批量生成卡密、**卡密上架/下架管理**等功能。

[![Docker Build](https://github.com/wp13461544040/faka/actions/workflows/docker-build.yml/badge.svg)](https://github.com/wp13461544040/faka/actions)

## ⚡ 快速开始

### 🐳 Ubuntu Docker一键部署 (推荐)

```bash
# 1. 下载代码
cd /opt
sudo git clone https://github.com/wp13461544040/faka.git
cd faka

# 2. 一键部署
chmod +x deploy.sh
sudo bash deploy.sh
# 选择 1) Docker部署

# 就这么简单!脚本会自动安装Docker、执行数据库迁移、启动服务
```

### 🪟 Windows本地测试

```cmd
# 双击运行
start.bat
```

**访问地址**: `http://你的服务器IP:3019`  
**管理后台**: `http://你的服务器IP:3019/july` (隐藏入口)

---

## ✨ 功能特性

### 🎯 核心功能
- 🔑 **自动生成卡密**: 格式 `XXXX-XXXX-XXXX-XXXX`,防重复
- 📥 **灵活导入**: 支持txt文件上传、JSON数据导入
- 🏪 **上架/下架管理**: 控制卡密是否可被用户兑换 (NEW!)
- 📋 **批量操作**: 批量上架/下架、批量复制
- 📊 **实时统计**: 总数/已使用/未使用/已上架/已下架
- 🔍 **智能筛选**: 按使用状态、上架状态筛选
- 🗑️ **便捷管理**: 删除、导出、自定义模板

### 🔐 安全特性
- ✅ 首次初始化自定义管理员账号
- ✅ 密码哈希存储(bcrypt)
- ✅ 隐藏后台入口(`/july`)
- ✅ 账号密码随时修改
- ✅ 权限验证,防止未授权访问

### 🎨 用户体验
- 📱 响应式设计,完美支持移动端
- 🌈 渐变紫色主题,现代化界面
- 🚀 操作流畅,无需刷新
- 📊 实时统计,数据一目了然

---

## 🆕 新功能: 卡密上架/下架管理

### 功能说明
- 每个卡密都有"上架/下架"状态,默认已上架
- **只有已上架的卡密才能被用户兑换**
- 已下架的卡密不影响查看和删除,仅用户无法兑换

### 使用场景
- 导入大批卡密,逐批上架销售
- 临时下架某些卡密
- 控制卡密发放节奏

### 操作方法
1. **单个操作**: 点击每行的"上架/下架"按钮
2. **批量操作**: 勾选多个卡密,点击"批量上架/下架"
3. **状态筛选**: 筛选器选择"已上架"或"已下架"

---

## 📖 使用说明

### 管理员操作

1. **首次访问** `http://你的IP:3019/july`
2. **创建管理员**账号 (用户名至少3字符,密码至少6字符)
3. **导入内容**:
   - 上传txt文件 (每行一个内容)
   - 或输入JSON数组
4. **生成卡密** (自动生成对应数量,默认已上架)
5. **管理状态**: 根据需要上架/下架卡密
6. **批量复制**发给用户

### 用户操作

1. 访问 `http://你的IP:3019`
2. 输入卡密
3. 点击"提取"
4. 查看内容 (卡密自动标记为已使用)

---

## 🔄 常用命令

### Docker部署
```bash
# 查看状态
sudo docker-compose ps

# 查看日志
sudo docker-compose logs -f

# 重启服务
sudo docker-compose restart

# 停止服务
sudo docker-compose down

# 一键更新
cd /opt/faka
sudo bash update.sh
```

### Systemd部署
```bash
# 查看状态
sudo systemctl status faka

# 查看日志
sudo journalctl -u faka -f

# 重启服务
sudo systemctl restart faka

# 一键更新
cd /opt/faka
sudo bash update.sh
```

---

## 🛠️ 技术栈

- **后端**: Flask 3.0 + SQLAlchemy
- **数据库**: SQLite
- **认证**: Flask-Login + Bcrypt
- **前端**: 原生HTML/CSS/JavaScript
- **部署**: Docker + Docker Compose / Systemd

---

## 📁 项目结构

```
faka/
├── app.py                    # Flask后端
├── requirements.txt          # Python依赖
├── deploy.sh                # 一键部署脚本
├── update.sh                # 一键更新脚本
├── start.bat                # Windows启动脚本
├── Dockerfile               # Docker镜像
├── docker-compose.yml       # Docker编排
├── templates/               # HTML模板
│   ├── index.html          # 用户提取页
│   ├── admin.html          # 管理后台
│   ├── login.html          # 登录页
│   └── init.html           # 初始化页
├── static/                  # 静态资源
│   └── style.css           # 样式
└── instance/                # 数据目录(自动创建)
    └── faka.db             # SQLite数据库
```

---

## 🐛 常见问题

### Q: 如何修改端口?
编辑 `app.py` 最后一行或 `docker-compose.yml` 的端口映射

### Q: 如何修改管理后台路径?
编辑 `app.py` 中的 `@app.route('/july', ...)` 改成你想要的路径

### Q: 如何备份数据?
数据库文件: `instance/faka.db`,直接复制即可

### Q: 更新后功能异常?
运行 `sudo bash update.sh` 会自动执行数据库迁移

---

## 🐳 Docker镜像

本项目通过GitHub Actions自动构建:

- **GitHub Container Registry**: `ghcr.io/wp13461544040/faka:latest`
- **触发条件**: 推送到main分支或创建tag

---

## 🤝 贡献

欢迎提交Issue和Pull Request!

## 📝 开源协议

MIT License

## ⚠️ 免责声明

本项目仅供学习交流使用,使用者需自行承担法律责任。
