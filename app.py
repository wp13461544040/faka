from flask import Flask, render_template, request, jsonify, redirect, url_for, flash
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager, UserMixin, login_user, logout_user, login_required, current_user
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename
import secrets
import json
import os
import random
import string
from datetime import datetime, timezone, timedelta

app = Flask(__name__)
app.config['SECRET_KEY'] = secrets.token_hex(32)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///faka.db'
app.config['UPLOAD_FOLDER'] = 'uploads'
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB

db = SQLAlchemy(app)
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'  # 这里要用函数名不是路由

os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

# Jinja2 时间格式化过滤器
@app.template_filter('format_time')
def format_time(dt):
    """格式化时间为东八区时间字符串"""
    if not dt:
        return '-'
    # 如果有时区信息,直接格式化
    if dt.tzinfo:
        return dt.strftime('%Y-%m-%d %H:%M:%S')
    # 如果没有时区信息,视为UTC+8
    return dt.strftime('%Y-%m-%d %H:%M:%S')

# 生成卡密函数
def generate_card_key():
    """生成格式为 xxxx-xxxx-xxxx-xxxx 的卡密"""
    chars = string.ascii_uppercase + string.digits  # A-Z和0-9
    parts = []
    for _ in range(4):
        part = ''.join(random.choices(chars, k=4))
        parts.append(part)
    return '-'.join(parts)

# 获取东八区当前时间
def get_beijing_time():
    """返回UTC+8时区的当前时间"""
    return datetime.now(timezone(timedelta(hours=8)))

# 数据库模型
class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password = db.Column(db.String(200), nullable=False)
    is_admin = db.Column(db.Boolean, default=False)

