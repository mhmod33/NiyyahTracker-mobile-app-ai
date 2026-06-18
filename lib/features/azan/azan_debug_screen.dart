import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../services/azan_debug_log.dart';
import '../../services/azan_service.dart';

class AzanDebugScreen extends StatefulWidget {
  const AzanDebugScreen({super.key});

  @override
  State<AzanDebugScreen> createState() => _AzanDebugScreenState();
}

class _AzanDebugScreenState extends State<AzanDebugScreen> {
  final _azanService = AzanService();
  String _log = 'جاري التحميل...';
  bool _loading = true;
  bool _testing = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final content = await AzanDebugLog.read();
    final path = await AzanDebugLog.filePath();
    setState(() {
      _log = 'Path: $path\n\n$content';
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _clear() async {
    await AzanDebugLog.clear();
    await _load();
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _log));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم النسخ إلى الحافظة'), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _testFlutter() async {
    setState(() => _testing = true);
    await AzanDebugLog.write('--- TEST FLUTTER AZAN BUTTON PRESSED ---');
    await _azanService.testFlutterAzan();
    await _load();
    setState(() => _testing = false);
  }

  Future<void> _testNative() async {
    setState(() => _testing = true);
    await AzanDebugLog.write('--- TEST NATIVE ALARM BUTTON PRESSED ---');
    final msg = await _azanService.testNativeAlarm(delaySeconds: 15);
    await _load();
    setState(() => _testing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
      );
    }
  }

  Future<void> _stopAzan() async {
    await AzanDebugLog.write('--- STOP AZAN BUTTON PRESSED ---');
    await _azanService.stopAzan();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F7F6);
    final cardBg = isDark ? const Color(0xFF1A1F1C) : Colors.white;
    final textColor = isDark ? Colors.white70 : Colors.black87;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF0D2818) : const Color(0xFF145A3A),
          foregroundColor: Colors.white,
          title: Text(
            'سجل تشخيص الأذان',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث',
              onPressed: _load,
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'نسخ',
              onPressed: _copy,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'مسح السجل',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('مسح السجل؟'),
                    content: const Text('سيتم حذف جميع سجلات التشخيص.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('إلغاء'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('مسح', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) _clear();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // ── Test Buttons ──
            Container(
              color: isDark ? const Color(0xFF111511) : const Color(0xFFEEF3F0),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: _testing
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(color: AppColors.darkGreen),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'اختبار تشغيل الأذان',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _TestButton(
                                label: 'تشغيل فوري (Flutter)',
                                subtitle: 'يختبر مشغل الصوت مباشرة',
                                icon: Icons.play_circle_rounded,
                                color: AppColors.darkGreen,
                                onTap: _testFlutter,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _TestButton(
                                label: 'تنبيه أصلي (15 ث)',
                                subtitle: 'يختبر AlarmManager الأصلي',
                                icon: Icons.alarm_rounded,
                                color: Colors.blue.shade700,
                                onTap: _testNative,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _TestButton(
                                label: 'إيقاف',
                                subtitle: 'إيقاف الأذان الحالي',
                                icon: Icons.stop_circle_rounded,
                                color: Colors.red.shade700,
                                onTap: _stopAzan,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),

            // ── Log ──
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.darkGreen))
                  : Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.black.withOpacity(0.06),
                        ),
                      ),
                      child: Scrollbar(
                        controller: _scrollController,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          child: SelectableText(
                            _log,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: textColor,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TestButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TestButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 9,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
