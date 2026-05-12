import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/app_colors.dart';

/// Represents a single day's wird reading record.
class WirdDayRecord {
  final String date; // 'yyyy-MM-dd'
  final int pagesRead;
  final int targetPages;
  final Map<String, int> sessionPages; // session key -> pages read in that session
  final int totalMinutes; // total minutes spent reading

  const WirdDayRecord({
    required this.date,
    required this.pagesRead,
    required this.targetPages,
    required this.sessionPages,
    required this.totalMinutes,
  });

  bool get isCompleted => pagesRead >= targetPages;

  double get progress => targetPages > 0 ? (pagesRead / targetPages).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toJson() => {
        'date': date,
        'pagesRead': pagesRead,
        'targetPages': targetPages,
        'sessionPages': sessionPages,
        'totalMinutes': totalMinutes,
      };

  factory WirdDayRecord.fromJson(Map<String, dynamic> json) => WirdDayRecord(
        date: json['date'] as String,
        pagesRead: json['pagesRead'] as int? ?? 0,
        targetPages: json['targetPages'] as int? ?? 20,
        sessionPages: Map<String, int>.from(json['sessionPages'] as Map? ?? {}),
        totalMinutes: json['totalMinutes'] as int? ?? 0,
      );

  WirdDayRecord copyWith({
    int? pagesRead,
    int? targetPages,
    Map<String, int>? sessionPages,
    int? totalMinutes,
  }) =>
      WirdDayRecord(
        date: date,
        pagesRead: pagesRead ?? this.pagesRead,
        targetPages: targetPages ?? this.targetPages,
        sessionPages: sessionPages ?? this.sessionPages,
        totalMinutes: totalMinutes ?? this.totalMinutes,
      );
}

/// Wird session keys — one per prayer time slot.
class WirdSession {
  static const String fajr = 'fajr';
  static const String dhuhr = 'dhuhr';
  static const String asr = 'asr';
  static const String isha = 'isha';

  static const List<String> all = [fajr, dhuhr, asr, isha];

  static String get current {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 12) return fajr;
    if (hour >= 12 && hour < 15) return dhuhr;
    if (hour >= 15 && hour < 20) return asr;
    return isha;
  }

  static String label(String session) {
    switch (session) {
      case fajr:
        return 'الصبح';
      case dhuhr:
        return 'الظهر';
      case asr:
        return 'العصر';
      case isha:
        return 'العشاء';
      default:
        return session;
    }
  }

  static IconData iconData(String session) {
    switch (session) {
      case fajr:
        return Icons.wb_twilight_rounded;
      case dhuhr:
        return Icons.wb_sunny_rounded;
      case asr:
        return Icons.light_mode_rounded;
      case isha:
        return Icons.nights_stay_rounded;
      default:
        return Icons.menu_book_rounded;
    }
  }

  static Color iconColor(String session) {
    switch (session) {
      case fajr:
        return const Color(0xFFFF8C42);
      case dhuhr:
        return const Color(0xFFFFD700);
      case asr:
        return const Color(0xFF4FC3F7);
      case isha:
        return const Color(0xFF9575CD);
      default:
        return AppColors.darkGreen;
    }
  }
}

/// Service that manages daily wird tracking, streak calculation, and statistics.
class WirdService {
  static final WirdService _instance = WirdService._internal();
  factory WirdService() => _instance;
  WirdService._internal();

  static const String _boxName = 'wird_tracking';
  static const String _settingsBoxName = 'wird_settings';
  static const String _targetPagesKey = 'target_pages';
  static const String _activeSessionKey = 'active_session';
  static const String _sessionStartKey = 'session_start';
  static const String _sessionStartPageKey = 'session_start_page';