class CardBatch(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    created_at = db.Column(db.DateTime, default=get_beijing_time)
    created_by = db.Column(db.Integer, db.ForeignKey('user.id'))
    total_cards = db.Column(db.Integer, default=0)
    used_cards = db.Column(db.Integer, default=0)
    description = db.Column(db.String(200))  # 批次描述

class Card(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    batch_id = db.Column(db.Integer, db.ForeignKey('card_batch.id'))
    card_key = db.Column(db.String(32), unique=True, nullable=False)
    content = db.Column(db.Text, nullable=False)
    is_used = db.Column(db.Boolean, default=False)
    is_listed = db.Column(db.Boolean, default=True)  # 新增:是否上架
    used_at = db.Column(db.DateTime)
    used_by_ip = db.Column(db.String(50))

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

# 初始化数据库
with app.app_context():
    db.create_all()

# 路由
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/july', methods=['GET', 'POST'])
def login():
    # 检查是否首次运行(无管理员)
    if User.query.count() == 0:
        return redirect(url_for('init_admin'))
    
    if request.method == 'POST':
        data = request.get_json()
        username = data.get('username')
        password = data.get('password')
        
        user = User.query.filter_by(username=username).first()
        if user and check_password_hash(user.password, password):
            login_user(user)
            return jsonify({'success': True, 'is_admin': user.is_admin})
        return jsonify({'success': False, 'message': '用户名或密码错误'}), 401
    
    return render_template('login.html')

@app.route('/init', methods=['GET', 'POST'])
def init_admin():
    # 如果已有管理员,跳转到登录页
    if User.query.count() > 0:
        return redirect(url_for('login'))
    
    if request.method == 'POST':
        data = request.get_json()
        username = data.get('username', '').strip()
        password = data.get('password', '').strip()
        confirm_password = data.get('confirm_password', '').strip()
        
        if not username or len(username) < 3:
            return jsonify({'success': False, 'message': '用户名至少3个字符'}), 400
        
        if not password or len(password) < 6:
            return jsonify({'success': False, 'message': '密码至少6个字符'}), 400
        
        if password != confirm_password:
            return jsonify({'success': False, 'message': '两次密码不一致'}), 400
        
        # 创建管理员
        admin = User(
            username=username,
            password=generate_password_hash(password),
            is_admin=True
        )
        db.session.add(admin)
        db.session.commit()
        
        return jsonify({'success': True, 'message': '管理员创建成功'})
    
    return render_template('init.html')

@app.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('index'))

@app.route('/admin')
@login_required
def admin():
    if not current_user.is_admin:
        flash('无权限访问')
        return redirect(url_for('index'))
    
    # 直接获取所有卡密,按创建时间倒序
    cards = Card.query.order_by(Card.id.desc()).all()
    
    # 统计信息
    total_cards = Card.query.count()
    used_cards = Card.query.filter_by(is_used=True).count()
    unused_cards = total_cards - used_cards
    listed_cards = Card.query.filter_by(is_listed=True).count()
    unlisted_cards = Card.query.filter_by(is_listed=False).count()
    
    return render_template('admin.html', 
                         cards=cards,
                         total_cards=total_cards,
                         used_cards=used_cards,
                         unused_cards=unused_cards,
                         listed_cards=listed_cards,
                         unlisted_cards=unlisted_cards)

@app.route('/api/create_batch', methods=['POST'])
@login_required
def create_batch():
    if not current_user.is_admin:
        return jsonify({'success': False, 'message': '无权限'}), 403
    
    content_type = request.form.get('content_type')
    
    cards_data = []
    content_list = []
    
    # 解析内容
    if content_type == 'file':
        file = request.files.get('file')
        if not file:
            return jsonify({'success': False, 'message': '请上传文件'}), 400
        
        filename = secure_filename(file.filename)
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(filepath)
        
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()
            content_list = [line.strip() for line in lines if line.strip()]
        
        # 删除临时文件
        os.remove(filepath)
    
    elif content_type == 'json':
        json_content = request.form.get('json_content', '').strip()
        if not json_content:
            return jsonify({'success': False, 'message': '请输入JSON内容'}), 400
        
        try:
            data = json.loads(json_content)
            if not isinstance(data, list):
                return jsonify({'success': False, 'message': 'JSON必须是数组格式'}), 400
            content_list = [json.dumps(item, ensure_ascii=False) for item in data]
        except json.JSONDecodeError:
            return jsonify({'success': False, 'message': 'JSON格式错误'}), 400
    else:
        return jsonify({'success': False, 'message': '请选择内容类型'}), 400
    
    if not content_list:
        return jsonify({'success': False, 'message': '内容为空'}), 400
    
    # 直接生成卡密,不创建批次
    for content in content_list:
        # 生成唯一卡密
        while True:
            card_key = generate_card_key()
            # 检查是否重复
            if not Card.query.filter_by(card_key=card_key).first():
                break
        
        card = Card(
            batch_id=None,  # 不需要批次ID
            card_key=card_key,
            content=content,
            is_listed=False  # 默认下架
        )
        db.session.add(card)
        cards_data.append({'key': card_key, 'content': content})
    
    db.session.commit()
    
    return jsonify({
        'success': True,
        'total': len(content_list),
        'cards': cards_data
    })

@app.route('/api/use_card', methods=['POST'])
def use_card():
    data = request.get_json()
    card_key = data.get('card_key')
    
    card = Card.query.filter_by(card_key=card_key).first()
    
    if not card:
        return jsonify({'success': False, 'message': '卡密不存在'}), 404
    
    if not card.is_listed:
        return jsonify({'success': False, 'message': '该卡密未上架,暂不可用'}), 400
    
    if card.is_used:
        # 格式化时间为东八区显示
        used_time = card.used_at.strftime('%Y-%m-%d %H:%M:%S') if card.used_at else '未知'
        return jsonify({
            'success': False,
            'message': f'卡密已被使用 (使用时间: {used_time})'
        }), 400
    
    # 标记为已使用
    card.is_used = True
    card.used_at = get_beijing_time()
    card.used_by_ip = request.remote_addr
    
    db.session.commit()
    
    # 尝试解析JSON内容
    try:
        content_data = json.loads(card.content)
    except:
        content_data = card.content
    
    return jsonify({
        'success': True,
        'content': content_data
    })

@app.route('/api/export_cards')
@login_required
def export_cards():
    if not current_user.is_admin:
        return jsonify({'success': False, 'message': '无权限'}), 403
    
    filter_type = request.args.get('type', 'unused')
    
    if filter_type == 'unused':
        cards = Card.query.filter_by(is_used=False).all()
    elif filter_type == 'used':
        cards = Card.query.filter_by(is_used=True).all()
    else:
        cards = Card.query.all()
    
    cards_text = '\n'.join([card.card_key for card in cards])
    
    return cards_text, 200, {
        'Content-Type': 'text/plain; charset=utf-8',
        'Content-Disposition': f'attachment; filename=cards_{filter_type}.txt'
    }

@app.route('/api/delete_card/<int:card_id>', methods=['DELETE'])
@login_required
def delete_card(card_id):
    if not current_user.is_admin:
        return jsonify({'success': False, 'message': '无权限'}), 403
    
    card = Card.query.get(card_id)
    if not card:
        return jsonify({'success': False, 'message': '卡密不存在'}), 404
    
    db.session.delete(card)
    db.session.commit()
    
    return jsonify({'success': True, 'message': '删除成功'})

@app.route('/api/change_password', methods=['POST'])
@login_required
def change_password():
    if not current_user.is_admin:
        return jsonify({'success': False, 'message': '无权限'}), 403
    
    data = request.get_json()
    old_password = data.get('old_password', '').strip()
    new_password = data.get('new_password', '').strip()
    confirm_password = data.get('confirm_password', '').strip()
    
    if not check_password_hash(current_user.password, old_password):
        return jsonify({'success': False, 'message': '原密码错误'}), 400
    
    if len(new_password) < 6:
        return jsonify({'success': False, 'message': '新密码至少6个字符'}), 400
    
    if new_password != confirm_password:
        return jsonify({'success': False, 'message': '两次密码不一致'}), 400
    
    current_user.password = generate_password_hash(new_password)
    db.session.commit()
    
    return jsonify({'success': True, 'message': '密码修改成功'})

@app.route('/api/change_username', methods=['POST'])
@login_required
def change_username():
    if not current_user.is_admin:
        return jsonify({'success': False, 'message': '无权限'}), 403
    
    data = request.get_json()
    new_username = data.get('new_username', '').strip()
    password = data.get('password', '').strip()
    
    if not check_password_hash(current_user.password, password):
        return jsonify({'success': False, 'message': '密码错误'}), 400
    
    if len(new_username) < 3:
        return jsonify({'success': False, 'message': '用户名至少3个字符'}), 400
    
    # 检查用户名是否已存在
    existing_user = User.query.filter_by(username=new_username).first()
    if existing_user and existing_user.id != current_user.id:
        return jsonify({'success': False, 'message': '用户名已存在'}), 400
    
    current_user.username = new_username
    db.session.commit()
    
    return jsonify({'success': True, 'message': '用户名修改成功'})

@app.route('/api/toggle_card_status/<int:card_id>', methods=['POST'])
@login_required
def toggle_card_status(card_id):
    if not current_user.is_admin:
        return jsonify({'success': False, 'message': '无权限'}), 403
    
    card = Card.query.get(card_id)
    if not card:
        return jsonify({'success': False, 'message': '卡密不存在'}), 404
    
    card.is_listed = not card.is_listed
    db.session.commit()
    
    status_text = '已上架' if card.is_listed else '已下架'
    return jsonify({'success': True, 'message': f'卡密{status_text}', 'is_listed': card.is_listed})

@app.route('/api/batch_toggle_status', methods=['POST'])
@login_required
def batch_toggle_status():
    if not current_user.is_admin:
        return jsonify({'success': False, 'message': '无权限'}), 403
    
    data = request.get_json()
    card_ids = data.get('card_ids', [])
    is_listed = data.get('is_listed', True)
    
    if not card_ids:
        return jsonify({'success': False, 'message': '未选择卡密'}), 400
    
    Card.query.filter(Card.id.in_(card_ids)).update({'is_listed': is_listed}, synchronize_session=False)
    db.session.commit()
    
    status_text = '上架' if is_listed else '下架'
    return jsonify({'success': True, 'message': f'成功{status_text} {len(card_ids)} 个卡密'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=3019, debug=False)
