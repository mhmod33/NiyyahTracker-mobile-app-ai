import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/app_colors.dart';
import '../../core/app_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../models/challenge_model.dart';

TextStyle _f({double sz = 14, FontWeight fw = FontWeight.w400, Color? c, double? h}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c, height: h);

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});
  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = true;
  List<Challenge> _challenges = [];

  @override
  void initState() {
    super.initState();
    _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    final userId = context.read<AppAuthProvider>().userId;
    if (userId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final challenges = await _firebaseService.getChallenges(userId);
      
      if (challenges.isEmpty) {
        // Add default challenges if none exist
        _challenges = [
          Challenge(id: '1', title: 'صيام الاثنين والخميس', desc: 'سنة مؤكدة عن النبي ﷺ', icon: 'nights_stay', gradient: ['#1A237E', '#3949AB'], target: 8, current: 0),
          Challenge(id: '2', title: 'الورد القرآني', desc: 'استمرار قراءة القرآن', icon: 'auto_stories', gradient: ['#4A148C', '#7B1FA2'], target: 30, current: 0),
          Challenge(id: '3', title: 'قيام الليل', desc: 'شرف المؤمن', icon: 'star', gradient: ['#0D47A1', '#1976D2'], target: 30, current: 0),
        ];
        for (var c in _challenges) {
          await _firebaseService.saveChallenge(userId, c);
        }
      } else {
        _challenges = challenges;
      }
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading challenges: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F7F6);
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    final completed = _challenges.where((c) => c.current >= c.target).length;
    final totalProgress = _challenges.isEmpty ? 0.0 : _challenges.fold<double>(0, (s, c) => s + (c.current / c.target).clamp(0, 1)) / _challenges.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: _isLoading ? const Center(child: CircularProgressIndicator(color: AppColors.gold)) : CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Modern Header ──
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, bottom: 28, left: 20, right: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark ? [const Color(0xFF0D2818), const Color(0xFF0A3D22)] : [const Color(0xFF145A3A), const Color(0xFF1E8255)],
                  ),
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _BackButton(),
                        Expanded(child: Text('التحديات الروحية', textAlign: TextAlign.center, style: _f(sz: 20, fw: FontWeight.w800, c: Colors.white))),
                        IconButton(icon: const Icon(Icons.add_rounded, color: Colors.white), onPressed: () => _showAddChallengeDialog(isDark)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _ProgressOverview(totalProgress: totalProgress, completedCount: completed, totalCount: _challenges.length, totalFire: _challenges.fold(0, (s, c) => s + c.current)),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 12), child: Text('تحدياتك النشطة', style: _f(sz: 18, fw: FontWeight.w800, c: textColor)))),

            // ── Challenge List ──
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((ctx, i) {
                  final c = _challenges[i];
                  return _ChallengeCard(challenge: c, isDark: isDark, onUpdate: () => _updateProgress(c));
                }, childCount: _challenges.length),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  void _showAddChallengeDialog(bool isDark) {
    final titleController = TextEditingController();
    final targetController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('إضافة تحدي جديد', style: _f(sz: 18, fw: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: InputDecoration(hintText: 'اسم التحدي (مثلاً: ركعتي الضحى)', hintStyle: _f(c: AppColors.gray))),
              const SizedBox(height: 12),
              TextField(controller: targetController, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: 'الهدف (مثلاً: 30 يوماً)', hintStyle: _f(c: AppColors.gray))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: _f(c: Colors.grey))),
            ElevatedButton(
              onPressed: () => _addNewChallenge(titleController.text, targetController.text),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('إضافة', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addNewChallenge(String title, String targetStr) async {
    final target = int.tryParse(targetStr) ?? 30;
    if (title.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يرجى إدخال اسم التحدي', style: GoogleFonts.cairo()), backgroundColor: Colors.red),
      );
      return;
    }

    if (target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يرجى إدخال هدف صحيح', style: GoogleFonts.cairo()), backgroundColor: Colors.red),
      );
      return;
    }

    final userId = context.read<AppAuthProvider>().userId;
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يرجى تسجيل الدخول أولاً', style: GoogleFonts.cairo()), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final newChallenge = Challenge(
        id: const Uuid().v4(),
        title: title.trim(),
        desc: 'تحدي مخصص',
        icon: 'star',
        target: target,
        current: 0,
        gradient: ['#1B5E20', '#388E3C'],
      );

      await _firebaseService.saveChallenge(userId, newChallenge);
      Navigator.pop(context);
      _loadChallenges();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إضافة التحدي بنجاح 🎯', style: GoogleFonts.cairo(color: Colors.white)), backgroundColor: AppColors.darkGreen),
      );
    } catch (e) {
      debugPrint('Error adding challenge: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء إضافة التحدي', style: GoogleFonts.cairo()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _updateProgress(Challenge c) async {
    if (c.current >= c.target) return;
    final userId = context.read<AppAuthProvider>().userId;
    await _firebaseService.updateChallengeProgress(userId, c.id, c.current + 1);
    _loadChallenges();
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.pop(context),
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
      child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
    ),
  );
}

class _ProgressOverview extends StatelessWidget {
  final double totalProgress; final int completedCount, totalCount, totalFire;
  const _ProgressOverview({required this.totalProgress, required this.completedCount, required this.totalCount, required this.totalFire});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.1))),
    child: Row(children: [
      Stack(alignment: Alignment.center, children: [
        SizedBox(width: 60, height: 60, child: CircularProgressIndicator(value: totalProgress, strokeWidth: 6, backgroundColor: Colors.white12, color: AppColors.gold, strokeCap: StrokeCap.round)),
        Text('${(totalProgress * 100).toInt()}%', style: _f(sz: 12, fw: FontWeight.w800, c: Colors.white)),
      ]),
      const SizedBox(width: 20),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('تقدمك الإجمالي', style: _f(sz: 15, fw: FontWeight.w800, c: Colors.white)),
        Text('$completedCount من $totalCount تحديات مكتملة', style: _f(sz: 12, c: Colors.white70)),
      ])),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Text('🔥 $totalFire', style: _f(sz: 13, fw: FontWeight.bold, c: AppColors.gold))),
    ]),
  );
}

class _ChallengeCard extends StatelessWidget {
  final Challenge challenge; final bool isDark; final VoidCallback onUpdate;
  const _ChallengeCard({required this.challenge, required this.isDark, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final done = challenge.current >= challenge.target;
    final progress = (challenge.current / challenge.target).clamp(0.0, 1.0);
    final color = _parseColor(challenge.gradient[0]);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F1C) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        onTap: onUpdate,
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]), borderRadius: BorderRadius.circular(16)),
          child: Icon(done ? Icons.check_rounded : _getIcon(challenge.icon), color: Colors.white, size: 28),
        ),
        title: Text(challenge.title, style: _f(sz: 16, fw: FontWeight.w800)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 4),
          Text(challenge.desc, style: _f(sz: 12, c: AppColors.gray)),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.grey.withOpacity(0.1), color: color)),
        ]),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${challenge.current}', style: _f(sz: 18, fw: FontWeight.w900, c: color)),
          Text('/ ${challenge.target}', style: _f(sz: 10, c: AppColors.gray)),
        ]),
      ),
    );
  }

  Color _parseColor(String hex) => Color(int.parse(hex.replaceFirst('#', '0xFF')));
  IconData _getIcon(String name) => name == 'nights_stay' ? Icons.nights_stay_rounded : name == 'auto_stories' ? Icons.auto_stories_rounded : Icons.star_rounded;
}
