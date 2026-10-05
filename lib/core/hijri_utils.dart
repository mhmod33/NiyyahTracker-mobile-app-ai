/// Gregorian → Hijri conversion (Umm Al-Qura approximation).
class HijriDate {
  final int year;
  final int month;
  final int day;
  const HijriDate(this.year, this.month, this.day);

  static HijriDate fromGregorian(DateTime g) {
    final jd = _toJD(g.year, g.month, g.day);
    final l = jd - 1948440 + 10632;
    final n = ((l - 1) ~/ 10631);
    final l2 = l - 10631 * n + 354;
    final j =
        ((10985 - l2) ~/ 5316) * ((50 * l2) ~/ 17719) +
        (l2 ~/ 5670) * ((43 * l2) ~/ 15238);
    final l3 =
        l2 -
        ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
        (j ~/ 16) * ((15238 * j) ~/ 43) +
        29;
    final month = ((24 * l3) ~/ 709);
    final day = l3 - ((709 * month) ~/ 24);
    final year = 30 * n + j - 30;
    return HijriDate(year.toInt(), month.toInt(), day.toInt());
  }

  /// The "white days" (13th, 14th, 15th of the Hijri month).
  bool get isAyyamBeed => day >= 13 && day <= 15;

  static double _toJD(int y, int m, int d) {
    if (m <= 2) {
      y--;
      m += 12;
    }
    final a = y ~/ 100;
    final b = 2 - a + a ~/ 4;
    return (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        d +
        b -
        1524.5;
  }
}
