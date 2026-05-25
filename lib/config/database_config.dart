/// Database Configuration for Niyyah Tracker
///
/// Firestore Collection Structure:
///
/// users/
///   ├── {userId}/
///   │   ├── profile (user document)
///   │   ├── daily_worship/ (subcollection)
///   │   │   └── {worshipId}: DailyWorship
///   │   ├── monthly_goals/ (subcollection)
///   │   │   └── {goalId}: MonthlyGoal
///   │   ├── weekly_plans/ (subcollection)
///   │   │   └── {planId}: WeeklyPlan
///   │   ├── ramadan/ (subcollection)
///   │   │   └── {ramadanId}: RamadanTracking
///   │   ├── hajj/ (subcollection)
///   │   │   └── {hajjId}: HajjTracking
///   │   └── reports/ (subcollection)
///   │       └── {reportId}: MonthlyReport

const String usersCollection = 'users';
const String dailyWorshipCollection = 'daily_worship';
const String monthlyGoalsCollection = 'monthly_goals';
const String weeklyPlansCollection = 'weekly_plans';
const String ramadanCollection = 'ramadan';
const String hajjCollection = 'hajj';
const String reportsCollection = 'reports';
const String adminNotificationsCollection = 'admin_notifications';

/// Firestore Security Rules
/// Apply these rules in Firebase Console > Firestore Database > Rules
///
/// rules_version = '2';
/// service cloud.firestore {
///   match /databases/{database}/documents {
///     // Users collection
///     // See firestore.rules in project root (admins can read all users + set canUpload).
///     match /users/{userId} {
///       allow read: if request.auth != null && (
///         request.auth.uid == userId ||
///         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin'
///       );
///       allow create: if request.auth.uid == userId;
///       allow update: if request.auth != null && (
///         request.auth.uid == userId ||
///         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin'
///       );
///       match /{document=**} {
///         allow read, write: if request.auth.uid == userId;
///       }
///     }
///
///     // Admin notifications collection
///     match /admin_notifications/{notificationId} {
///       allow read: if request.auth != null;
///       allow write: if request.auth != null && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
///     }
///   }
/// }

/// Database Indexes
/// Create these indexes in Firebase Console for better query performance:
///
/// 1. users -> daily_worship
///    - Fields: date (Ascending), user ID
///
/// 2. users -> monthly_goals
///    - Fields: category (Ascending), startDate (Ascending)
///
/// 3. users -> weekly_plans
///    - Fields: monthlyGoalId (Ascending), weekStartDate (Descending)
///
/// 4. users -> ramadan
///    - Fields: currentDay (Ascending)
///
/// 5. users -> hajj
///    - Fields: isInHajjMode (Ascending)
