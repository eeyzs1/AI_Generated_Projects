import os
from PIL import Image, ImageDraw, ImageFont

# 确保头像目录存在
avatar_dir = 'static/avatars'
if not os.path.exists(avatar_dir):
    os.makedirs(avatar_dir)

# 生成默认头像
def generate_default_avatar(filename, color, text):
    # 创建200x200的图像
    img = Image.new('RGB', (200, 200), color)
    draw = ImageDraw.Draw(img)
    
    # 尝试使用系统字体，如果没有则使用默认字体
    try:
        font = ImageFont.truetype('arial.ttf', 80)
    except:
        font = ImageFont.load_default()
    
    # 计算文本位置
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    x = (200 - text_width) // 2
    y = (200 - text_height) // 2
    
    # 绘制文本
    draw.text((x, y), text, fill='white', font=font)
    
    # 保存图像
    img.save(os.path.join(avatar_dir, filename))

# 生成5个默认头像
default_avatars = [
    ('default1.png', '#3498db', 'U1'),
    ('default2.png', '#2ecc71', 'U2'),
    ('default3.png', '#e74c3c', 'U3'),
    ('default4.png', '#f39c12', 'U4'),
    ('default5.png', '#9b59b6', 'U5')
]

for filename, color, text in default_avatars:
    generate_default_avatar(filename, color, text)

print('Default avatars generated successfully!')