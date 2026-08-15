#!/usr/bin/env python3
"""
一键升级脚本
功能：
1. 备份现有数据库
2. 检测并迁移数据库结构
3. 数据适配和修复
4. 验证升级结果
"""

import sqlite3
import os
import shutil
from datetime import datetime, timezone, timedelta

class DatabaseUpgrade:
    def __init__(self, db_path='instance/faka.db'):
        self.db_path = db_path
        self.backup_path = None
        
    def get_beijing_time(self):
        """获取东八区当前时间"""
        return datetime.now(timezone(timedelta(hours=8)))
    
    def backup_database(self):
        """备份数据库"""
        if not os.path.exists(self.db_path):
            print(f"❌ 数据库文件不存在: {self.db_path}")
            return False
        
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        self.backup_path = f"{self.db_path}.backup_{timestamp}"
        
        try:
            shutil.copy2(self.db_path, self.backup_path)
            print(f"✅ 数据库备份成功: {self.backup_path}")
            return True
        except Exception as e:
            print(f"❌ 数据库备份失败: {e}")
            return False
    
    def get_table_columns(self, cursor, table_name):
        """获取表的所有列名"""
        cursor.execute(f"PRAGMA table_info({table_name})")
        return [column[1] for column in cursor.fetchall()]
    
    def table_exists(self, cursor, table_name):
        """检查表是否存在"""
        cursor.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
            (table_name,)
        )
        return cursor.fetchone() is not None
    
    def migrate_card_table(self, cursor):
        """迁移Card表结构"""
        print("\n📋 检查Card表结构...")
        
        if not self.table_exists(cursor, 'card'):
            print("⚠️  Card表不存在，跳过迁移")
            return True
        
        columns = self.get_table_columns(cursor, 'card')
        migrations_needed = []
        
        # 检查需要添加的字段
        required_fields = {
            'used_count': ('INTEGER', 0),
            'max_use_count': ('INTEGER', 3),
        }
        
        for field, (field_type, default_value) in required_fields.items():
            if field not in columns:
                migrations_needed.append((field, field_type, default_value))
        
        if not migrations_needed:
            print("✅ Card表结构已是最新")
            return True
        
        # 执行字段添加
        for field, field_type, default_value in migrations_needed:
            try:
                print(f"  添加字段: {field} ({field_type})")
                cursor.execute(
                    f"ALTER TABLE card ADD COLUMN {field} {field_type} DEFAULT {default_value}"
                )
            except sqlite3.OperationalError as e:
                if "duplicate column name" in str(e).lower():
                    print(f"  ⚠️  字段 {field} 已存在")
                else:
                    raise
        
        print("✅ Card表结构迁移完成")
        return True
    
    def migrate_data(self, cursor):
        """数据迁移和适配"""
        print("\n📊 执行数据迁移...")
        
        # 检查是否需要迁移已使用卡密的数据
        columns = self.get_table_columns(cursor, 'card')
        
        if 'used_count' in columns and 'is_used' in columns:
            # 统计需要迁移的数据
            cursor.execute("SELECT COUNT(*) FROM card WHERE is_used = 1 AND used_count = 0")
            need_migrate = cursor.fetchone()[0]
            
            if need_migrate > 0:
                print(f"  发现 {need_migrate} 个已使用卡密需要更新使用次数")
                cursor.execute(
                    "UPDATE card SET used_count = 3 WHERE is_used = 1 AND used_count = 0"
                )
                print(f"  ✅ 已将 {need_migrate} 个已使用卡密的使用次数设为3")
            else:
                print("  ✅ 所有卡密数据已是最新状态")
        
        return True
    
    def verify_upgrade(self, cursor):
        """验证升级结果"""
        print("\n🔍 验证升级结果...")
        
        # 检查表结构
        if not self.table_exists(cursor, 'card'):
            print("❌ Card表不存在")
            return False
        
        columns = self.get_table_columns(cursor, 'card')
        required_columns = ['used_count', 'max_use_count']
        
        missing_columns = [col for col in required_columns if col not in columns]
        if missing_columns:
            print(f"❌ 缺少必需字段: {', '.join(missing_columns)}")
            return False
        
        # 统计数据
        cursor.execute("SELECT COUNT(*) FROM card")
        total_cards = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM card WHERE is_used = 1")
        used_cards = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM card WHERE is_used = 0")
        unused_cards = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM card WHERE used_count > 0")
        has_used_count = cursor.fetchone()[0]
        
        print("\n📈 数据库统计:")
        print(f"  总卡密数: {total_cards}")
        print(f"  已使用: {used_cards}")
        print(f"  未使用: {unused_cards}")
        print(f"  有使用记录: {has_used_count}")
        
        print("\n✅ 升级验证通过")
        return True
    
    def run(self):
        """执行完整升级流程"""
        print("=" * 60)
        print("🚀 开始数据库升级")
        print("=" * 60)
        
        # 1. 备份数据库
        if not self.backup_database():
            return False
        
        # 2. 连接数据库
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
        except Exception as e:
            print(f"❌ 连接数据库失败: {e}")
            return False
        
        try:
            # 3. 迁移表结构
            if not self.migrate_card_table(cursor):
                conn.rollback()
                return False
            
            # 4. 迁移数据
            if not self.migrate_data(cursor):
                conn.rollback()
                return False
            
            # 5. 提交更改
            conn.commit()
            print("\n✅ 数据库更改已提交")
            
            # 6. 验证升级
            if not self.verify_upgrade(cursor):
                print("\n⚠️  验证失败，建议检查数据库状态")
                print(f"如需回滚，使用备份文件: {self.backup_path}")
                return False
            
        except Exception as e:
            conn.rollback()
            print(f"\n❌ 升级失败: {e}")
            print(f"数据库已回滚，备份文件: {self.backup_path}")
            return False
        
        finally:
            conn.close()
        
        print("\n" + "=" * 60)
        print("🎉 升级完成!")
        print("=" * 60)
        print(f"\n💾 备份文件已保存: {self.backup_path}")
        print("📝 如遇问题可使用备份文件恢复")
        print("\n🔄 建议重启应用以确保所有更改生效")
        
        return True
    
    def rollback(self):
        """回滚到备份"""
        if not self.backup_path or not os.path.exists(self.backup_path):
            print("❌ 未找到备份文件")
            return False
        
        try:
            shutil.copy2(self.backup_path, self.db_path)
            print(f"✅ 已回滚到备份: {self.backup_path}")
            return True
        except Exception as e:
            print(f"❌ 回滚失败: {e}")
            return False


def main():
    """主函数"""
    print("\n" + "=" * 60)
    print("  卡密系统 - 数据库升级工具")
    print("=" * 60)
    print("\n此工具将自动:")
    print("  1. 备份现有数据库")
    print("  2. 迁移数据库结构")
    print("  3. 适配现有数据")
    print("  4. 验证升级结果")
    print("\n" + "=" * 60)
    
    # 检查数据库文件
    db_path = 'instance/faka.db'
    if not os.path.exists(db_path):
        print(f"\n❌ 数据库文件不存在: {db_path}")
        print("如果是首次运行，请先启动应用创建数据库")
        return
    
    # 确认升级
    print("\n⚠️  升级前会自动备份数据库")
    confirm = input("是否继续? (y/n): ").strip().lower()
    
    if confirm != 'y':
        print("❌ 已取消升级")
        return
    
    # 执行升级
    upgrader = DatabaseUpgrade(db_path)
    success = upgrader.run()
    
    if not success:
        print("\n是否回滚到备份? (y/n): ", end='')
        rollback_confirm = input().strip().lower()
        if rollback_confirm == 'y':
            upgrader.rollback()


if __name__ == '__main__':
    main()
