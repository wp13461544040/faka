# 🎫 Faka - 简易发卡系统

一个轻量级的卡密发放与管理系统,支持文件上传、JSON数据导入、批量生成卡密、权限管理等功能。

## ✨ 功能特性

- 🎯 **卡密生成**: 批量生成唯一卡密,支持自定义数量
- 📁 **多种导入方式**: 
  - 上传txt文件(每行一个内容)
  - JSON格式导入(支持结构化数据如邮箱密码)
- 🔐 **权限控制**: 管理员登录系统,安全可靠
- 📊 **数据统计**: 实时查看卡密使用情况
- 💾 **批次管理**: 按批次组织卡密,方便管理
- 📤 **导出功能**: 一键导出未使用的卡密
- 🐳 **Docker部署**: 一键部署,开箱即用
- 📱 **响应式设计**: 完美适配移动端和PC端

## 🚀 快速开始

### 方式1: Docker Compose (推荐)

```bash
# 克隆仓库
git clone https://github.com/wp13461544040/faka.git
cd faka

# 启动服务
docker-compose up -d

# 访问 http://localhost:5000
```

### 方式2: 使用预构建镜像

```bash
# 从GitHub Container Registry拉取
docker pull ghcr.io/wp13461544040/faka:latest
docker run -d -p 5000:5000 -v $(pwd)/data:/app/data ghcr.io/wp13461544040/faka:latest

# 或从Docker Hub拉取(需要配置后可用)
# docker pull YOUR_DOCKERHUB_USERNAME/faka:latest
```

### 方式3: 本地开发运行

```bash
# 安装依赖
pip install -r requirements.txt

# 运行应用
python app.py

# 访问 http://localhost:5000
```

## 📖 使用说明

### 首次登录

- **访问地址**: `http://localhost:5000`
- **管理后台**: `http://localhost:5000/login`
- **默认账号**: `admin`
- **默认密码**: `admin123`

⚠️ **重要**: 首次登录后请立即修改默认密码!

### 创建卡密批次

1. 登录管理后台
2. 填写批次名称(如: 月卡会员)
3. 设置生成数量
4. 选择内容类型:
   
   **文件上传模式**:
   ```
   创建一个txt文件,每行一个内容:
   账号1:密码1
   账号2:密码2
   账号3:密码3
   ```
   
   **JSON模式**:
   ```json
   [
     {"email": "user1@example.com", "password": "pass123"},
     {"email": "user2@example.com", "password": "pass456"}
   ]
   ```

5. 点击"创建批次"
6. 自动生成卡密并可下载

### 提取卡密

1. 访问首页 `http://localhost:5000`
2. 输入卡密
3. 点击"提取"
4. 查看对应内容
5. 卡密自动标记为已使用(一次性)

## 🔧 配置说明

### 环境变量

在`docker-compose.yml`中可配置:

```yaml
environment:
  - FLASK_ENV=production  # 生产环境模式
```

### 数据持久化

Docker部署会自动挂载以下目录:
- `./data` - 数据库文件
- `./uploads` - 上传的文件

## 📁 项目结构

```
faka/
├── app.py                    # Flask后端主程序
├── requirements.txt          # Python依赖
├── Dockerfile               # Docker镜像构建文件
├── docker-compose.yml       # Docker编排配置
├── .github/
│   └── workflows/
│       └── docker-build.yml # GitHub Actions自动构建
├── templates/               # HTML模板
│   ├── index.html          # 用户提取页面
│   ├── login.html          # 登录页面
│   └── admin.html          # 管理后台
├── static/
│   └── style.css           # 样式文件
└── uploads/                # 上传文件目录(自动创建)
```

## 🐳 Docker镜像自动构建

本项目配置了GitHub Actions自动构建流程:

### 触发条件:
- 推送到`main`分支
- 创建新tag(如`v1.0.0`)
- Pull Request

### 构建产物:
- GitHub Container Registry: `ghcr.io/wp13461544040/faka`
- Docker Hub: 需配置Secret后可用

### 配置Docker Hub自动推送:

1. 在GitHub仓库中添加Secrets:
   - 进入仓库 → Settings → Secrets and variables → Actions
   - 添加以下Secrets:
     - `DOCKERHUB_USERNAME`: 你的Docker Hub用户名
     - `DOCKERHUB_TOKEN`: Docker Hub访问令牌

2. 获取Docker Hub Token:
   - 访问 https://hub.docker.com/settings/security
   - 点击"New Access Token"
   - 复制生成的token

3. 推送代码,自动触发构建

## 🌐 生产环境部署

### 修改默认密码

建议在生产环境中修改数据库或使用环境变量:

```python
# app.py 中修改默认管理员密码
admin = User(
    username='admin',
    password=generate_password_hash('你的强密码'),
    is_admin=True
)
```

### 使用反向代理(Nginx)

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 使用HTTPS

建议配置SSL证书,使用Let's Encrypt免费证书:

```bash
certbot --nginx -d your-domain.com
```

## 🛠️ 技术栈

- **后端**: Flask 3.0
- **数据库**: SQLite
- **认证**: Flask-Login
- **前端**: 原生HTML/CSS/JavaScript
- **部署**: Docker + Docker Compose

## 📊 数据库结构

### User (用户表)
- id: 用户ID
- username: 用户名
- password: 密码(哈希)
- is_admin: 是否管理员

### CardBatch (批次表)
- id: 批次ID
- name: 批次名称
- created_at: 创建时间
- total_cards: 总卡密数
- used_cards: 已使用数

### Card (卡密表)
- id: 卡密ID
- batch_id: 所属批次
- card_key: 卡密
- content: 内容
- is_used: 是否已使用
- used_at: 使用时间
- used_by_ip: 使用者IP

## 🤝 贡献

欢迎提交Issue和Pull Request!

## 📝 开源协议

MIT License

## ⚠️ 免责声明

本项目仅供学习交流使用,请勿用于非法用途。使用本系统产生的任何法律责任由使用者自行承担。