  Box? _box;
  Box? _settingsBox;

  Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox(_boxName);
      } else {
        _box = Hive.box(_boxName);
      }
      if (!Hive.isBoxOpen(_settingsBoxName)) {
        _settingsBox = await Hive.openBox(_settingsBoxName);
      } else {
        _settingsBox = Hive.box(_settingsBoxName);
      }
      developer.log('✅ WirdService initialized', name: 'WirdService');
    } catch (e) {
      developer.log('❌ WirdService init error: $e', name: 'WirdService');
    }
  }

  Box get _safeBox {
    if (_box == null || !_box!.isOpen) throw Exception('WirdService not initialized');
    return _box!;
  }

  Box get _safeSettings {
    if (_settingsBox == null || !_settingsBox!.isOpen) {
      throw Exception('WirdService settings not initialized');
    }
    return _settingsBox!;
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  int get targetPages => _settingsBox?.get(_targetPagesKey, defaultValue: 20) ?? 20;

  Future<void> setTargetPages(int pages) async {
    await _safeSettings.put(_targetPagesKey, pages);
  }

  // ── Date helpers ──────────────────────────────────────────────────────────

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String get todayKey => _dateKey(DateTime.now());

  // ── Record access ─────────────────────────────────────────────────────────

  WirdDayRecord? getRecord(String dateKey) {
    try {
      final raw = _safeBox.get(dateKey);
      if (raw == null) return null;
      return WirdDayRecord.fromJson(Map<String, dynamic>.from(jsonDecode(raw as String)));
    } catch (e) {
      developer.log('❌ getRecord error: $e', name: 'WirdService');
      return null;
    }
  }

  WirdDayRecord getTodayRecord() {
    return getRecord(todayKey) ??
        WirdDayRecord(
          date: todayKey,
          pagesRead: 0,
          targetPages: targetPages,
          sessionPages: {},
          totalMinutes: 0,
        );
  }

  Future<void> _saveRecord(WirdDayRecord record) async {
    await _safeBox.put(record.date, jsonEncode(record.toJson()));
  }

  // ── Session tracking ──────────────────────────────────────────────────────

  /// Called when user enters the Quran reader page.
  Future<void> startReadingSession(int currentPage) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _safeSettings.put(_activeSessionKey, WirdSession.current);
    await _safeSettings.put(_sessionStartKey, now);
    await _safeSettings.put(_sessionStartPageKey, currentPage);
    developer.log('📖 Wird session started at page $currentPage', name: 'WirdService');
  }

  /// Called when user leaves the Quran reader page.
  /// Returns pages credited if session was valid (≥ 1 minute).
  Future<int> endReadingSession(int currentPage) async {
    try {
      final startMs = _settingsBox?.get(_sessionStartKey) as int?;
      final startPage = _settingsBox?.get(_sessionStartPageKey) as int?;
      final session = _settingsBox?.get(_activeSessionKey) as String?;

      if (startMs == null || startPage == null || session == null) return 0;

      final durationMs = DateTime.now().millisecondsSinceEpoch - startMs;
      final durationMinutes = durationMs ~/ 60000;

      // Clear session data
      await _settingsBox?.delete(_activeSessionKey);
      await _settingsBox?.delete(_sessionStartKey);
      await _settingsBox?.delete(_sessionStartPageKey);

      // Only credit if user spent at least 1 minute
      if (durationMinutes < 1) {
        developer.log('⏱️ Session too short (${durationMinutes}min), not credited', name: 'WirdService');
        return 0;
      }

      // Pages moved forward = pages read
      final pagesRead = (currentPage - startPage).abs();
      if (pagesRead <= 0) {
        developer.log('📄 No pages advanced, not credited', name: 'WirdService');
        return 0;
      }

      // Update today's record
      final today = getTodayRecord();
      final updatedSessionPages = Map<String, int>.from(today.sessionPages);
      updatedSessionPages[session] = (updatedSessionPages[session] ?? 0) + pagesRead;

      final updated = today.copyWith(
        pagesRead: today.pagesRead + pagesRead,
        sessionPages: updatedSessionPages,
        totalMinutes: today.totalMinutes + durationMinutes,
      );

      await _saveRecord(updated);
      developer.log(
          '✅ Wird session ended: +$pagesRead pages, ${durationMinutes}min, session=$session',
          name: 'WirdService');
      return pagesRead;
    } catch (e) {
      developer.log('❌ endReadingSession error: $e', name: 'WirdService');
      return 0;
    }
  }

  /// Manually add pages (e.g., from a manual input).
  Future<void> addPages(int pages, {String? session}) async {
    final today = getTodayRecord();
    final s = session ?? WirdSession.current;
    final updatedSessionPages = Map<String, int>.from(today.sessionPages);
    updatedSessionPages[s] = (updatedSessionPages[s] ?? 0) + pages;

    final updated = today.copyWith(
      pagesRead: today.pagesRead + pages,
      sessionPages: updatedSessionPages,
    );
    await _saveRecord(updated);
  }

  // ── Streak calculation ────────────────────────────────────────────────────

  /// Returns the current consecutive-day streak.
  int getCurrentStreak() {
    int streak = 0;
    var date = DateTime.now();

    // Check today first — if today is complete, count it
    // If today is not complete yet, start checking from yesterday
    final todayRecord = getRecord(todayKey);
    if (todayRecord != null && todayRecord.isCompleted) {
      streak = 1;
      date = date.subtract(const Duration(days: 1));
    } else {
      // Today not complete — check if yesterday was complete to show streak
      date = date.subtract(const Duration(days: 1));
    }

    // Walk backwards
    for (int i = 0; i < 365; i++) {
      final key = _dateKey(date);
      final record = getRecord(key);
      if (record != null && record.isCompleted) {
        streak++;
        date = date.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  /// Returns the longest streak ever.
  int getLongestStreak() {
    final keys = _safeBox.keys.cast<String>().toList()..sort();
    if (keys.isEmpty) return 0;

    int longest = 0;
    int current = 0;
    DateTime? prevDate;

    for (final key in keys) {
      final record = getRecord(key);
      if (record == null || !record.isCompleted) {
        current = 0;
        prevDate = null;
        continue;
      }

      final date = DateTime.tryParse(key);
      if (date == null) continue;

      if (prevDate == null) {
        current = 1;
      } else {
        final diff = date.difference(prevDate).inDays;
        if (diff == 1) {
          current++;
        } else {
          current = 1;
        }
      }

      if (current > longest) longest = current;
      prevDate = date;
    }

    return longest;
  }

  // ── Statistics ────────────────────────────────────────────────────────────

  /// Total pages read across all time.
  int getTotalPagesRead() {
    int total = 0;
    for (final key in _safeBox.keys) {
      final record = getRecord(key as String);
      if (record != null) total += record.pagesRead;
    }
    return total;
  }

  /// Total minutes spent reading.
  int getTotalMinutes() {
    int total = 0;
    for (final key in _safeBox.keys) {
      final record = getRecord(key as String);
      if (record != null) total += record.totalMinutes;
    }
    return total;
  }

  /// Total completed days.
  int getTotalCompletedDays() {
    int count = 0;
    for (final key in _safeBox.keys) {
      final record = getRecord(key as String);
      if (record != null && record.isCompleted) count++;
    }
    return count;
  }

  /// Pages read in the last N days (for chart).
  List<int> getLastNDayPages(int n) {
    final result = <int>[];
    for (int i = n - 1; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final record = getRecord(_dateKey(date));
      result.add(record?.pagesRead ?? 0);
    }
    return result;
  }

  /// Total Quran parts (أجزاء) read — 1 juz = 20 pages.
  double getTotalJuzRead() => getTotalPagesRead() / 20.0;

  /// Total hours spent reading.
  double getTotalHours() => getTotalMinutes() / 60.0;

  /// Returns records for the last N days.
  List<WirdDayRecord> getLastNDayRecords(int n) {
    final result = <WirdDayRecord>[];
    for (int i = n - 1; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final key = _dateKey(date);
      result.add(
        getRecord(key) ??
            WirdDayRecord(
              date: key,
              pagesRead: 0,
              targetPages: targetPages,
              sessionPages: {},
              totalMinutes: 0,
            ),
      );
    }
    return result;
  }

  /// Check if a specific session has been completed today.
  bool isSessionDoneToday(String session) {
    final today = getTodayRecord();
    final sessionPages = today.sessionPages[session] ?? 0;
    return sessionPages >= 5; // 5 pages per session = done
  }

  /// How many sessions are done today.
  int completedSessionsToday() {
    return WirdSession.all.where(isSessionDoneToday).length;
  }
}
