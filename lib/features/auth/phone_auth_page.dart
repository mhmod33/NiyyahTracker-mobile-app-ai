import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:country_picker/country_picker.dart';
import '../../core/app_colors.dart';
import '../../core/directional_icon.dart';
import '../dashboard/dashboard_page.dart';
import '../../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PhoneAuthPage extends StatefulWidget {
  const PhoneAuthPage({super.key});

  @override
  State<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends State<PhoneAuthPage> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final AuthService _authService = AuthService();
  
  bool _codeSent = false;
  String _verificationId = '';
  bool _isLoading = false;
  Country _selectedCountry = CountryParser.parseCountryCode('EG');

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال رقم الهاتف')));
      return;
    }
    
    // Combine country code with phone number (trim leading zero if present)
    String phoneText = phone;
    if (phoneText.startsWith('0')) {
      phoneText = phoneText.substring(1);
    }
    final fullPhoneNumber = '+${_selectedCountry.phoneCode}$phoneText';

    setState(() => _isLoading = true);
    await _authService.verifyPhoneNumber(
      phoneNumber: fullPhoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          final user = await FirebaseAuth.instance.signInWithCredential(credential);
          if (user.user != null && mounted) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardPage()));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في التحقق التلقائي: $e')));
          }
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isLoading = false);
        String errorMsg = e.message ?? e.toString();
        if (e.code == 'invalid-phone-number') {
          errorMsg = 'رقم الهاتف غير صالح. تأكد من إدخال الرمز الدولي صحيحاً.';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التحقق: $errorMsg')));
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _codeSent = true;
          _isLoading = false;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  void _verifyCode() async {
    setState(() => _isLoading = true);
    final user = await _authService.signInWithOTP(_verificationId, _otpController.text.trim());
    setState(() => _isLoading = false);
    
    if (user != null && mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardPage()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرمز غير صحيح')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
            leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.darkGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: DirectionalIcon(isBack: true, size: 18, color: AppColors.darkGreen),
              ),
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _codeSent ? 'أدخل رمز التحقق' : 'تسجيل الدخول برقم الهاتف',
                style: GoogleFonts.cairo(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkGreen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _codeSent 
                  ? 'تم إرسال رسالة قصيرة تحتوي على الرمز إلى ${_selectedCountry.phoneCode}${_phoneController.text}'
                  : 'اختر دولتك ثم أدخل رقم هاتفك',
                style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 40),
              if (!_codeSent) ...[
                // Integrated Phone Input
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    enabled: !_isLoading,
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: '1X XXXX XXXX',
                      hintStyle: GoogleFonts.cairo(color: Colors.grey[400]),
                      prefixIcon: GestureDetector(
                        onTap: () {
                          showCountryPicker(
                            context: context,
                            showPhoneCode: true,
                            onSelect: (Country country) {
                              setState(() {
                                _selectedCountry = country;
                              });
                            },
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: Colors.grey.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedCountry.flagEmoji,
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '+${_selectedCountry.phoneCode}',
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkGreen,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: AppColors.midGreen, size: 20),
                            ],
                          ),
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.paleGreen),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.paleGreen),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.darkGreen, width: 2),
                      ),
                    ),
                  ),
                ),
              ]
              else
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                  maxLength: 6,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '------',
                    hintStyle: GoogleFonts.cairo(color: Colors.grey[400], letterSpacing: 8),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.paleGreen),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.darkGreen, width: 2),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : (_codeSent ? _verifyCode : _sendCode),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _codeSent ? 'تحقق من الرمز' : 'إرسال الرمز',
                        style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
