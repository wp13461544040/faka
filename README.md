# 🎫 Faka - 简易发卡系统

一个轻量级的卡密发放与管理系统,支持文件上传、JSON数据导入、批量生成卡密、自定义复制模板等功能。

[![Docker Build](https://github.com/wp13461544040/faka/actions/workflows/docker-build.yml/badge.svg)](https://github.com/wp13461544040/faka/actions)

## ⚡ 快速开始

### 一键部署到Ubuntu服务器

```bash
curl -fsSL https://get.docker.com | sh && \
sudo apt install docker-compose git -y && \
cd /opt && \
sudo git clone https://github.com/wp13461544040/faka.git && \
cd faka && \
sudo docker-compose up -d && \
echo "部署完成! 访问 http://$(curl -s ifconfig.me):3019"
```

**访问地址**: `http://你的服务器IP:3019`  
**管理后台**: `http://你的服务器IP:3019/july` (隐藏入口)

📖 **详细文档**:
- [⚡ 快速开始指南](QUICKSTART.md) - 5分钟上手
- [🚀 完整部署文档](DEPLOY.md) - Docker/直接部署/Nginx配置

---

## ✨ 功能特性

### 🎯 核心功能
- 🔑 **自动生成卡密**: 格式 `XXXX-XXXX-XXXX-XXXX`,防重复
- 📥 **灵活导入**: 支持txt文件上传、JSON数据导入
- 📋 **批量复制**: 自定义模板,一键复制多个卡密
- 🔍 **智能筛选**: 按使用状态筛选卡密
- 🗑️ **便捷管理**: 删除、导出、实时统计

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

## 📸 界面预览

### 用户提取页面
简洁的卡密提取界面,输入卡密即可获取内容

### 管理后台
- 数据统计卡片 (总数/未使用/已使用)
- 卡密导入 (文件/JSON)
- 卡密列表 (筛选/复制/删除)
- 批量操作 (全选/批量复制)

---

## 📖 使用说明

### 管理员操作

1. **首次访问** `http://你的IP:3019/july`
2. **创建管理员**账号 (用户名至少3字符,密码至少6字符)
3. **导入内容**:
   - 上传txt文件 (每行一个内容)
   - 或输入JSON数组
4. **生成卡密** (自动生成对应数量)
5. **批量复制**发给用户

### 用户操作

1. 访问 `http://你的IP:3019`
2. 输入卡密
3. 点击"提取"
4. 查看内容 (卡密自动标记为已使用)

### 自定义复制模板

在管理后台"复制模板"输入框:

```
卡密：{key}\n兑换地址：http://你的域名.com\n有效期：永久
```

使用 `{key}` 占位卡密, `\n` 或 `&#10;` 表示换行

---

## 🛠️ 技术栈

- **后端**: Flask 3.0
- **数据库**: SQLite
- **认证**: Flask-Login
- **前端**: 原生HTML/CSS/JavaScript
- **部署**: Docker + Docker Compose

---

## 📁 项目结构

```
faka/
├── app.py                    # Flask后端
├── requirements.txt          # Python依赖
├── Dockerfile               # Docker镜像
├── docker-compose.yml       # Docker编排
├── QUICKSTART.md            # 快速开始
├── DEPLOY.md                # 部署文档
├── templates/               # HTML模板
├── static/                  # 静态资源
└── .github/workflows/       # CI/CD
```

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
