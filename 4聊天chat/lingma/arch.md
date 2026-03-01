# Chat Application Architecture Documentation

## Project Overview
This is a full-stack chat application with real-time messaging capabilities, built using FastAPI for the backend and React/TypeScript for the frontend.

## Backend Architecture (Python/FastAPI)

### Core Application Files

#### `main.py` - Application Entry Point
- **Purpose**: Main FastAPI application configuration and route definitions
- **Key Features**:
  - User registration and authentication endpoints
  - Chat room management APIs
  - Message sending/receiving endpoints
  - WebSocket connection handling
  - CORS middleware configuration
- **Dependencies**: All service modules, models, and schemas

#### `database.py` - Database Configuration
- **Purpose**: Database connection and session management
- **Key Features**:
  - SQLAlchemy engine configuration
  - Database session factory
  - Environment variable loading
  - MySQL connection setup
- **Dependencies**: `sqlalchemy`, `pymysql`, `python-dotenv`

### Models Layer

#### `models/user.py` - User Data Model
- **Purpose**: Define user entity structure and relationships
- **Fields**: id, username, email, hashed_password, is_active, is_online, timestamps
- **Relationships**: created_rooms, rooms (many-to-many), sent_messages
- **Dependencies**: SQLAlchemy Base class

#### `models/room.py` - Chat Room Model
- **Purpose**: Define chat room structure and member relationships
- **Fields**: id, name, creator_id, timestamps
- **Relationships**: creator (User), members (many-to-many User), messages
- **Dependencies**: room_members association table

#### `models/message.py` - Message Model
- **Purpose**: Define message structure and relationships
- **Fields**: id, sender_id, room_id, content, created_at
- **Relationships**: sender (User), room (Room)
- **Dependencies**: SQLAlchemy relationships

### Schema Layer (Pydantic Validation)

#### `schemas/user.py` - User Data Schemas
- **Purpose**: Request/response validation for user operations
- **Classes**: UserBase, UserCreate, UserLogin, UserResponse, Token, TokenData
- **Features**: Email validation, password handling, JWT token structures

#### `schemas/room.py` - Room Data Schemas
- **Purpose**: Validation for room-related operations
- **Classes**: RoomBase, RoomCreate, RoomResponse, RoomInvite
- **Features**: Room creation validation, member list handling

#### `schemas/message.py` - Message Data Schemas
- **Purpose**: Message request/response validation
- **Classes**: MessageBase, MessageCreate, MessageResponse
- **Features**: Content validation, sender information

### Service Layer

#### `services/auth_service.py` - Authentication Service
- **Purpose**: Handle user authentication and JWT token management
- **Key Functions**:
  - Password hashing and verification
  - JWT token creation and validation
  - Current user retrieval with dependency injection
  - OAuth2 password bearer authentication
- **Dependencies**: `passlib`, `python-jose`, FastAPI security

#### `services/chat_service.py` - Chat Business Logic
- **Purpose**: Core chat application business logic
- **Key Functions**:
  - Room creation and management
  - User invitation to rooms
  - Message sending and retrieval
  - Online user tracking
- **Dependencies**: Database models, SQLAlchemy sessions

#### `services/ws_service.py` - WebSocket Service
- **Purpose**: Manage real-time WebSocket connections
- **Key Features**:
  - ConnectionManager class for tracking active connections
  - Message broadcasting to rooms
  - User status notifications
  - Connection lifecycle management
- **Dependencies**: FastAPI WebSocket, JSON serialization

## Frontend Architecture (React/TypeScript)

### Core Configuration

#### `frontend/package.json` - Project Dependencies
- **Purpose**: Define frontend project dependencies and scripts
- **Key Dependencies**: React, TypeScript, react-scripts
- **Scripts**: start, build, test, eject

#### `frontend/public/index.html` - HTML Template
- **Purpose**: Main HTML entry point for React application
- **Features**: Root div mounting point, viewport configuration

### Source Components

#### `frontend/src/App.tsx` - Main Application Component
- **Purpose**: Root component managing authentication state
- **Key Features**:
  - Authentication flow management
  - Route switching between login/register/chat
  - Local storage integration
  - User session persistence
- **Dependencies**: Login, Register, ChatRoom components

#### `frontend/src/Login.tsx` - User Login Component
- **Purpose**: Handle user authentication
- **Key Features**:
  - Login form with validation
  - API integration for authentication
  - Token storage in local storage
  - Error handling and display
- **Dependencies**: Fetch API, React hooks

#### `frontend/src/Register.tsx` - User Registration Component
- **Purpose**: Handle new user registration
- **Key Features**:
  - Registration form with validation
  - Password confirmation matching
  - Automatic login after registration
  - Form validation and error handling
- **Dependencies**: Fetch API, React hooks

#### `frontend/src/ChatRoom.tsx` - Main Chat Interface
- **Purpose**: Primary chat application interface
- **Key Features**:
  - Room selection and creation
  - Real-time message display
  - WebSocket integration
  - Online users sidebar
  - Message sending functionality
- **Dependencies**: WebSocket API, Fetch API, React hooks

#### `frontend/src/UserList.tsx` - Online Users Display
- **Purpose**: Show currently online users
- **Key Features**:
  - User status indicators
  - Current user highlighting
  - Online status filtering
- **Dependencies**: React props interface

#### `frontend/src/App.css` - Application Styling
- **Purpose**: Global and component-specific styling
- **Features**:
  - Responsive design
  - Chat interface layout
  - Form styling
  - Mobile optimization
  - Color scheme and typography

## Infrastructure

#### `Dockerfile` - Container Configuration
- **Purpose**: Define application containerization
- **Features**:
  - Python 3.9 base image
  - Dependency installation
  - Application copying
  - Uvicorn server configuration

#### `docker-compose.yml` - Service Orchestration
- **Purpose**: Multi-container application deployment
- **Services**: 
  - MySQL database service
  - FastAPI application service
- **Features**: Volume persistence, environment configuration

#### `requirements.txt` - Python Dependencies
- **Purpose**: Backend dependency management
- **Key Packages**: FastAPI, SQLAlchemy, Pydantic, JWT, WebSocket support

#### `.env.example` - Environment Configuration Template
- **Purpose**: Template for environment variables
- **Variables**: Database URL, secret key, JWT configuration

## Data Flow Architecture

### Authentication Flow
1. User submits login/register form
2. Frontend sends request to backend API
3. Backend validates credentials/user data
4. JWT token generated and returned
5. Token stored in localStorage
6. Protected routes require valid token

### Message Flow
1. User sends message through WebSocket
2. Backend validates user permissions
3. Message stored in database
4. Message broadcast to room members
5. Frontend receives and displays message

### Real-time Updates
1. WebSocket connections established on login
2. Server broadcasts user status changes
3. Client updates online users list
4. Message notifications sent in real-time

## Security Considerations

### Backend Security
- JWT token-based authentication
- Password hashing with bcrypt
- Input validation with Pydantic
- SQL injection prevention with SQLAlchemy ORM
- CORS policy configuration

### Frontend Security
- Token-based API authentication
- Form validation and sanitization
- Secure local storage usage
- HTTPS-ready configuration

## Deployment Architecture

### Development Mode
- Backend: `uvicorn main:app --reload`
- Frontend: `npm start`
- Separate development servers

### Production Mode
- Docker containerization
- nginx reverse proxy (recommended)
- SSL termination
- Static file serving for frontend build

This architecture provides a scalable, secure, and maintainable chat application with real-time capabilities.