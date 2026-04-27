# Finlit Mobile App

A Flutter mobile application for financial literacy and transaction management.

## Prerequisites

1. Install Flutter SDK: https://flutter.dev/docs/get-started/install
2. Install Android Studio (for Android) or Xcode (for iOS)
3. Make sure the backend server is running at `http://127.0.0.1:5000`

## Setup

1. Install dependencies:
```bash
flutter pub get
```

2. Configure backend URL in `.env`:
   - For Android Emulator: `BACKEND_URL=http://10.0.2.2:5000`
   - For Physical Device (same WiFi): `BACKEND_URL=http://YOUR_PC_IP:5000` (e.g., `http://192.168.0.107:5000`)
   - For iOS Simulator: `BACKEND_URL=http://127.0.0.1:5000`

## Running the App

### Android Emulator
```bash
flutter run
```

### Physical Device
1. Enable Developer Options and USB Debugging on your device
2. Connect device via USB
3. Run: `flutter run`

### Build APK (Android)
```bash
flutter build apk
```
The APK will be in `build/app/outputs/flutter-apk/app-release.apk`

## Features

- User registration and login with JWT authentication
- Secure token storage using Flutter Secure Storage
- View transaction history
- Add new transactions
- Protected API calls to backend
- Session restoration on app restart

## Backend Integration

The app connects to the Flask backend at the URL specified in `.env` and uses:
- `/api/auth/register` - User registration
- `/api/auth/login` - User login
- `/api/transactions/` (GET) - Fetch user transactions
- `/api/transactions/` (POST) - Create new transaction

All transaction endpoints require Bearer token authentication.
