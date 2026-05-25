/// Bootstrap admin accounts by email (lowercase).
///
/// Add your Firebase Auth email(s) here. On sign-in, matching users get
/// `role: admin` and `canUpload: true` in Firestore automatically.
///
/// You can also promote a user manually in Firebase Console:
/// Firestore → users → {uid} → set `role` to `admin` and `canUpload` to `true`.
const List<String> kBootstrapAdminEmails = [
  'me653830@gmail.com',
];

bool isBootstrapAdminEmail(String? email) {
  if (email == null || email.isEmpty) return false;
  final normalized = email.trim().toLowerCase();
  return kBootstrapAdminEmails
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .contains(normalized);
}
