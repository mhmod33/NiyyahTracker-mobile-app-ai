import 'package:firebase_auth/firebase_auth.dart';

class PhoneAuthService {
  static final PhoneAuthService _instance = PhoneAuthService._internal();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  factory PhoneAuthService() {
    return _instance;
  }

  PhoneAuthService._internal();

  // Phone number format for Egypt: +20 XXX XXX XXXX
  // Mobile operators: Vodafone (10, 12), Etisalat (11, 15), Orange (16, 18), We (17)
  static const String egyptCountryCode = '+20';
  static const String egyptCountryName = 'Egypt - مصر';

  /// Valid phone prefixes for Egypt
  static const List<String> egyptMobileOperators = [
    '10', // Vodafone
    '11', // Etisalat
    '12', // Vodafone
    '15', // Etisalat
    '16', // Orange
    '17', // We
    '18', // Orange
  ];

  /// Validate phone number format
  static bool isValidPhone(String phoneNumber) {
    // Remove spaces, dashes, and plus
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\+]'), '');
    
    // Basic validation: should be at least 7 digits (international minimum)
    return cleanNumber.length >= 7;
  }

  /// Format phone number to international format
  static String formatPhone(String phoneNumber) {
    // If it already starts with +, just clean internal spaces/dashes
    if (phoneNumber.startsWith('+')) {
      return '+' + phoneNumber.replaceAll(RegExp(r'[\s\-\+]'), '');
    }
    
    // Otherwise, ensure it has a + (caller should provide country code)
    String clean = phoneNumber.replaceAll(RegExp(r'[\s\-\+]'), '');
    return '+$clean';
  }

  /// Send OTP to any phone number
  Future<String?> sendOtp(
    String phoneNumber, {
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    try {
      String formattedPhone = formatPhone(phoneNumber);

      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: const Duration(minutes: 2),
        verificationCompleted: verificationCompleted,
        verificationFailed: verificationFailed,
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      );

      return formattedPhone;
    } on FirebaseAuthException catch (e) {
      rethrow;
    }
  }

  /// Verify OTP code
  Future<UserCredential?> verifyOtpCode(
    String verificationId,
    String smsCode,
  ) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        throw FirebaseAuthException(
          code: 'invalid-verification-code',
          message: 'رمز التحقق غير صحيح. حاول مرة أخرى.',
        );
      }
      rethrow;
    }
  }

  /// Resend OTP
  Future<void> resendOtp(
    String phoneNumber, {
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    try {
      String formattedPhone = formatPhone(phoneNumber);

      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: const Duration(minutes: 2),
        verificationCompleted: verificationCompleted,
        verificationFailed: verificationFailed,
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
        forceResendingToken: null,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Keep compatibility for Egypt if needed elsewhere
  static bool isValidEgyptianPhone(String phoneNumber) => isValidPhone(phoneNumber);
  static String formatEgyptianPhone(String phoneNumber) => formatPhone(phoneNumber);
  Future<String?> sendOtpToEgyptianPhone(String p, {required dynamic verificationCompleted, required dynamic verificationFailed, required dynamic codeSent, required dynamic codeAutoRetrievalTimeout}) => 
    sendOtp(p, verificationCompleted: verificationCompleted, verificationFailed: verificationFailed, codeSent: codeSent, codeAutoRetrievalTimeout: codeAutoRetrievalTimeout);

  /// Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

/// Country configuration for phone authentication
class PhoneAuthCountry {
  final String name;
  final String countryCode;
  final String dialCode;
  final List<String> mobileOperators;
  final String example;

  const PhoneAuthCountry({
    required this.name,
    required this.countryCode,
    required this.dialCode,
    required this.mobileOperators,
    required this.example,
  });
}

/// Predefined countries for phone authentication
class PhoneAuthCountries {
  static const PhoneAuthCountry egypt = PhoneAuthCountry(
    name: 'Egypt - مصر',
    countryCode: 'EG',
    dialCode: '+20',
    mobileOperators: [
      '10 - Vodafone',
      '11 - Etisalat',
      '12 - Vodafone',
      '15 - Etisalat',
      '16 - Orange',
      '17 - We',
      '18 - Orange',
    ],
    example: '+201001234567',
  );

  static const PhoneAuthCountry unitedArabEmirates = PhoneAuthCountry(
    name: 'United Arab Emirates - الإمارات',
    countryCode: 'AE',
    dialCode: '+971',
    mobileOperators: [
      '50 - Etisalat',
      '51 - Etisalat',
      '52 - Du',
      '55 - Du',
      '56 - Du',
    ],
    example: '+971501234567',
  );

  static const PhoneAuthCountry saudiArabia = PhoneAuthCountry(
    name: 'Saudi Arabia - السعودية',
    countryCode: 'SA',
    dialCode: '+966',
    mobileOperators: [
      '50 - STC',
      '51 - STC',
      '52 - STC',
      '53 - STC',
      '54 - STC',
      '55 - Mobily',
      '56 - Mobily',
      '57 - Mobily',
      '58 - Mobily',
      '59 - Zain',
    ],
    example: '+966501234567',
  );

  static List<PhoneAuthCountry> get arabCountries => [
    egypt,
    unitedArabEmirates,
    saudiArabia,
  ];
}
