import sys
import os

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

print("Testing imports...")
try:
    from services import create_user, get_password_hash
    print("OK: Services imported successfully")

    # Test password hashing
    test_password = "password123"
    print(f"Testing password hashing for: '{test_password}' (length: {len(test_password)})")
    hashed = get_password_hash(test_password[:72])
    print("OK: Password hashed successfully")

    # Test database connection
    from database import SessionLocal
    from models import User

    db = SessionLocal()
    print("OK: Database connected")

    # Check if user exists
    existing_user = db.query(User).filter(User.username == "testuser").first()
    if existing_user:
        print(f"OK: Found existing user: {existing_user.username}")
    else:
        print("OK: No existing user found with username 'testuser'")

    db.close()
    print("OK: All tests passed!")

except Exception as e:
    import traceback
    print(f"Error: {e}")
    print(traceback.format_exc())
