# Bookstore Application

A complete bookstore management system with a Django REST API backend and Flutter mobile frontend.

## Project Structure

```
Bookstore-project/
├── Back-end/                    # Django REST API
│   └── Bookstore Application/
│       └── bookstore/          # Django project
├── Front-end/                  # Flutter Mobile App
│   └── Bookstore Application/
│       └── bookstore/          # Flutter project
└── README.md
```

## Features

### Frontend (Flutter)
- 🎨 Beautiful UI with custom color scheme
- 📱 3-screen onboarding flow for first-time users
- 🔐 Complete authentication system (login/register)
- 🏠 Home screen with book browsing
- 🔍 Search and filter books by category
- 📚 Book details with purchase/borrow options
- 💾 Persistent login state using SharedPreferences
- 🌐 Full backend integration via REST API

### Backend (Django)
- 👤 User management with roles (Customer, Library Admin, Delivery Admin)
- 📖 Complete book management system
- 🏷️ Categories and authors
- ⭐ Book ratings and evaluations
- ❤️ Favorites system
- 🚚 Delivery management
- 💳 Payment processing
- 🛒 Shopping cart functionality

## Setup Instructions

### Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd "Back-end/Bookstore Application/bookstore"
   ```

2. Create and activate virtual environment:
   ```bash
   python -m venv v1
   # On Windows:
   v1\Scripts\activate
   # On Linux/Mac:
   source v1/bin/activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Run migrations:
   ```bash
   python manage.py migrate
   ```

5. Create superuser (optional):
   ```bash
   python manage.py createsuperuser
   ```

6. Start the server:
   ```bash
   python manage.py runserver
   ```
   
   **For mobile device access (phone/tablet on same Wi-Fi):**
   ```bash
   python manage.py runserver 0.0.0.0:8000
   ```
   This makes the server accessible from other devices on your network at `http://YOUR_IP:8000/`

The API will be available at:
- `http://127.0.0.1:8000/` (localhost only)
- `http://0.0.0.0:8000/` (network accessible, when using `0.0.0.0:8000`)

### Frontend Setup

1. Navigate to the frontend directory:
   ```bash
   cd "Front-end/Bookstore Application/bookstore"
   ```

2. Get Flutter dependencies:
   ```bash
   flutter pub get
   ```

3. Generate JSON serialization code:
   ```bash
   flutter packages pub run build_runner build
   ```

4. Run the app:
   ```bash
   flutter run
   ```

## App Flow

### First Time Users
1. **Splash Screen** - App loading screen
2. **Onboarding** - 3 welcome screens introducing the app
3. **Auth Selection** - Choose between Sign In or Create Account
4. **Authentication** - Login or register
5. **Home Screen** - Browse books

### Returning Users
1. **Splash Screen** - App loading screen
2. **Auto-login** - If previously logged in, goes directly to Home
3. **Auth Selection** - If not logged in, goes to authentication

## API Endpoints

### Authentication
- `POST /api/users/register/` - User registration
- `POST /api/users/login/` - User login
- `GET /api/users/profile/` - Get user profile

### Books
- `GET /api/library/books/` - List all books
- `GET /api/library/books/{id}/` - Get book details
- `GET /api/library/books/new/` - Get new books
- `GET /api/library/books/category/{id}/` - Get books by category

### Categories & Authors
- `GET /api/library/categories/` - List categories
- `GET /api/library/authors/` - List authors

## Configuration

### Backend Configuration
- Update `ALLOWED_HOSTS` in `settings.py` for production
- Configure database settings in `settings.py`
- Set up media files serving for production

### Frontend Configuration
- Update API base URL in `lib/services/api_service.dart`:
  ```dart
  static const String baseUrl = 'http://127.0.0.1:8000/api';
  ```

## Color Scheme

The app uses a beautiful color palette:
- **Thistle**: `#CDB4DB`
- **Fairy Tale**: `#FFC8DD`
- **Carnation Pink**: `#FFAFCC`
- **Uranian Blue**: `#BDE0FE`
- **Light Sky Blue**: `#A2D2FF`

## Testing

Run Flutter tests:
```bash
flutter test
```

## Technologies Used

### Backend
- Django 4.x
- Django REST Framework
- SQLite (default) / PostgreSQL (production)
- Python 3.x

### Frontend
- Flutter 3.x
- Dart 3.x
- Provider (State Management)
- SharedPreferences (Local Storage)
- HTTP (API Communication)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is for educational purposes. Please ensure you have the rights to use any images or content in production.
