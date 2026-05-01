# Firebase Setup Guide for Niyyah Tracker

## Prerequisites
- Google Account
- Firebase Project (free tier is sufficient)
- FlutterFire CLI installed (`dart pub global activate flutterfire_cli`)

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter project name: `niyyah-tracker` (or your preferred name)
4. Accept the default settings
5. Click "Create project"
6. Wait for the project to be created

## Step 2: Set Up Firestore Database

1. In Firebase Console, go to **Firestore Database**
2. Click **Create database**
3. Select region (choose closest to your users, e.g., `us-central1`)
4. Choose **Start in test mode** (for development)
   - ⚠️ For production, use secure rules (see Step 6)
5. Click **Create**

## Step 3: Enable Firebase Authentication

1. Go to **Authentication**
2. Click **Get started**
3. Enable these sign-in methods:
   - **Email/Password** (required)
   - **Google** (optional, for convenience)
   - **Apple** (optional, for iOS)

## Step 4: Configure FlutterFire

1. Open terminal in project root:
   ```bash
   cd G:\project\niyyah_tracker_flutter
   ```

2. Run FlutterFire CLI:
   ```bash
   flutterfire configure
   ```

3. When prompted:
   - Select platforms: Android, iOS (or as needed)
   - Select your Firebase project
   - Follow the prompts to complete setup

4. This will automatically:
   - Create `firebase_options.dart` with your project credentials
   - Update `android/build.gradle`
   - Update `ios/Podfile`

## Step 5: Install Dependencies

```bash
flutter pub get
```

This installs all packages from `pubspec.yaml`, including:
- `firebase_core`
- `cloud_firestore`
- `firebase_auth`
- `provider` (state management)
- `hive` (local storage)
- And others

## Step 6: Set Up Firestore Security Rules

1. In Firebase Console, go to **Firestore Database** > **Rules**
2. Replace the default rules with:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Only authenticated users can access their own data
    match /users/{userId} {
      allow read: if request.auth.uid == userId;
      allow create: if request.auth.uid == userId;
      allow update, delete: if request.auth.uid == userId;

      // Allow access to all subcollections
      match /{document=**} {
        allow read: if request.auth.uid == userId;
        allow write: if request.auth.uid == userId;
      }
    }

    // Public collections (if needed in future)
    match /public/{document=**} {
      allow read: if true;
      allow write: if false;
    }
  }
}
```

3. Click **Publish**

## Step 7: Create Firestore Indexes (Optional but Recommended)

For better query performance, create these indexes in Firebase Console:

### Index 1: Daily Worship by Date
- Collection: `users/{userId}/daily_worship`
- Fields: `date (Ascending)`

### Index 2: Monthly Goals by Category
- Collection: `users/{userId}/monthly_goals`
- Fields: `category (Ascending)`, `startDate (Descending)`

### Index 3: Weekly Plans by Goal
- Collection: `users/{userId}/weekly_plans`
- Fields: `monthlyGoalId (Ascending)`, `weekStartDate (Descending)`

## Step 8: Verify Setup

Run the app and test:

```bash
flutter run
```

Check the console logs for:
- ✅ `Firebase initialized successfully`
- ✅ No Firebase authentication errors

## Step 9: Enable Firebase Storage (for future features)

When you need to upload images/audio:

1. Go to Firebase Console > **Storage**
2. Click **Get started**
3. Choose security rules (test mode for development)
4. Click **Done**

## Collection Structure

The app uses this Firestore structure:

```
users/
  {userId}/
    profile: { name, email, createdAt, preferences }
    daily_worship/
      {date-id}: { date, worships: {type: bool}, notes }
    monthly_goals/
      {goalId}: { goalTitle, targetValue, currentValue, category, dates }
    weekly_plans/
      {planId}: { weekStartDate, dailyPlans[], monthlyGoalId }
    ramadan/
      {ramadanId}: { currentDay, quranPagesCompleted, dayRecords[] }
    hajj/
      {hajjId}: { isInHajjMode, currentDayOfHajj, pillars[], supplications[] }
    reports/
      {reportId}: { month, worshipSummary, bestDays, pdf_url }
```

## Troubleshooting

### Issue: `firebase_core` package not found
**Solution:** Run `flutter pub get`

### Issue: Firebase options not loading
**Solution:** Ensure `firebase_options.dart` was created by FlutterFire CLI

### Issue: Authentication errors
**Solution:** Check that user is signed in before accessing Firestore

### Issue: Firestore rules rejections
**Solution:** Verify user ID matches the document path in security rules

## Environment Variables (Optional)

For extra security, store Firebase project ID in `.env`:

1. Create `.env` file in project root:
   ```
   FIREBASE_PROJECT_ID=your-project-id
   ```

2. Add to `.gitignore`:
   ```
   .env
   ```

3. Load in app:
   ```dart
   final projectId = env.get('FIREBASE_PROJECT_ID');
   ```

## Next Steps

1. ✅ Complete this setup
2. Update `firebase_options.dart` with your credentials
3. Test authentication flow
4. Create user profile functionality
5. Implement daily worship recording UI
6. Build monthly goals management
7. Add charts/dashboard features

## Resources

- [Firebase Console](https://console.firebase.google.com/)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firestore Documentation](https://firebase.google.com/docs/firestore)
- [Firebase Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
