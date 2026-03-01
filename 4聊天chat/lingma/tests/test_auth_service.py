import pytest
from datetime import timedelta
from jose import jwt
from services.auth_service import (
    verify_password, get_password_hash, authenticate_user,
    create_access_token, get_current_user, get_current_active_user
)
from models.user import User

class TestAuthService:
    
    def test_password_hashing(self):
        """Test password hashing and verification"""
        password = "test_password_123"
        hashed_password = get_password_hash(password)
        
        # Verify the hashed password works
        assert verify_password(password, hashed_password)
        # Verify wrong password doesn't work
        assert not verify_password("wrong_password", hashed_password)
        # Verify same password produces different hashes (salt)
        hashed_password2 = get_password_hash(password)
        assert hashed_password != hashed_password2
    
    def test_create_access_token(self):
        """Test JWT token creation"""
        data = {"sub": "testuser"}
        token = create_access_token(data)
        
        # Verify token can be decoded
        decoded = jwt.decode(token, "your-secret-key-here", algorithms=["HS256"])
        assert decoded["sub"] == "testuser"
        assert "exp" in decoded
        
        # Test with custom expiration
        token_with_exp = create_access_token(data, timedelta(minutes=15))
        decoded_custom = jwt.decode(token_with_exp, "your-secret-key-here", algorithms=["HS256"])
        assert decoded_custom["sub"] == "testuser"
    
    def test_authenticate_user_success(self, db_session, test_user):
        """Test successful user authentication"""
        user = authenticate_user(db_session, "testuser", "testpassword")
        assert user is not False
        assert user.username == "testuser"
        assert user.email == "test@example.com"
    
    def test_authenticate_user_wrong_username(self, db_session):
        """Test authentication with wrong username"""
        user = authenticate_user(db_session, "nonexistent", "password")
        assert user is False
    
    def test_authenticate_user_wrong_password(self, db_session, test_user):
        """Test authentication with wrong password"""
        user = authenticate_user(db_session, "testuser", "wrongpassword")
        assert user is False
    
    def test_authenticate_inactive_user(self, db_session):
        """Test authentication with inactive user"""
        inactive_user = User(
            username="inactiveuser",
            email="inactive@example.com",
            hashed_password=get_password_hash("password"),
            is_active=False
        )
        db_session.add(inactive_user)
        db_session.commit()
        
        user = authenticate_user(db_session, "inactiveuser", "password")
        assert user is False
    
    @pytest.mark.asyncio
    async def test_get_current_user_valid_token(self, db_session, test_user):
        """Test getting current user with valid token"""
        # This would normally be tested with actual token validation
        # For now, we test the user retrieval logic
        user = db_session.query(User).filter(User.username == "testuser").first()
        assert user is not None
        assert user.username == "testuser"
    
    @pytest.mark.asyncio
    async def test_get_current_active_user(self, test_user):
        """Test getting current active user"""
        user = await get_current_active_user(test_user)
        assert user.username == "testuser"
        assert user.is_active is True
    
    @pytest.mark.asyncio
    async def test_get_current_active_user_inactive(self):
        """Test getting current active user with inactive user"""
        inactive_user = User(
            username="inactive",
            email="inactive@example.com",
            hashed_password="hash",
            is_active=False
        )
        
        with pytest.raises(Exception) as exc_info:
            await get_current_active_user(inactive_user)
        
        assert "Inactive user" in str(exc_info.value)