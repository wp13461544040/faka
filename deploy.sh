#!/bin/bash

# Faka发卡系统 - 一键部署脚本 (Docker版)
# 支持GitHub镜像加速

set -e

echo "=========================================="
echo "   🚀 Faka发卡系统 - Docker一键部署"
echo "=========================================="
echo ""

# GitHub镜像列表
GITHUB_MIRRORS=(
    "https://ghp.ci/"
    "https://github.moeyy.xyz/"
    "https://gh-proxy.com/"
    "https://ghproxy.cc/"
    "https://gh.ddlc.top/"
    ""  # 原始地址
)

# 项目信息
GITHUB_REPO="wp13461544040/faka"
INSTALL_DIR="/opt/faka"
PORT=3019

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检测系统
check_system() {
    print_info "检测系统环境..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
        print_success "系统: $OS $VER"
    else
        print_error "无法检测系统版本"
        exit 1
    fi
    
    echo ""
}

# 检测Docker
check_docker() {
    print_info "检测Docker环境..."
    
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version)
        print_success "Docker已安装: $DOCKER_VERSION"
    else
        print_error "未检测到Docker"
        print_warning "请先安装Docker: https://docs.docker.com/engine/install/"
        exit 1
    fi
    
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
        print_success "Docker Compose已安装"
        # 判断使用哪个命令
        if docker compose version &> /dev/null 2>&1; then
            DOCKER_COMPOSE_CMD="docker compose"
        else
            DOCKER_COMPOSE_CMD="docker-compose"
        fi
    else
        print_error "未检测到Docker Compose"
        print_warning "请先安装Docker Compose"
        exit 1
    fi
    
    echo ""
}

# 检测是否在国内
check_china_network() {
    print_info "检测网络环境..."
    
    # 测试能否访问Docker Hub
    if timeout 5 curl -s https://hub.docker.com > /dev/null 2>&1; then
        USE_CHINA_MIRROR=false
        print_success "使用国际镜像源"
    else
        USE_CHINA_MIRROR=true
        print_warning "检测到国内网络,将使用国内镜像加速"
    fi
    
    echo ""
}

# 测试GitHub镜像连接
test_github_mirror() {
    local mirror=$1
    
    if [ -z "$mirror" ]; then
        # 测试原始GitHub
        if timeout 10 git ls-remote https://github.com/${GITHUB_REPO}.git HEAD &>/dev/null; then
            return 0
        fi
    else
        # 测试镜像 - 直接尝试ls-remote
        local test_url="${mirror}https://github.com/${GITHUB_REPO}.git"
        if timeout 10 git ls-remote "$test_url" HEAD &>/dev/null; then
            return 0
        fi
    fi
    
    return 1
}

# 选择最快的GitHub镜像
select_best_mirror() {
    print_info "测试GitHub镜像连接..."
    
    for mirror in "${GITHUB_MIRRORS[@]}"; do
        if [ -z "$mirror" ]; then
            print_info "测试原始GitHub..."
        else
            print_info "测试镜像: $mirror"
        fi
        
        if test_github_mirror "$mirror"; then
            MIRROR_URL="$mirror"
            if [ -z "$mirror" ]; then
                print_success "使用原始GitHub地址"
            else
                print_success "使用镜像: $mirror"
            fi
            return 0
        fi
    done
    
    print_error "所有镜像测试失败"
    print_warning "请检查网络连接或手动克隆项目"
    exit 1
}

# 克隆或更新项目
clone_or_update() {
    select_best_mirror
    
    CLONE_URL="${MIRROR_URL}https://github.com/${GITHUB_REPO}.git"
    
    if [ -d "$INSTALL_DIR/.git" ]; then
        print_info "项目已存在,拉取最新代码..."
        cd "$INSTALL_DIR"
        
        # 备份数据
        if [ -f "instance/faka.db" ]; then
            print_info "备份数据库..."
            mkdir -p backups
            cp instance/faka.db backups/faka.db.backup.$(date +%Y%m%d_%H%M%S)
        fi
        
        # 更新代码
        git remote set-url origin "$CLONE_URL"
        if git fetch origin; then
            git reset --hard origin/main || git reset --hard origin/master
            print_success "代码更新完成"
        else
            print_error "代码更新失败"
            exit 1
        fi
    else
        print_info "下载项目代码..."
        print_info "克隆地址: $CLONE_URL"
        
        sudo rm -rf "$INSTALL_DIR"
        sudo mkdir -p "$(dirname "$INSTALL_DIR")"
        
        # 尝试克隆,失败后重试
        if ! git clone --depth 1 "$CLONE_URL" "$INSTALL_DIR"; then
            print_warning "克隆失败,尝试完整克隆..."
            if ! git clone "$CLONE_URL" "$INSTALL_DIR"; then
                print_error "代码下载失败"
                print_info "请尝试手动克隆:"
                print_info "  git clone https://github.com/${GITHUB_REPO}.git $INSTALL_DIR"
                exit 1
            fi
        fi
        
        print_success "代码下载完成"
    fi
    
    echo ""
}

