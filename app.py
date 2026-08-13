from flask import Flask, render_template, request, jsonify, redirect, url_for, flash
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager, UserMixin, login_user, logout_user, login_required, current_user
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename
import secrets
import json
import os
from datetime import datetime

app = Flask(__name__)
app.config['SECRET_KEY'] = secrets.token_hex(32)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///faka.db'
app.config['UPLOAD_FOLDER'] = 'uploads'
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB

db = SQLAlchemy(app)
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'july'

os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

# 数据库模型
class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password = db.Column(db.String(200), nullable=False)
    is_admin = db.Column(db.Boolean, default=False)

class CardBatch(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    created_by = db.Column(db.Integer, db.ForeignKey('user.id'))
    total_cards = db.Column(db.Integer, default=0)
    used_cards = db.Column(db.Integer, default=0)

class Card(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    batch_id = db.Column(db.Integer, db.ForeignKey('card_batch.id'))
    card_key = db.Column(db.String(32), unique=True, nullable=False)
    content = db.Column(db.Text, nullable=False)
    is_used = db.Column(db.Boolean, default=False)
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
    
    batches = CardBatch.query.order_by(CardBatch.created_at.desc()).all()
    return render_template('admin.html', batches=batches)

@app.route('/api/create_batch', methods=['POST'])
@login_required
def create_batch():
    if not current_user.is_admin:
        return jsonify({'success': False, 'message': '无权限'}), 403
    
    batch_name = request.form.get('batch_name')
    card_count = int(request.form.get('card_count', 10))
    content_type = request.form.get('content_type')
    
    # 创建批次
    batch = CardBatch(
        name=batch_name,
        created_by=current_user.id,
        total_cards=card_count
    )
    db.session.add(batch)
    db.session.flush()
    
    cards_data = []
    
    if content_type == 'file':
        file = request.files.get('file')
        if file:
            filename = secure_filename(file.filename)
            filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            file.save(filepath)
            
            with open(filepath, 'r', encoding='utf-8') as f:
                lines = f.readlines()
                for i in range(card_count):
                    card_key = secrets.token_urlsafe(24)
                    content = lines[i].strip() if i < len(lines) else f"内容{i+1}"
                    card = Card(batch_id=batch.id, card_key=card_key, content=content)
                    db.session.add(card)
                    cards_data.append({'key': card_key, 'content': content})
    
    elif content_type == 'json':
        json_content = request.form.get('json_content')
        try:
            data = json.loads(json_content)
            for i in range(min(card_count, len(data))):
                card_key = secrets.token_urlsafe(24)
                content = json.dumps(data[i], ensure_ascii=False)
                card = Card(batch_id=batch.id, card_key=card_key, content=content)
                db.session.add(card)
                cards_data.append({'key': card_key, 'content': content})
        except json.JSONDecodeError:
            return jsonify({'success': False, 'message': 'JSON格式错误'}), 400
    
    db.session.commit()
    
    return jsonify({
        'success': True,
        'batch_id': batch.id,
        'cards': cards_data
    })

@app.route('/api/use_card', methods=['POST'])
def use_card():
    data = request.get_json()
    card_key = data.get('card_key')
    
    card = Card.query.filter_by(card_key=card_key).first()
    
    if not card:
        return jsonify({'success': False, 'message': '卡密不存在'}), 404
    
    if card.is_used:
        return jsonify({
            'success': False,
            'message': f'卡密已被使用 (使用时间: {card.used_at})'
        }), 400
    
    # 标记为已使用
    card.is_used = True
    card.used_at = datetime.utcnow()
    card.used_by_ip = request.remote_addr
    
    # 更新批次统计
    batch = CardBatch.query.get(card.batch_id)
    batch.used_cards += 1
    
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

@app.route('/api/batch/<int:batch_id>/cards')
@login_required
def get_batch_cards(batch_id):
    if not current_user.is_admin:
        return jsonify({'success': False, 'message': '无权限'}), 403
    
    cards = Card.query.filter_by(batch_id=batch_id).all()
    cards_data = [{
        'id': card.id,
        'card_key': card.card_key,
        'content': card.content,
        'is_used': card.is_used,
        'used_at': card.used_at.strftime('%Y-%m-%d %H:%M:%S') if card.used_at else None
    } for card in cards]
    
    return jsonify({'success': True, 'cards': cards_data})

@app.route('/api/export_batch/<int:batch_id>')
@login_required
def export_batch(batch_id):
    if not current_user.is_admin:
        return jsonify({'success': False, 'message': '无权限'}), 403
    
    cards = Card.query.filter_by(batch_id=batch_id, is_used=False).all()
    cards_text = '\n'.join([card.card_key for card in cards])
    
    return cards_text, 200, {
        'Content-Type': 'text/plain',
        'Content-Disposition': f'attachment; filename=batch_{batch_id}_keys.txt'
    }

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

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=3019, debug=False)
