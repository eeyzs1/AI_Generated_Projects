#!/usr/bin/env python3
"""
Startup script for the Chat Application
This script provides guidance on how to set up and run the application.
"""

def print_setup_instructions():
    print("=" * 50)
    print("CHAT APPLICATION SETUP INSTRUCTIONS")
    print("=" * 50)
    print("\n1. Backend Setup:")
    print("   - Install Python dependencies:")
    print("     pip install -r requirements.txt")
    print("\n   - Set up MySQL database:")
    print("     CREATE DATABASE chat_app;")
    print("\n   - Create .env file with database configuration:")
    print("     DATABASE_URL=mysql+pymysql://username:password@localhost/chat_app")
    print("     SECRET_KEY=your-secret-key-here")
    print("\n   - Run the backend:")
    print("     python main.py")
    print("\n2. Frontend Setup:")
    print("   - Navigate to frontend directory:")
    print("     cd frontend")
    print("\n   - Install npm dependencies:")
    print("     npm install")
    print("\n   - Start the frontend:")
    print("     npm start")
    print("\n3. Access the application:")
    print("   - Backend API: http://localhost:8000")
    print("   - Frontend: http://localhost:3000")
    print("   - API Documentation: http://localhost:8000/docs")
    print("\n" + "=" * 50)

if __name__ == "__main__":
    print_setup_instructions()