# 配置Docker Compose
configure_compose() {
    print_info "配置Docker Compose..."
    
    cd "$INSTALL_DIR"
    
    # 根据网络环境选择配置文件
    if [ "$USE_CHINA_MIRROR" = true ]; then
        if [ -f "docker-compose.china.yml" ]; then
            print_info "使用国内优化配置"
            COMPOSE_FILE="docker-compose.china.yml"
        else
            print_warning "国内配置文件不存在,使用默认配置"
            COMPOSE_FILE="docker-compose.yml"
        fi
    else
        COMPOSE_FILE="docker-compose.yml"
    fi
    
    # 确保配置文件存在
    if [ ! -f "$COMPOSE_FILE" ]; then
        print_error "配置文件 $COMPOSE_FILE 不存在"
        exit 1
    fi
    
    # 创建必要目录
    sudo mkdir -p instance uploads
    sudo chmod -R 755 instance uploads
    
    print_success "配置完成 (使用: $COMPOSE_FILE)"
    echo ""
}

# 构建和启动容器
build_and_start() {
    print_info "构建Docker镜像..."
    cd "$INSTALL_DIR"
    
    # 停止旧容器
    $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" down 2>/dev/null || true
    
    # 构建镜像
    print_info "开始构建镜像 (可能需要几分钟)..."
    if $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" build --no-cache; then
        print_success "镜像构建完成"
    else
        print_error "镜像构建失败"
        print_warning "如果是网络问题,可尝试配置Docker镜像加速"
        exit 1
    fi
    
    echo ""
    print_info "启动容器..."
    
    if $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" up -d; then
        print_success "容器启动完成"
    else
        print_error "容器启动失败"
        exit 1
    fi
    
    echo ""
}

# 等待服务就绪
wait_service() {
    print_info "等待服务启动..."
    
    local max_wait=30
    local count=0
    
    while [ $count -lt $max_wait ]; do
        if curl -s http://localhost:$PORT > /dev/null 2>&1; then
            print_success "服务启动成功"
            return 0
        fi
        
        sleep 1
        count=$((count + 1))
        echo -n "."
    done
    
    echo ""
    print_warning "服务启动超时,请检查日志"
    return 1
}

# 配置防火墙
setup_firewall() {
    print_info "配置防火墙..."
    
    if command -v ufw &> /dev/null; then
        if sudo ufw status | grep -q "Status: active"; then
            sudo ufw allow $PORT/tcp
            print_success "已开放端口: $PORT"
        else
            print_warning "防火墙未启用,无需配置"
        fi
    elif command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --permanent --add-port=$PORT/tcp
        sudo firewall-cmd --reload
        print_success "已开放端口: $PORT"
    else
        print_warning "未检测到防火墙,请手动开放端口: $PORT"
    fi
    
    echo ""
}

# 显示服务状态
show_status() {
    print_info "服务状态:"
    cd "$INSTALL_DIR"
    $DOCKER_COMPOSE_CMD -f "$COMPOSE_FILE" ps
    echo ""
}

# 显示完成信息
show_result() {
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "你的服务器IP")
    
    echo ""
    echo "=========================================="
    echo "   🎉 部署完成!"
    echo "=========================================="
    echo ""
    echo "📱 访问地址:"
    echo "   用户提取: http://$SERVER_IP:$PORT"
    echo "   管理后台: http://$SERVER_IP:$PORT/july"
    echo ""
    echo "🔐 首次访问:"
    echo "   1. 访问管理后台 /july"
    echo "   2. 点击 '初始化管理员' 创建账号"
    echo "   3. 登录后开始使用"
    echo ""
    echo "📊 管理命令:"
    echo "   查看日志: cd $INSTALL_DIR && $DOCKER_COMPOSE_CMD logs -f"
    echo "   重启服务: cd $INSTALL_DIR && $DOCKER_COMPOSE_CMD restart"
    echo "   停止服务: cd $INSTALL_DIR && $DOCKER_COMPOSE_CMD down"
    echo "   更新系统: cd $INSTALL_DIR && bash deploy.sh"
    echo ""
    echo "💾 数据位置:"
    echo "   数据库: $INSTALL_DIR/instance/faka.db"
    echo "   上传文件: $INSTALL_DIR/uploads/"
    echo ""
    echo "📖 项目地址: https://github.com/$GITHUB_REPO"
    echo ""
}

# 主流程
main() {
    clear
    echo "=========================================="
    echo "   🚀 Faka发卡系统 - Docker一键部署"
    echo "=========================================="
    echo ""
    
    # 检测环境
    check_system
    check_docker
    check_china_network
    
    # 下载代码
    clone_or_update
    
    # 配置
    configure_compose
    
    # 构建启动
    build_and_start
    
    # 等待服务
    wait_service
    
    # 配置防火墙
    setup_firewall
    
    # 显示状态
    show_status
    
    # 显示结果
    show_result
}

# 执行主流程
main
