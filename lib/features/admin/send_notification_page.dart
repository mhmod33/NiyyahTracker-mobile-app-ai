import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_notification_service.dart';

class SendNotificationPage extends StatefulWidget {
  const SendNotificationPage({super.key});

  @override
  State<SendNotificationPage> createState() => _SendNotificationPageState();
}

class _SendNotificationPageState extends State<SendNotificationPage> {
  final _titleCtl = TextEditingController();
  final _bodyCtl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleCtl.dispose();
    _bodyCtl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleCtl.text.trim();
    final body = _bodyCtl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يرجى كتابة العنوان والرسالة', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white)),
          backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _sending = true);
    final auth = context.read<AppAuthProvider>();
    final ok = await AdminNotificationService().sendNotification(
      title: title,
      body: body,
      adminId: auth.userId,
      adminName: auth.displayName,
    );
    setState(() => _sending = false);

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إرسال الإشعار بنجاح', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white)),
          backgroundColor: AppColors.darkGreen),
      );
      _titleCtl.clear();
      _bodyCtl.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل إرسال الإشعار', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white)),
          backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: AppColors.darkGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text('إرسال إشعار', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.goldLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.campaign_rounded, color: AppColors.gold, size: 28),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    'سيتم إرسال هذا الإشعار لجميع مستخدمي التطبيق',
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: AppColors.gold, fontWeight: FontWeight.w600),
                  )),
                ]),
              ),
              const SizedBox(height: 24),
              Text('العنوان', style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.darkGreen)),
              const SizedBox(height: 8),
              TextField(
                controller: _titleCtl,
                textDirection: TextDirection.rtl,
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 15, color: isDark ? Colors.white : AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'مثال: تحديث جديد في التطبيق',
                  hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: AppColors.gray),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.title_rounded, color: AppColors.darkGreen),
                ),
              ),
              const SizedBox(height: 20),
              Text('الرسالة', style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.darkGreen)),
              const SizedBox(height: 8),
              TextField(
                controller: _bodyCtl,
                textDirection: TextDirection.rtl,
                maxLines: 6,
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 15, color: isDark ? Colors.white : AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'اكتب رسالتك هنا...',
                  hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: AppColors.gray),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, color: Colors.white),
                  label: Text(_sending ? 'جاري الإرسال...' : 'إرسال الإشعار', style: GoogleFonts.ibmPlexSansArabic(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
