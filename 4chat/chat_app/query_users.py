from database import get_db, Base, engine
from models.user import User

# 创建数据库会话
db = next(get_db())

# 查询所有用户
users = db.query(User).all()

print("Users in database:")
for user in users:
    print(f"ID: {user.id}, Username: {user.username}, Displayname: {user.displayname}, Email: {user.email}")

# 关闭会话
db.close()