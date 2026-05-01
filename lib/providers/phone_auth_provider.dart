import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/phone_auth_service.dart';

class PhoneAuthProvider extends ChangeNotifier {
  final PhoneAuthService _phoneAuthService = PhoneAuthService();

  String? _verificationId;
  bool _isOtpSent = false;
  bool _isLoading = false;
  String? _errorMessage;
  User? _currentUser;
  int _resendCountdown = 0;

  // Getters
  bool get isOtpSent => _isOtpSent;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _currentUser;
  int get resendCountdown => _resendCountdown;

  PhoneAuthProvider() {
    _currentUser = _phoneAuthService.getCurrentUser();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> sendOtpToPhone(String phoneNumber) async {
    if (!PhoneAuthService.isValidEgyptianPhone(phoneNumber)) {
      _errorMessage = 'رقم الهاتف المصري غير صحيح. يجب أن يكون في الصيغة: +20XXXXXXXXXX';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _phoneAuthService.sendOtpToEgyptianPhone(
        phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            _currentUser = FirebaseAuth.instance.currentUser;
            _isLoading = false;
            _isOtpSent = false;
            notifyListeners();
          } catch (e) {
            _errorMessage = 'خطأ في تسجيل الدخول';
            _isLoading = false;
            notifyListeners();
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          _errorMessage = e.message ?? 'حدث خطأ في التحقق';
          _isLoading = false;
          notifyListeners();
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _isOtpSent = true;
          _isLoading = false;
          _resendCountdown = 60;
          _errorMessage = null;
          notifyListeners();
          _startResendCountdown();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> verifyOtp(String otp) async {
    if (_verificationId == null) {
      _errorMessage = 'معرّف التحقق غير موجود';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _phoneAuthService.verifyOtpCode(_verificationId!, otp);
      _currentUser = FirebaseAuth.instance.currentUser;
      _isLoading = false;
      _isOtpSent = false;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'فشل التحقق من الرمز';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resendOtp(String phoneNumber) async {
    if (_resendCountdown > 0) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _phoneAuthService.resendOtp(
        phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            _currentUser = FirebaseAuth.instance.currentUser;
            _isLoading = false;
            _isOtpSent = false;
            notifyListeners();
          } catch (e) {
            _errorMessage = 'خطأ في تسجيل الدخول';
            _isLoading = false;
            notifyListeners();
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          _errorMessage = e.message ?? 'حدث خطأ في التحقق';
          _isLoading = false;
          notifyListeners();
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _isLoading = false;
          _resendCountdown = 60;
          notifyListeners();
          _startResendCountdown();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startResendCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_resendCountdown > 0) {
        _resendCountdown--;
        notifyListeners();
        _startResendCountdown();
      }
    });
  }

  void resetOtpFlow() {
    _isOtpSent = false;
    _verificationId = null;
    _errorMessage = null;
    _isLoading = false;
    _resendCountdown = 0;
    notifyListeners();
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _phoneAuthService.signOut();
      _currentUser = null;
      _isLoading = false;
      _isOtpSent = false;
      _verificationId = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'فشل تسجيل الخروج';
      _isLoading = false;
      notifyListeners();
    }
  }

  bool get isAuthenticated => _currentUser != null;

  String? get userPhoneNumber => _currentUser?.phoneNumber;
  String? get userId => _currentUser?.uid;
}
