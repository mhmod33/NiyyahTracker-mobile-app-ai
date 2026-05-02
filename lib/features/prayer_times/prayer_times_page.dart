import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart' as intl;
import '../../core/app_colors.dart';

class PrayerTimesPage extends StatefulWidget {
  const PrayerTimesPage({super.key});

  @override
  State<PrayerTimesPage> createState() => _PrayerTimesPageState();
}

class _PrayerTimesPageState extends State<PrayerTimesPage> {
  PrayerTimes? _prayerTimes;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPrayerTimes();
  }

  Future<void> _fetchPrayerTimes() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));
      
      final coordinates = Coordinates(position.latitude, position.longitude);
      final params = CalculationMethod.egyptian.getParameters();
      params.madhab = Madhab.shafi;
      
      final date = DateComponents.from(DateTime.now());
      final prayerTimes = PrayerTimes(coordinates, date, params);

      setState(() {
        _prayerTimes = prayerTimes;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'تعذر الحصول على أوقات الصلاة: $e';
        _loading = false;
      });
    }
  }

  String _formatTime(DateTime time) {
    return intl.DateFormat.jm('ar_SA').format(time);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('أوقات الصلاة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.darkGreen,
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildPrayerTile('الفجر', _prayerTimes!.fajr),
                        _buildPrayerTile('الشروق', _prayerTimes!.sunrise),
                        _buildPrayerTile('الظهر', _prayerTimes!.dhuhr),
                        _buildPrayerTile('العصر', _prayerTimes!.asr),
                        _buildPrayerTile('المغرب', _prayerTimes!.maghrib),
                        _buildPrayerTile('العشاء', _prayerTimes!.isha),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildPrayerTile(String name, DateTime time) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(name, style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
        trailing: Text(_formatTime(time), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.darkGreen)),
      ),
    );
  }
}
