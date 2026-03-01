# Chat Application

A modern, full-stack chat application built with Python/FastAPI backend and React/TypeScript frontend, featuring real-time messaging, user authentication, and responsive design.

## 🌟 Features

- **🔐 Secure Authentication**: JWT-based user registration and login system
- **💬 Real-time Messaging**: WebSocket-powered instant messaging between users
- **🏠 Chat Rooms**: Create and join multiple chat rooms with different participants
- **👥 User Presence**: Real-time online/offline status tracking
- **📱 Responsive Design**: Mobile-friendly interface that works on all devices
- **🐳 Docker Support**: Easy containerized deployment options

## 🏗️ Tech Stack

### Backend
- **[FastAPI](https://fastapi.tiangolo.com/)** - High-performance Python web framework
- **[SQLAlchemy](https://www.sqlalchemy.org/)** - SQL toolkit and ORM
- **[MySQL](https://www.mysql.com/)** - Relational database management
- **[Pydantic](https://docs.pydantic.dev/)** - Data validation and settings management
- **[JWT](https://jwt.io/)** - JSON Web Token authentication
- **WebSocket** - Real-time bidirectional communication

### Frontend
- **[React](https://reactjs.org/)** - JavaScript library for building user interfaces
- **[TypeScript](https://www.typescriptlang.org/)** - Typed superset of JavaScript
- **[CSS3](https://developer.mozilla.org/en-US/docs/Web/CSS)** - Modern styling and responsive design

## 📁 Project Structure

```
chat_app/
├── main.py                 # FastAPI application entry point
├── database.py            # Database configuration and connection
├── models/                # SQLAlchemy data models
│   ├── user.py           # User entity model
│   ├── room.py           # Chat room model
│   └── message.py        # Message model
├── schemas/               # Pydantic validation schemas
│   ├── user.py           # User data validation
│   ├── room.py           # Room data validation
│   └── message.py        # Message data validation
├── services/              # Business logic services
│   ├── auth_service.py   # Authentication and JWT handling
│   ├── chat_service.py   # Chat room and messaging logic
│   └── ws_service.py     # WebSocket connection management
├── frontend/              # React frontend application
│   ├── public/
│   │   └── index.html    # HTML template
│   ├── src/
│   │   ├── App.tsx       # Main application component
│   │   ├── Login.tsx     # User login interface
│   │   ├── Register.tsx  # User registration interface
│   │   ├── ChatRoom.tsx  # Main chat interface
│   │   ├── UserList.tsx  # Online users display
│   │   └── App.css       # Application styling
│   └── package.json      # Frontend dependencies
├── Dockerfile             # Docker container configuration
├── docker-compose.yml     # Multi-service orchestration
├── requirements.txt       # Python dependencies
├── .env.example          # Environment configuration template
├── arch.md               # Architecture documentation
└── README.md             # This documentation
```

## 🚀 Quick Start

### Prerequisites
- Python 3.9 or higher
- Node.js 16 or higher
- MySQL 8.0 or higher
- Docker (optional, for containerized deployment)

### Method 1: Manual Installation

#### Backend Setup

1. **Clone and navigate to project directory:**
```bash
git clone <repository-url>
cd chat_app
```

2. **Create virtual environment:**
```bash
python -m venv venv
# On Windows:
venv\Scripts\activate
# On macOS/Linux:
source venv/bin/activate
```

3. **Install Python dependencies:**
```bash
pip install -r requirements.txt
```

4. **Set up MySQL database:**
```sql
CREATE DATABASE chat_app;
CREATE USER 'chatuser'@'localhost' IDENTIFIED BY 'chatpassword';
GRANT ALL PRIVILEGES ON chat_app.* TO 'chatuser'@'localhost';
FLUSH PRIVILEGES;
```

5. **Configure environment variables:**
```bash
cp .env.example .env
```
Edit `.env` file with your database configuration:
```env
DATABASE_URL=mysql+pymysql://chatuser:chatpassword@localhost/chat_app
SECRET_KEY=your-super-secret-key-here-change-this
ACCESS_TOKEN_EXPIRE_MINUTES=30
```

6. **Run the backend server:**
```bash
python main.py
```
Backend will be available at: `http://localhost:8000`

#### Frontend Setup

1. **Navigate to frontend directory:**
```bash
cd frontend
```

2. **Install dependencies:**
```bash
npm install
```

3. **Start the development server:**
```bash
npm start
```
Frontend will be available at: `http://localhost:3000`

### Method 2: Docker Deployment

1. **Using Docker Compose (Recommended):**
```bash
docker-compose up --build
```
This will start both the backend (port 8000) and database services.

2. **Individual Docker containers:**
```bash
# Build the application
docker build -t chat-app .

# Run the container
docker run -p 8000:8000 chat-app
```

## 🔧 Configuration

### Environment Variables

Create a `.env` file in the root directory:

```env
# Database Configuration
DATABASE_URL=mysql+pymysql://username:password@localhost:3306/chat_app

# Security Configuration
SECRET_KEY=your-very-long-secret-key-here-minimum-32-characters
ACCESS_TOKEN_EXPIRE_MINUTES=30

# Optional: Database connection pool settings
DB_POOL_SIZE=10
DB_MAX_OVERFLOW=20
```

### Database Migration

The application automatically creates database tables on first run. For manual migration:

```bash
# In Python shell
from database import engine, Base
from models import user, room, message

Base.metadata.create_all(bind=engine)
```

## 🎮 Usage Guide

### 1. User Registration
- Visit `http://localhost:3000`
- Click "Register here" if you don't have an account
- Fill in username, email, and password
- You'll be automatically logged in after registration

### 2. Creating Chat Rooms
- Once logged in, you'll see the chat interface
- Enter a room name in the "New room name" field
- Click "Create Room" to create a new chat room
- Your newly created room will appear in the rooms list

### 3. Joining Rooms
- Click on any room name in the left sidebar
- The chat area will load messages from that room
- You can now send and receive messages in real-time

### 4. Sending Messages
- Select a room from the sidebar
- Type your message in the input field at the bottom
- Press Enter or click "Send" to send the message
- Messages appear instantly for all room members

### 5. Online Users
- The right sidebar shows currently online users
- Green dots indicate online status
- Your own status is shown at the bottom of the list

## 🔐 API Documentation

The FastAPI backend provides interactive API documentation:

- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`

### Key API Endpoints

#### Authentication
- `POST /register` - User registration
- `POST /login` - User login
- `GET /users/me` - Get current user info

#### Rooms
- `POST /rooms` - Create new room
- `GET /rooms` - Get user's rooms
- `POST /rooms/{room_id}/invite` - Invite user to room

#### Messages
- `POST /messages` - Send message
- `GET /messages/room/{room_id}` - Get room messages

#### WebSocket
- `WS /ws/{user_id}` - Real-time messaging connection

## 🛠️ Development

### Backend Development

```bash
# Run with auto-reload for development
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Run tests (if implemented)
python -m pytest

# Check code quality
flake8 .
black .
```

### Frontend Development

```bash
# Development server with hot reload
npm start

# Build for production
npm run build

# Run tests
npm test

# Eject from create-react-app (if needed)
npm run eject
```

### Database Management

```bash
# Connect to MySQL
mysql -u chatuser -p chat_app

# Backup database
mysqldump -u chatuser -p chat_app > backup.sql

# Restore database
mysql -u chatuser -p chat_app < backup.sql
```

## 🐳 Deployment

### Production Docker Setup

1. **Create production environment file:**
```env
# .env.production
DATABASE_URL=mysql+pymysql://prod_user:prod_pass@db:3306/chat_app_prod
SECRET_KEY=your-production-secret-key-here
ACCESS_TOKEN_EXPIRE_MINUTES=30
```

2. **Build and deploy:**
```bash
docker-compose -f docker-compose.yml up -d
```

### Traditional Deployment

1. **Backend deployment:**
```bash
# Install dependencies
pip install -r requirements.txt

# Run with Gunicorn (production WSGI server)
gunicorn main:app --workers 4 --worker-class uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

2. **Frontend deployment:**
```bash
# Build production version
cd frontend
npm run build

# Serve built files with nginx or similar
```

## 🔒 Security Considerations

### Production Checklist
- [ ] Change default `SECRET_KEY` to a strong, random value
- [ ] Use HTTPS in production
- [ ] Configure proper CORS origins
- [ ] Set up database backups
- [ ] Implement rate limiting
- [ ] Use environment variables for sensitive data
- [ ] Regular security updates for dependencies

### Additional Security Measures
```python
# In main.py, consider adding:
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development Guidelines
- Follow PEP 8 for Python code
- Use TypeScript with strict mode
- Write meaningful commit messages
- Add tests for new features
- Update documentation when needed

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Troubleshooting

### Common Issues

**Database Connection Failed:**
- Check MySQL service is running
- Verify database credentials in `.env`
- Ensure database exists and user has proper permissions

**WebSocket Connection Issues:**
- Check if backend server is running
- Verify CORS configuration
- Check browser console for specific errors

**Frontend Not Loading:**
- Ensure Node.js version is 16+
- Clear npm cache: `npm cache clean --force`
- Reinstall dependencies: `rm -rf node_modules && npm install`

**Authentication Errors:**
- Verify `SECRET_KEY` is set properly
- Check JWT token expiration settings
- Ensure time synchronization between client and server

### Getting Help

- Check the [Architecture Documentation](arch.md) for detailed system information
- Review the API documentation at `http://localhost:8000/docs`
- Open an issue on the GitHub repository

## 🙏 Acknowledgments

- [FastAPI](https://fastapi.tiangolo.com/) for the excellent backend framework
- [React](https://reactjs.org/) for the frontend library
- [SQLAlchemy](https://www.sqlalchemy.org/) for database ORM
- All the open-source contributors who made this project possible

---

<p align="center">
  Made with ❤️ using FastAPI and React
</p>