import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';

class ReadingStatsPage extends StatefulWidget {
  const ReadingStatsPage({super.key});

  @override
  State<ReadingStatsPage> createState() => _ReadingStatsPageState();
}

class _ReadingStatsPageState extends State<ReadingStatsPage> {
  Map<String, dynamic> _todayStats = {};
  Map<String, dynamic> _weekStats = {};
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final box = await Hive.openBox('reading_stats');
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Today's stats
      final todaySessions = box.get(today, defaultValue: []) as List;
      final todaySeconds = todaySessions.fold<int>(
        0,
        (sum, session) => sum + ((session as Map)['duration'] as int? ?? 0),
      );

      setState(() {
        _todayStats = {
          'date': today,
          'seconds': todaySeconds,
          'minutes': (todaySeconds / 60).round(),
          'sessions': todaySessions.length,
        };
      });

      // Week stats
      final now = DateTime.now();
      int weekTotal = 0;
      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        final dateStr = date.toIso8601String().substring(0, 10);
        final sessions = box.get(dateStr, defaultValue: []) as List;
        final daySeconds = sessions.fold<int>(
          0,
          (sum, s) => sum + ((s as Map)['duration'] as int? ?? 0),
        );
        weekTotal += daySeconds;
      }

      setState(() {
        _weekStats = {
          'seconds': weekTotal,
          'minutes': (weekTotal / 60).round(),
        };
      });

      // Calculate streak
      int streak = 0;
      for (int i = 0; i < 365; i++) {
        final date = now.subtract(Duration(days: i));
        final dateStr = date.toIso8601String().substring(0, 10);
        final sessions = box.get(dateStr, defaultValue: []) as List;
        if (sessions.isEmpty) break;
        streak++;
      }

      setState(() => _streak = streak);
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF1A1A1A)
            : const Color(0xFFFAF8F3),
        appBar: AppBar(
          backgroundColor: isDark
              ? const Color(0xFF0B120D)
              : AppColors.darkGreen,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'إحصائيات القراءة',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _loadStats,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Today's Reading
              _buildStatCard(
                title: 'اليوم',
                icon: Icons.today_rounded,
                mainValue: '${_todayStats['minutes'] ?? 0}',
                mainLabel: 'دقيقة',
                subtitle: '${_todayStats['sessions'] ?? 0} جلسة قراءة',
                color: AppColors.darkGreen,
                isDark: isDark,
              ),

              const SizedBox(height: 16),

              // This Week
              _buildStatCard(
                title: 'هذا الأسبوع',
                icon: Icons.calendar_today_rounded,
                mainValue: '${_weekStats['minutes'] ?? 0}',
                mainLabel: 'دقيقة',
                subtitle: '${(_weekStats['minutes'] ?? 0) / 7} دقيقة/يوم',
                color: AppColors.gold,
                isDark: isDark,
              ),

              const SizedBox(height: 16),

              // Streak
              _buildStatCard(
                title: 'سلسلة القراءة',
                icon: Icons.local_fire_department_rounded,
                mainValue: '$_streak',
                mainLabel: _streak == 1 ? 'يوم' : 'أيام',
                subtitle: _streak > 0
                    ? 'ما شاء الله! استمر'
                    : 'ابدأ سلسلة جديدة اليوم',
                color: Colors.orange,
                isDark: isDark,
              ),

              const SizedBox(height: 24),

              // Motivation message
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.darkGreen.withOpacity(0.1),
                      AppColors.gold.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : AppColors.darkGreen.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.auto_stories_rounded,
                      color: AppColors.darkGreen,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getMotivationMessage(),
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required IconData icon,
    required String mainValue,
    required String mainLabel,
    required String subtitle,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                mainValue,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  mainLabel,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white70
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 14,
              color: isDark ? Colors.white54 : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _getMotivationMessage() {
    final minutes = _todayStats['minutes'] ?? 0;
    if (minutes == 0) {
      return '﴿ وَرَتِّلِ الْقُرْآنَ تَرْتِيلًا ﴾\nابدأ قراءتك اليوم';
    } else if (minutes < 5) {
      return 'بداية رائعة! واصل القراءة';
    } else if (minutes < 15) {
      return 'ما شاء الله! قراءة مباركة';
    } else if (minutes < 30) {
      return 'اللهم بارك! قراءة ممتازة';
    } else {
      return 'ما شاء الله تبارك الله! قراءة مميزة';
    }
  }
}
