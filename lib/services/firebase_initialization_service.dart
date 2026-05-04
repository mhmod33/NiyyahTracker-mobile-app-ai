import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

class FirebaseInitializationService {
  static Future<void> initializeFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      throw Exception('Failed to initialize Firebase: $e');
    }
  }

  static Future<void> setupFirestoreRules() async {
    // Note: Firestore security rules should be set up in Firebase Console
    // This is just a placeholder for reference
  }
}
