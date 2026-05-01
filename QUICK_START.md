# Niyyah Tracker - Quick Start Guide

## 🚀 Getting Started

### Step 1: Install Dependencies
```bash
cd G:\project\niyyah_tracker_flutter
flutter pub get
```

### Step 2: Set Up Firebase

**Option A: Using FlutterFire CLI (Recommended)**
```bash
flutterfire configure
```

This will automatically:
- Create `google-services.json` (Android)
- Create `GoogleService-Info.plist` (iOS)
- Update build files

**Option B: Manual Setup**

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project called "niyyah-tracker"
3. Add Android app:
   - Package name: `com.example.niyyah_tracker` (or your app ID)
   - SHA-1 fingerprint: Get with:
     ```bash
     keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore ^
       -alias androiddebugkey -storepass android -keypass android
     ```
   - Download `google-services.json`
   - Place in: `android/app/google-services.json`

4. Enable Authentication:
   - Go to Authentication > Get started
   - Enable **Email/Password**
   - Enable **Phone**
   - Enable **Google** (optional)

5. Create Firestore Database:
   - Go to Firestore Database > Create database
   - Start in test mode (for development)
   - Choose region: `us-central1`

6. Update `lib/firebase_options.dart`:
   - Replace `YOUR_PROJECT_ID` with your project ID
   - Replace API keys from Firebase Console > Project Settings

### Step 3: Verify Setup

Check for any errors:
```bash
flutter analyze
```

### Step 4: Run the App

```bash
# Debug mode
flutter run

# Release mode
flutter run --release
```

## 📱 Features Available

### ✅ Implemented
- Dashboard with daily worship tracking
- UI components and theming
- Firebase/Firestore integration
- Local storage (Hive)
- Phone authentication (Egypt)
- Database models and services

### 🚧 To Be Implemented
- Daily worship recording UI
- Monthly goal management
- Weekly plan generation
- ECharts dashboard
- PDF report generation
- Ramadan special mode
- Hajj mode
- Smart notifications
- User profile management

## 📁 Project Structure

```
lib/
├── main.dart                           # App entry point
├── firebase_options.dart               # Firebase config
├── core/
│   └── app_colors.dart                # Color theme
├── features/
│   ├── auth/
│   │   ├── login_page.dart
│   │   ├── register_page.dart
│   │   └── phone_login_page.dart      # NEW: Egypt phone auth
│   ├── dashboard/
│   │   └── dashboard_page.dart
│   ├── onboarding/
│   │   └── onboarding_page.dart
│   └── splash/
│       └── splash_page.dart
├── models/
│   ├── worship_model.dart             # NEW
│   ├── monthly_goal_model.dart        # NEW
│   ├── weekly_plan_model.dart         # NEW
│   ├── ramadan_model.dart             # NEW
│   └── hajj_model.dart                # NEW
├── services/
│   ├── firebase_service.dart          # NEW: Firestore CRUD
│   ├── local_storage_service.dart     # NEW: Hive caching
│   ├── phone_auth_service.dart        # NEW: Egypt phone auth
│   └── firebase_initialization_service.dart # NEW
├── providers/
│   └── phone_auth_provider.dart       # NEW: State management
└── config/
    └── database_config.dart           # NEW: DB structure docs
```

## 🔐 Firebase Security Rules

Apply in Firebase Console > Firestore > Rules:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
      match /{document=**} {
        allow read, write: if request.auth.uid == userId;
      }
    }
  }
}
```

## 🧪 Testing

### Test Phone Numbers (Development)
```
Phone: +2015555555551
Code: 123456 (any 6 digits)
```

Add in Firebase Console:
1. Authentication > Phone > Phone numbers for testing
2. Add the test number and code

### Test Egyptian Phone Numbers
Valid formats:
- `+201001234567` ✅ Vodafone
- `+201101234567` ✅ Etisalat
- `+201601234567` ✅ Orange
- `+201701234567` ✅ We

## 🐛 Troubleshooting

### Error: "Firebase initialization error"
**Solution:** Run `flutterfire configure` to generate `firebase_options.dart`

### Error: "MyApp isn't a class"
**Solution:** App uses `NiyyahTrackerApp`, not `MyApp`. This is already fixed in main.dart

### Error: "Phone authentication is not enabled"
**Solution:** Enable Phone auth in Firebase Console > Authentication

### Error: "Cannot find google-services.json"
**Solution:** 
- Run `flutterfire configure`
- Or manually download from Firebase Console > Project Settings > Your apps > Android

### Error: "SHA-1 not registered"
**Solution:** Get SHA-1 with keytool command above and register in Firebase Console

## 📚 Documentation Files

- `FIREBASE_SETUP.md` - Complete Firebase setup
- `ANDROID_PHONE_AUTH_SETUP.md` - Android phone auth configuration
- `lib/config/database_config.dart` - Firestore collection structure
- `lib/services/firebase_service.dart` - Firestore operations

## 🔗 Useful Links

- [Firebase Flutter Docs](https://firebase.flutter.dev/)
- [Flutter Documentation](https://flutter.dev/docs)
- [Firestore Documentation](https://firebase.google.com/docs/firestore)
- [Phone Authentication](https://firebase.google.com/docs/auth/flutter/phone-auth)

## 📝 Next Steps

1. ✅ Install dependencies with `flutter pub get`
2. ✅ Configure Firebase (run `flutterfire configure`)
3. ✅ Test with sample phone number
4. ⬜ Implement daily worship recording UI
5. ⬜ Add monthly goal management
6. ⬜ Create dashboard with charts
7. ⬜ Implement PDF report generation
8. ⬜ Add notification system

## 💡 Tips

- Use `flutter run -v` for verbose output and debugging
- Check Firebase Console logs for any errors
- Use test phone numbers during development
- Keep `google-services.json` out of version control (it's in .gitignore)

## Need Help?

Check the documentation files:
- Common Firebase issues: `FIREBASE_SETUP.md`
- Android-specific issues: `ANDROID_PHONE_AUTH_SETUP.md`
- Database structure: `lib/config/database_config.dart`

---

**Last Updated:** May 1, 2026
**Status:** Ready for development
