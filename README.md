# 🏥 HealthCare - Patient Care Task Management System

A comprehensive healthcare management platform developed for task tracking, communication, and problem reporting between patient relatives and caregivers.

## 📋 Features

### 👥 User Roles
- **Patient Relative**: Assigns tasks, monitors progress, views problems
- **Caregiver**: Completes tasks, reports problems, uploads photos

### ✨ Main Features
- 📅 **Task Management**: Create task templates, assign and track tasks
- 🔔 **Notifications**: Automatic notification system
- 💬 **Live Chat**: User-to-user messaging (with emoji and file attachment support)
- 📸 **Photo Documentation**: Upload task completion photos
- ⭐ **Rating System**: Rate completed tasks with 1-5 stars
- 💊 **Medication Tracking**: Special medication task type (visually differentiated)
- 🚨 **Problem Management**: 3-level (mild/moderate/critical) problem reporting
- 📊 **Statistics**: Task completion rates and performance charts
- 🏥 **Critical Issue Reporting**: Automatic ministry notification for critical problems

## 🛠️ Technology Stack

### Backend
- **Framework**: FastAPI 0.115.6
- **Database**: SQLite (SQLAlchemy ORM 2.0.36)
- **Validation**: Pydantic 2.10.5
- **Server**: Uvicorn 0.34.0
- **File Processing**: python-multipart, aiofiles

### Frontend
- **Framework**: Flutter 3.9.2+
- **State Management**: flutter_riverpod 2.6.1
- **HTTP Client**: http 1.6.0
- **UI Components**:
  - table_calendar 3.1.3 (Calendar view)
  - image_picker 1.2.1 (Photo selection)
  - emoji_picker_flutter 3.1.0 (Emoji picker)
  - cached_network_image 3.4.1 (Image caching)
  - shared_preferences 2.3.3 (Local data storage)

## 📁 Project Structure

```
HealthCare/
├── backend/
│   ├── venv/                    # Python virtual environment
│   │   └── app/
│   │       ├── main.py          # FastAPI main application
│   │       ├── database.py      # Database connection
│   │       ├── models.py        # SQLAlchemy models
│   │       ├── schemas.py       # Pydantic schemas
│   │       ├── crud.py          # Database operations
│   │       └── routers/         # API endpoints
│   │           ├── auth.py      # Authentication
│   │           ├── tasks.py     # Task management
│   │           ├── messages.py  # Messaging
│   │           ├── notifications.py
│   │           ├── statistics.py
│   │           └── uploads.py   # Photo upload
│   ├── uploads/                 # Uploaded task photos
│   ├── healthcare.db            # SQLite database
│   └── requirements.txt
│
└── frontend/
    └── healthcare_app/
        ├── lib/
        │   ├── main.dart        # Application entry point
        │   ├── core/
        │   │   ├── api_client.dart  # API HTTP client
        │   │   └── models.dart      # Dart data models
        │   └── pages/           # UI pages
        │       ├── login_page.dart
        │       ├── caregiver_home_page.dart
        │       ├── caregiver_tasks_page.dart
        │       ├── relative_home_page.dart
        │       ├── relative_tasks_page.dart
        │       ├── chat_page.dart
        │       ├── conversations_list_page.dart
        │       └── notifications_page.dart
        ├── pubspec.yaml         # Flutter dependencies
        └── analysis_options.yaml
```

## 🚀 Installation and Setup

### Requirements
- Python 3.8+
- Flutter 3.9.2+
- Dart SDK 3.9.2+

### Backend Setup

1. Navigate to the backend directory:
```bash
cd backend
```

2. Create and activate Python virtual environment:
```bash
python -m venv venv
.\venv\Scripts\Activate.ps1  # Windows PowerShell
# or
source venv/bin/activate  # Linux/Mac
```

3. Install required packages:
```bash
pip install -r requirements.txt
```

4. Ensure the database file is in the correct location:
- The `healthcare.db` file should be in the `backend/` directory
- It will be automatically created on first run

5. Start the backend server:
```bash
cd venv
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Backend is now running at http://127.0.0.1:8000
- API Documentation: http://127.0.0.1:8000/docs (Swagger UI)

### Frontend Setup

1. Navigate to the frontend directory:
```bash
cd frontend/healthcare_app
```

2. Install Flutter dependencies:
```bash
flutter pub get
```

3. Run the application:

**For Chrome (Web):**
```bash
flutter run -d chrome
```

**For Android:**
```bash
flutter run -d <device_id>
```

**For iOS (Mac required):**
```bash
flutter run -d <device_id>
```

### Test Users

Login credentials for testing:

**Patient Relative:**
- Email: `relative@example.com`
- Password: Anything

**Caregiver:**
- Email: `caregiver@example.com`
- Password: Anything

> Note: Currently using simple email validation. Secure authentication implementation required for production.

## 🎯 Usage Scenarios

### 1. Task Creation and Assignment (Patient Relative)
1. Log in
2. Click "Add Task" button
3. Enter task details (title, description, time, days)
4. For medication tasks, check "Medication Task" option
5. Save

### 2. Task Completion (Caregiver)
1. View assigned tasks
2. Click "Start" button
3. After completing the task, press "Complete" button
4. Optionally upload a photo or complete without photo

### 3. Problem Reporting (Caregiver)
1. Click "Report Problem" button in task details
2. Write problem description
3. Select severity level (mild/moderate/critical)
4. Submit
- **Critical problems** automatically send notification to patient relative and display "Reported to ministry" message

### 4. Task Rating (Patient Relative)
1. View completed tasks
2. Click "Rate" button
3. Give 1-5 stars
4. Optionally add a comment

## 📊 Database Schema

### Main Tables
- **users**: User information (patient_relative, caregiver)
- **task_template**: Task templates (for recurring tasks)
- **task_instance**: Task instances (tasks assigned for specific dates)
- **notifications**: Notifications
- **messages**: Messages (one-to-one chat)
- **conversation**: Conversation metadata

### Important Columns
- `task_type`: 'normal' or 'medication'
- `completion_photo_url`: Completion photo file path
- `rating`: Task rating (1-5)
- `review_note`: Rating comment
- `critical_notified`: Was critical problem notification sent?
- `severity`: Problem severity (mild/moderate/critical)

## 🔒 Security Notes

**⚠️ Important**: This project is in development stage. For production use:
- Add JWT token-based authentication
- Hash passwords (bcrypt, argon2)
- Restrict CORS settings to specific domains
- Add rate limiting
- Strengthen input validation
- Use HTTPS
- Update SQL injection protection (continue using SQLAlchemy ORM)

