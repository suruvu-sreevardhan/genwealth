# Setup Instructions for Finlit Flutter App

## Important: Flutter Installation Required

This project requires Flutter to be installed. If you don't have Flutter installed yet:

1. **Install Flutter SDK**
   - Windows: https://docs.flutter.dev/get-started/install/windows
   - Download Flutter SDK
   - Extract to a location (e.g., `C:\src\flutter`)
   - Add Flutter to PATH: `C:\src\flutter\bin`
   
2. **Verify Installation**
   ```bash
   flutter doctor
   ```
   This will check for any missing dependencies.

3. **Install Android Studio** (for Android development)
   - Download from: https://developer.android.com/studio
   - Install Android SDK
   - Set up an Android Emulator (AVD)

## Once Flutter is Installed

### Step 1: Navigate to project directory
```bash
cd "c:\Users\sreev\Downloads\Finance Manager\fin_mobile"
```

### Step 2: Install dependencies
```bash
flutter pub get
```

### Step 3: Configure Backend URL
Edit `.env` file:
- **For Android Emulator**: Already set to `http://10.0.2.2:5000`
- **For Physical Android Device**: Change to `http://YOUR_PC_IP:5000`
  - Find your PC IP: Run `ipconfig` in PowerShell and look for IPv4 Address
  - Example: `BACKEND_URL=http://192.168.0.107:5000`

### Step 4: Start the Backend Server
In a separate terminal:
```bash
cd "c:\Users\sreev\Downloads\Finance Manager\fin_backend"
.\venv\Scripts\Activate.ps1
python app.py
```

Backend should be running on `http://127.0.0.1:5000`

### Step 5: Run the Flutter App

**Option A: Using Android Emulator**
1. Open Android Studio
2. Start an AVD (Android Virtual Device)
3. Run:
```bash
flutter run
```

**Option B: Using Physical Android Device**
1. Enable Developer Mode on your Android phone:
   - Go to Settings > About Phone
   - Tap "Build Number" 7 times
2. Enable USB Debugging:
   - Go to Settings > Developer Options
   - Enable "USB Debugging"
3. Connect phone via USB
4. Run:
```bash
flutter devices  # Verify device is detected
flutter run
```

### Step 6: Test the App

1. **Register a new user**
   - Tap "Create new account"
   - Enter email and password
   - Should navigate to Home screen

2. **Add a transaction**
   - Tap the "+" button
   - Enter merchant name and amount
   - Tap "Save"
   - Should return to home with new transaction listed

3. **View transactions**
   - Should see list of all your transactions
   - Tap refresh icon to reload

4. **Logout and Login**
   - Tap logout icon
   - Login again with same credentials
   - Transactions should persist

## Troubleshooting

### "Unable to connect to backend"
- Make sure backend is running
- Check `.env` has correct URL
- For physical device, ensure phone and PC are on same WiFi

### "Flutter command not found"
- Flutter not in PATH
- Restart terminal after adding Flutter to PATH
- Run `flutter doctor` to verify installation

### "No devices available"
- For emulator: Start AVD in Android Studio
- For physical device: Enable USB debugging and authorize computer

### Build errors
```bash
flutter clean
flutter pub get
flutter run
```

## Building APK

To build a release APK:
```bash
flutter build apk --release
```

APK location: `build/app/outputs/flutter-apk/app-release.apk`

You can install this APK on any Android device.

## Project Structure

```
fin_mobile/
├── .env                          # Backend URL configuration
├── pubspec.yaml                  # Dependencies
├── lib/
│   ├── main.dart                # App entry point
│   ├── services/
│   │   └── api_service.dart     # HTTP client & JWT storage
│   ├── providers/
│   │   └── auth_provider.dart   # Authentication state management
│   └── screens/
│       ├── login_screen.dart    # Login/Register UI
│       ├── home_screen.dart     # Transaction list
│       └── add_transaction_screen.dart  # Add new transaction
```

## Next Steps

After successfully running the app, you're ready for Prompt 5 which will add:
- AI-powered transaction categorization
- Financial health score calculation
- Personalized financial advice
