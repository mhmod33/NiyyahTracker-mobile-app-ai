import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';

class QiblaPage extends StatelessWidget {
  const QiblaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('القبلة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.darkGreen,
          foregroundColor: Colors.white,
        ),
        body: StreamBuilder(
          stream: FlutterQiblah.qiblahStream,
          builder: (context, AsyncSnapshot<QiblahDirection> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('خطأ: ${snapshot.error}', style: GoogleFonts.cairo()));
            }

            final qiblahDirection = snapshot.data!;

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${qiblahDirection.direction.toStringAsFixed(2)}°',
                    style: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 300,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.rotate(
                          angle: (qiblahDirection.direction * (pi / 180) * -1),
                          child: const Icon(Icons.compass_calibration, size: 250, color: Colors.grey),
                        ),
                        Transform.rotate(
                          angle: (qiblahDirection.qiblah * (pi / 180) * -1),
                          child: const Icon(Icons.navigation, size: 150, color: AppColors.darkGreen),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'قم بتوجيه الهاتف نحو الكعبة',
                    style: GoogleFonts.cairo(fontSize: 18, color: AppColors.gray),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
