# Android Phone Authentication Setup for Egypt

## Overview
This guide explains how to set up phone authentication for Egyptian phone numbers in your Flutter app's Android configuration.

## Prerequisites
- Firebase project with phone authentication enabled
- App SHA-1 fingerprint registered in Firebase Console
- Android build.gradle configured with Firebase

## Step 1: Find Your Application ID

Your application ID is found in `android/app/build.gradle`:

```gradle
android {
    ...
    defaultConfig {
        applicationId "com.example.niyyah_tracker"  // This is your applicationId
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

**Common application ID for Niyyah Tracker:**
```
com.niyyah.tracker
```

## Step 2: Register SHA-1 Fingerprint

Phone authentication requires your app's SHA-1 fingerprint for security. To get your debug SHA-1:

### On Windows:
```bash
# Navigate to your project
cd G:\project\niyyah_tracker_flutter

# Get debug keystore SHA-1
keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
```

### Output will look like:
```
SHA1: AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD
```

### For Release Build:
```bash
# Use your release keystore
keytool -list -v -keystore path/to/release.keystore -alias key_name
```

## Step 3: Register SHA-1 in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project → Project Settings
3. Scroll to "Your apps" section
4. Click on your Android app
5. Under "SHA certificate fingerprints", add:
   - **Debug SHA-1**: (from Step 2)
   - **Release SHA-1**: (for production)

Example:
```
AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD
```

## Step 4: Configure google-services.json

1. In Firebase Console, go to Project Settings
2. Download `google-services.json`
3. Place it in: `android/app/google-services.json`

The file should contain your:
- `project_id`
- `package_name` (matching applicationId)
- `api_key`
- `client` configurations

## Step 5: Android Build Configuration

Ensure `android/build.gradle` has Firebase plugin:

```gradle
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath 'com.google.gms:google-services:4.3.15'
    }
}
```

And `android/app/build.gradle` has:

```gradle
apply plugin: 'com.google.gms.google-services'

dependencies {
    // Firebase
    implementation 'com.google.firebase:firebase-auth'
    implementation 'com.google.firebase:firebase-core'
}
```

## Step 6: Enable Phone Authentication in Firebase

1. Go to Firebase Console → Authentication
2. Click "Get started"
3. Enable **Phone** sign-in method
4. Click Save

## Step 7: Android Manifest Permissions

Ensure `android/app/src/main/AndroidManifest.xml` has:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    
    <application>
        <!-- Your app configuration -->
    </application>
</manifest>
```

## Step 8: Test Phone Number

Firebase provides test phone numbers for development:

**For Egypt Development:**
```
Test Phone: +2015555555551
Test Code: 123456 (any 6 digits work)
```

Add in Firebase Console:
1. Go to Authentication → Phone
2. Scroll to "Phone numbers for testing"
3. Add:
   - Phone number: `+2015555555551`
   - Code: `123456`

## Step 9: Build and Test

```bash
cd G:\project\niyyah_tracker_flutter

# Get dependencies
flutter pub get

# Build APK for testing
flutter build apk

# Or run on device
flutter run
```

## Troubleshooting

### Issue: "Phone authentication is not enabled"
**Solution:** 
- Enable it in Firebase Console → Authentication → Phone
- Ensure SHA-1 fingerprint is registered

### Issue: "SMS code not received"
**Solution:**
- For development, use test phone numbers
- Ensure phone has working SMS service
- Check that rate limiting hasn't been triggered
- Use Firebase console to verify the credentials

### Issue: "Invalid SHA-1"
**Solution:**
- Regenerate using `keytool` command above
- Copy exact format with colons
- Ensure you're using the debug keystore for development

### Issue: "Package name mismatch"
**Solution:**
- Verify `applicationId` in `android/app/build.gradle`
- Must match `package_name` in `google-services.json`
- Don't confuse with `package` in `AndroidManifest.xml`

## Egypt-Specific Configuration

### Mobile Operators
Your app validates these Egyptian mobile operator codes:

| Code | Operator |
|------|----------|
| 10   | Vodafone |
| 11   | Etisalat |
| 12   | Vodafone |
| 15   | Etisalat |
| 16   | Orange   |
| 17   | We       |
| 18   | Orange   |

**Valid Egyptian phone formats:**
- `+201001234567` ✅
- `01001234567` ✅ (converts to +201001234567)
- `001201001234567` ✅
- `01234567890` ❌ (wrong operator code)
- `+201234567` ❌ (too short)

### Example Usage in Code

```dart
final service = PhoneAuthService();

// Validate Egyptian phone
bool isValid = PhoneAuthService.isValidEgyptianPhone('01001234567');

// Format to international
String formatted = PhoneAuthService.formatEgyptianPhone('01001234567');
// Result: +201001234567

// Send OTP
await service.sendOtpToEgyptianPhone(
  '+201001234567',
  verificationCompleted: (credential) { ... },
  verificationFailed: (error) { ... },
  codeSent: (verificationId, resendToken) { ... },
  codeAutoRetrievalTimeout: (verificationId) { ... },
);

// Verify OTP
await service.verifyOtpCode(verificationId, '123456');
```

## Environment Setup Checklist

- [ ] Application ID found in `android/app/build.gradle`
- [ ] Debug SHA-1 fingerprint generated
- [ ] SHA-1 registered in Firebase Console
- [ ] `google-services.json` downloaded and placed in `android/app/`
- [ ] Phone authentication enabled in Firebase
- [ ] Test phone number added in Firebase Console
- [ ] Android Manifest has internet permission
- [ ] Build.gradle files have Firebase dependencies
- [ ] Tested with development/test phone number
- [ ] Ready for production with release SHA-1

## Next Steps

1. Complete this setup
2. Test with provided test phone numbers
3. Update `PhoneAuthService` with any Egypt-specific requirements
4. Create UI tests for phone validation
5. Set up release build authentication

## Resources

- [Firebase Phone Auth Documentation](https://firebase.google.com/docs/auth/android/phone-auth)
- [Flutter Firebase Documentation](https://firebase.flutter.dev/)
- [Android Keytool Documentation](https://developer.android.com/studio/publish/app-signing)
- [Firebase Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
