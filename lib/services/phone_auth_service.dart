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

  /// Validate Egyptian phone number
  /// Phone should be: +20 followed by 10 digits starting with valid operator code
  static bool isValidEgyptianPhone(String phoneNumber) {
    // Remove spaces and dashes
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[\s\-]'), '');

    // Check if starts with +20 or just the 10-digit number
    if (cleanNumber.startsWith('+20')) {
      cleanNumber = cleanNumber.substring(3);
    } else if (cleanNumber.startsWith('0')) {
      cleanNumber = cleanNumber.substring(1);
    }

    // Check length and format
    if (cleanNumber.length != 10) {
      return false;
    }

    // Check if first 2 digits are valid operator code
    String firstTwoDigits = cleanNumber.substring(0, 2);
    return egyptMobileOperators.contains(firstTwoDigits);
  }

  /// Format Egyptian phone number to international format (+20...)
  static String formatEgyptianPhone(String phoneNumber) {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[\s\-]'), '');

    // Remove leading 0 if present
    if (cleanNumber.startsWith('0')) {
      cleanNumber = cleanNumber.substring(1);
    }

    // Remove +20 if present and add back properly
    if (cleanNumber.startsWith('20')) {
      cleanNumber = cleanNumber.substring(2);
    }

    return '+20$cleanNumber';
  }

  /// Send OTP to Egyptian phone number
  Future<String?> sendOtpToEgyptianPhone(
    String phoneNumber, {
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    try {
      if (!isValidEgyptianPhone(phoneNumber)) {
        throw FirebaseAuthException(
          code: 'invalid-phone-number',
          message: 'رقم الهاتف المصري غير صحيح. يجب أن يكون في الصيغة: +20XXXXXXXXXX',
        );
      }

      String formattedPhone = formatEgyptianPhone(phoneNumber);

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
      String formattedPhone = formatEgyptianPhone(phoneNumber);

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
