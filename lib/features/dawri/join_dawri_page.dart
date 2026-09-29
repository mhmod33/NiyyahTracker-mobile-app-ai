import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/dawri_service.dart';
import 'dawri_detail_page.dart';

TextStyle _f({
  double sz = 14,
  FontWeight fw = FontWeight.w400,
  Color? c,
  double? h,
}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c, height: h);

class JoinDawriPage extends StatefulWidget {
  const JoinDawriPage({super.key});

  @override
  State<JoinDawriPage> createState() => _JoinDawriPageState();
}

class _JoinDawriPageState extends State<JoinDawriPage> {
  final _codeCtrl = TextEditingController();
  bool _joining = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  bool get _canJoin => _codeCtrl.text.trim().length == 8;

  Future<void> _join() async {
    if (!_canJoin) return;
    final auth = context.read<AppAuthProvider>();
    setState(() => _joining = true);
    try {
      final dawri = await DawriService().joinByCode(
        userId: auth.userId,
        userName: auth.displayName,
        code: _codeCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DawriDetailPage(dawriId: dawri.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(e.toString().replaceAll('Exception: ', ''),
                  style: _f(c: Colors.white)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAF9);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor:
              isDark ? const Color(0xFF0D2818) : AppColors.darkGreen,
          foregroundColor: Colors.white,
          title: Text(
            'الانضمام إلى دوري',
            style: _f(sz: 20, fw: FontWeight.w800, c: Colors.white),
          ),
          centerTitle: true,
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Envelope icon
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.darkGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_read_rounded,
                  size: 60,
                  color: AppColors.darkGreen.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'أدخل رمز الدعوة',
                style: _f(
                  sz: 22,
                  fw: FontWeight.w900,
                  c: isDark ? Colors.white : AppColors.darkGreen,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'اطلب رمز الدعوة من مشرف الدوري.',
                style: _f(sz: 14, c: AppColors.gray),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              // Code input
              TextField(
                controller: _codeCtrl,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                maxLength: 8,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                  color: isDark ? Colors.white : AppColors.darkGreen,
                ),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'X X X X X X X X',
                  hintStyle: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray.withOpacity(0.4),
                    letterSpacing: 6,
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.05)
                      : AppColors.paleGreen,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                        color: AppColors.darkGreen, width: 2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'رموز الدعوة غير حساسة لحالة الأحرف.',
                style: _f(sz: 11, c: AppColors.gray),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _canJoin && !_joining ? _join : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkGreen,
                    disabledBackgroundColor:
                        AppColors.gray.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _joining
                      ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)
                      : Text(
                          'الانضمام للدوري',
                          style: _f(
                              sz: 16,
                              fw: FontWeight.bold,
                              c: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
