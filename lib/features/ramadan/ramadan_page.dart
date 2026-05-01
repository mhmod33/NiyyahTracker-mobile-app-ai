import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';

class RamadanPage extends StatelessWidget {
  const RamadanPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Days until next Ramadan (approximate)
    final daysUntilLaylatAlQadr = 27 - DateTime.now().day;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A0E21),
          title: Text('🌙 مود رمضان', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Laylat Al-Qadr Countdown
            _laylatAlQadrCard(daysUntilLaylatAlQadr),
            const SizedBox(height: 16),
            // Suhoor & Iftar Times
            _timesCard(),
            const SizedBox(height: 16),
            // 30-Day Plan Progress
            _thirtyDayPlan(),
            const SizedBox(height: 16),
            // Taraweeh tracker
            _taraweehCard(),
          ],
        ),
      ),
    );
  }

  Widget _laylatAlQadrCard(int days) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF311B92)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text('⭐', style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text('العد التنازلي لليلة القدر', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text('${days.abs()} يوم', style: GoogleFonts.cairo(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold)),
          Text('ليلة ٢٧ رمضان', style: GoogleFonts.cairo(color: AppColors.goldLight, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _timesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151929),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('مواعيد اليوم', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _timeBox('السحور', '٣:٤٥ ص', '🌅')),
              const SizedBox(width: 12),
              Expanded(child: _timeBox('الإفطار', '٦:٢٨ م', '🌆')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeBox(String label, String time, String emoji) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12)),
          Text(time, style: GoogleFonts.cairo(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _thirtyDayPlan() {
    final today = 15; // mock current day in Ramadan
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151929),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('خطة الـ ٣٠ يوم', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(30, (i) {
              final day = i + 1;
              final isDone = day < today;
              final isToday = day == today;
              return Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDone ? AppColors.lightGreen : isToday ? AppColors.gold : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: isToday ? Border.all(color: AppColors.gold, width: 2) : null,
                ),
                child: Center(
                  child: Text('$day',
                      style: GoogleFonts.cairo(
                          color: isDone || isToday ? Colors.white : Colors.white54,
                          fontSize: 11,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _taraweehCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151929),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🕌 التراويح', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('صليت التراويح الليلة؟', style: GoogleFonts.cairo(color: Colors.white70)),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lightGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('نعم ✓', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: 14 / 30,
            backgroundColor: Colors.white12,
            color: AppColors.gold,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 6),
          Text('١٤ / ٣٠ ليلة', style: GoogleFonts.cairo(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}
