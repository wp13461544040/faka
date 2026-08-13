# ⚡ 快速开始 - 5分钟部署Faka发卡系统

## 🚀 最快部署方式 (Ubuntu服务器)

### 一键部署脚本

```bash
# 复制粘贴这段代码到服务器终端,回车执行
curl -fsSL https://get.docker.com | sh && \
sudo apt install docker-compose git -y && \
cd /opt && \
sudo git clone https://github.com/wp13461544040/faka.git && \
cd faka && \
sudo docker-compose up -d && \
echo "部署完成! 访问 http://$(curl -s ifconfig.me):3019"
```

等待3-5分钟,完成后会显示访问地址!

---

## 📱 立即使用

### 1. 首次访问

浏览器打开: `http://你的服务器IP:3019/july`

**注意**: 登录路径是 `/july` (已隐藏)

### 2. 创建管理员

- 输入用户名(至少3个字符)
- 设置密码(至少6个字符)
- 确认密码
- 点击"创建管理员"

### 3. 登录后台

- 使用刚才设置的账号登录
- 进入管理界面

### 4. 生成卡密

**方式A - 上传文件**:
1. 创建 `test.txt`:
   ```
   账号1:密码1
   账号2:密码2
   账号3:密码3
   ```
2. 选择"上传文件",上传 test.txt
3. 点击"生成卡密"
4. 自动生成3个卡密

**方式B - JSON导入**:
1. 选择"JSON内容"
2. 输入:
   ```json
   [
     {"email":"user1@qq.com","password":"123456"},
     {"email":"user2@qq.com","password":"abc123"}
   ]
   ```
3. 点击"生成卡密"
4. 自动生成2个卡密

### 5. 复制卡密

- 在卡密列表点击"复制"按钮
- 或勾选多个→点"批量复制"
- 粘贴发给用户

### 6. 用户提取

用户访问: `http://你的服务器IP:3019`
- 输入卡密
- 点击"提取"
- 显示内容
- 卡密自动标记为已使用(一次性)

---

## 🎨 自定义复制模板

在管理后台找到"复制模板"输入框:

**默认模板**:
```
卡密：{key}\n兑换地址：http://127.0.0.1:3019
```

**改成你的**:
```
🎫 您的卡密：{key}\n🌐 提取地址：http://你的域名.com\n💝 客服QQ：123456789
```

**效果**:
```
🎫 您的卡密：A7B3-XY9K-2M4N-P8Q1
🌐 提取地址：http://你的域名.com
💝 客服QQ：123456789
```

---

## 🔒 安全建议

### 1. 立即修改管理员密码

登录后台 → 点击"⚙️ 账号设置" → 修改密码

### 2. 配置防火墙

```bash
sudo ufw allow 3019
sudo ufw enable
```

### 3. 使用域名+SSL (推荐)

参考 `DEPLOY.md` 中的Nginx配置

---

## 📊 常用命令

```bash
# 查看运行状态
sudo docker-compose ps

# 查看日志
sudo docker-compose logs -f

# 重启服务
sudo docker-compose restart

# 停止服务
sudo docker-compose down

# 更新系统
cd /opt/faka
sudo git pull
sudo docker-compose up -d --build
```

---

## 💡 使用技巧

### 卡密格式
自动生成格式: `XXXX-XXXX-XXXX-XXXX`
- 4组4位字符
- 大写字母+数字
- 自动防重复

### 批量操作
- 勾选多个卡密 → 批量复制
- 点击"复制全部未使用" → 一键复制所有
- 筛选"未使用" → 只看未用的

### 数据管理
- 已使用的卡密会自动置灰
- 点击"删除"按钮删除不要的卡密
- 点击"📤 导出未使用"下载txt文件

---

## 🐛 遇到问题?

### 端口被占用
```bash
# 查看占用
sudo netstat -tulpn | grep 3019

# 修改端口
sudo nano docker-compose.yml
# 把 "3019:3019" 改成 "8080:3019"
sudo docker-compose up -d
```

### 无法访问
```bash
# 检查服务状态
sudo docker-compose ps

# 检查日志
sudo docker-compose logs

# 检查防火墙
sudo ufw status
```

### 忘记密码
```bash
# 删除数据库(会清空所有数据)
sudo docker-compose down
sudo rm data/faka.db
sudo docker-compose up -d
# 重新创建管理员
```

---

## 📞 获取帮助

- 详细部署文档: `DEPLOY.md`
- GitHub项目: https://github.com/wp13461544040/faka
- 提交Issue: GitHub Issues

---

## ✅ 部署完成检查清单

- [ ] Docker服务正常运行
- [ ] 可以访问 `http://IP:3019`
- [ ] 已创建管理员账号
- [ ] 已测试生成卡密
- [ ] 已测试提取卡密
- [ ] 防火墙已配置
- [ ] (可选) 已配置域名
- [ ] (可选) 已配置SSL证书

全部完成? 🎉 恭喜你成功部署!
