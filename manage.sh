#!/bin/bash

# Faka发卡系统 - 管理脚本
# 提供启动、停止、重启、查看日志等功能

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 检测部署方式
detect_deployment() {
    if [ -f "docker-compose.yml" ] && command -v docker-compose &> /dev/null; then
        if sudo docker-compose ps 2>/dev/null | grep -q "faka"; then
            DEPLOY_TYPE="docker"
            return
        fi
    fi
    
    if systemctl list-units --type=service | grep -q "faka.service"; then
        DEPLOY_TYPE="systemd"
        return
    fi
    
    echo "❌ 未检测到已部署的服务"
    echo "请先部署系统: bash deploy.sh"
    exit 1
}

# 显示菜单
show_menu() {
    clear
    echo "=========================================="
    echo "   🎛️  Faka发卡系统 - 管理面板"
    echo "=========================================="
    echo ""
    echo "部署方式: $DEPLOY_TYPE"
    echo ""
    echo "1) 启动服务"
    echo "2) 停止服务"
    echo "3) 重启服务"
    echo "4) 查看状态"
    echo "5) 查看日志"
    echo "6) 更新系统"
    echo "7) 备份数据库"
    echo "8) 恢复数据库"
    echo "9) 卸载系统"
    echo "0) 退出"
    echo ""
    read -p "请选择操作 (0-9): " choice
    echo ""
}

# 启动服务
start_service() {
    echo "🚀 启动服务..."
    if [ "$DEPLOY_TYPE" = "docker" ]; then
        sudo docker-compose up -d
    else
        sudo systemctl start faka
    fi
    echo "✅ 服务已启动"
}

# 停止服务
stop_service() {
    echo "🛑 停止服务..."
    if [ "$DEPLOY_TYPE" = "docker" ]; then
        sudo docker-compose down
    else
        sudo systemctl stop faka
    fi
    echo "✅ 服务已停止"
}

# 重启服务
restart_service() {
    echo "🔄 重启服务..."
    if [ "$DEPLOY_TYPE" = "docker" ]; then
        sudo docker-compose restart
    else
        sudo systemctl restart faka
    fi
    echo "✅ 服务已重启"
}

# 查看状态
view_status() {
    echo "📊 服务状态:"
    echo ""
    if [ "$DEPLOY_TYPE" = "docker" ]; then
        sudo docker-compose ps
    else
        sudo systemctl status faka --no-pager
    fi
}

# 查看日志
view_logs() {
    echo "📜 查看日志 (按Ctrl+C退出)..."
    echo ""
    sleep 1
    if [ "$DEPLOY_TYPE" = "docker" ]; then
        sudo docker-compose logs -f --tail=100
    else
        sudo journalctl -u faka -f -n 100
    fi
}

# 更新系统
update_system() {
    echo "⬆️  更新系统..."
    echo ""
    if [ -f "update.sh" ]; then
        bash update.sh
    else
        echo "❌ 未找到update.sh脚本"
    fi
}

# 备份数据库
backup_database() {
    echo "💾 备份数据库..."
    
    BACKUP_DIR="./backups"
    mkdir -p "$BACKUP_DIR"
    BACKUP_FILE="$BACKUP_DIR/faka_$(date +%Y%m%d_%H%M%S).db"
    
    if [ -f "faka.db" ]; then
        cp faka.db "$BACKUP_FILE"
    elif [ -f "data/faka.db" ]; then
        cp data/faka.db "$BACKUP_FILE"
    else
        echo "❌ 未找到数据库文件"
        return
    fi
    
    echo "✅ 数据库已备份到: $BACKUP_FILE"
    echo ""
    echo "备份列表:"
    ls -lh "$BACKUP_DIR"
}

# 恢复数据库
restore_database() {
    echo "♻️  恢复数据库..."
    echo ""
    
    BACKUP_DIR="./backups"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "❌ 备份目录不存在"
        return
    fi
    
    echo "可用的备份:"
    ls -1 "$BACKUP_DIR"
    echo ""
    
    read -p "请输入要恢复的备份文件名: " backup_file
    
    if [ ! -f "$BACKUP_DIR/$backup_file" ]; then
        echo "❌ 备份文件不存在"
        return
    fi
    
    echo ""
    echo "⚠️  警告: 恢复数据库将覆盖当前数据!"
    read -p "是否继续? (y/n): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ 已取消恢复"
        return
    fi
    
    # 先停止服务
    stop_service
    sleep 2
    
    # 恢复数据库
    if [ -f "faka.db" ]; then
        cp "$BACKUP_DIR/$backup_file" faka.db
    elif [ -d "data" ]; then
        cp "$BACKUP_DIR/$backup_file" data/faka.db
    fi
    
    # 重启服务
    start_service
    
    echo "✅ 数据库已恢复"
}

# 卸载系统
uninstall_system() {
    echo "🗑️  卸载系统..."
    echo ""
    echo "⚠️  警告: 此操作将删除所有数据!"
    read -p "是否继续? (y/n): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ 已取消卸载"
        return
    fi
    
    # 停止服务
    if [ "$DEPLOY_TYPE" = "docker" ]; then
        sudo docker-compose down -v
    else
        sudo systemctl stop faka
        sudo systemctl disable faka
        sudo rm -f /etc/systemd/system/faka.service
        sudo systemctl daemon-reload
    fi
    
    # 询问是否删除数据
    echo ""
    read -p "是否删除所有数据? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd /opt
        sudo rm -rf faka
        echo "✅ 系统已完全卸载"
    else
        echo "✅ 服务已停止,数据已保留"
    fi
}

# 主流程
main() {
    detect_deployment
    
    while true; do
        show_menu
        
        case $choice in
            1)
                start_service
                ;;
            2)
                stop_service
                ;;
            3)
                restart_service
                ;;
            4)
                view_status
                ;;
            5)
                view_logs
                ;;
            6)
                update_system
                ;;
            7)
                backup_database
                ;;
            8)
                restore_database
                ;;
            9)
                uninstall_system
                break
                ;;
            0)
                echo "👋 再见!"
                exit 0
                ;;
            *)
                echo "❌ 无效选择"
                ;;
        esac
        
        echo ""
        read -p "按回车键继续..."
    done
}

main
