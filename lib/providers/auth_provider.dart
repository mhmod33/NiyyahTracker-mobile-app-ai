import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralized authentication provider that manages Firebase Auth state
/// and user profile data from Firestore.
class AppAuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? _user;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<User?>? _authSubscription;

  // ── Getters ──
  User? get user => _user;
  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get errorMessage => _errorMessage;
  String get userId => _user?.uid ?? '';
  String get displayName => _userProfile?['name'] ?? _user?.displayName ?? 'مستخدم النية';
  String get email => _user?.email ?? '';
  String get phone => _user?.phoneNumber ?? '';

  AppAuthProvider() {
    _init();
  }

  void _init() {
    _authSubscription = _auth.authStateChanges().listen((User? user) async {
      _user = user;
      if (user != null) {
        await _loadUserProfile();
      } else {
        _userProfile = null;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Load user profile from Firestore
  Future<void> _loadUserProfile() async {
    if (_user == null) return;
    try {
      final doc = await _db.collection('users').doc(_user!.uid).get();
      if (doc.exists) {
        _userProfile = doc.data();
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Register with email & password + create Firestore profile
  Future<bool> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Update display name
      await credential.user?.updateDisplayName(name.trim());

      // Create Firestore user profile
      if (credential.user != null) {
        await _db.collection('users').doc(credential.user!.uid).set({
          'name': name.trim(),
          'email': email.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'streakDays': 0,
          'totalWorships': 0,
          'settings': {
            'notificationsEnabled': true,
            'language': 'ar',
          },
        });
        await _loadUserProfile();
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getArabicErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'حدث خطأ غير متوقع: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in with email & password
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Update last login
      if (_user != null) {
        await _db.collection('users').doc(_user!.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
        }).catchError((_) {}); // Ignore if doc doesn't exist yet
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getArabicErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'حدث خطأ غير متوقع: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Send password reset email
  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getArabicErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'حدث خطأ: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _auth.signOut();
      _userProfile = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'فشل تسجيل الخروج';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update user profile in Firestore
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    if (_user == null) return false;
    try {
      await _db.collection('users').doc(_user!.uid).update(data);
      await _loadUserProfile();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'فشل تحديث الملف الشخصي';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Arabic error messages for Firebase Auth error codes
  String _getArabicErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'البريد الإلكتروني مسجل بالفعل';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صالح';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً (يجب أن تكون 6 أحرف على الأقل)';
      case 'user-not-found':
        return 'لا يوجد حساب بهذا البريد الإلكتروني';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة';
      case 'user-disabled':
        return 'هذا الحساب معطل';
      case 'too-many-requests':
        return 'محاولات كثيرة جداً. حاول لاحقاً';
      case 'operation-not-allowed':
        return 'هذه العملية غير مسموحة';
      case 'network-request-failed':
        return 'خطأ في الاتصال بالإنترنت';
      case 'invalid-credential':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      default:
        return 'حدث خطأ: $code';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
