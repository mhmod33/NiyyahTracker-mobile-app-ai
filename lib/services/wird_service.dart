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

  int get pagesPerSession => (targetPages / WirdSession.all.length).ceil();

  bool get isCompleted =>
      pagesRead >= targetPages &&
      WirdSession.all.every((s) => (sessionPages[s] ?? 0) >= pagesPerSession);

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
/// All data is scoped per userId — each account has completely separate records.
class WirdService {
  static final WirdService _instance = WirdService._internal();
  factory WirdService() => _instance;
  WirdService._internal();

  static const String _boxName = 'wird_tracking';
  static const String _settingsBoxName = 'wird_settings';
  static const String _activeSessionKey = 'active_session';
  static const String _sessionStartKey = 'session_start';
  static const String _sessionStartPageKey = 'session_start_page';
  static const String _sessionUserKey = 'session_user';

  Box? _box;
  Box? _settingsBox;
  String _currentUserId = '';

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

  /// Must be called after login/logout to scope data to the correct user.
  void setUserId(String userId) {
    _currentUserId = userId;
    developer.log('👤 WirdService userId set: $userId', name: 'WirdService');
  }

  bool get hasUser => _currentUserId.isNotEmpty;

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

  // ── User-scoped key helpers ───────────────────────────────────────────────

  /// Prefix every storage key with userId so accounts never share data.
  String _userKey(String key) => '${_currentUserId}_$key';

  String _targetPagesKey() => _userKey('target_pages');

  // ── Settings ──────────────────────────────────────────────────────────────

  int get targetPages =>
      _settingsBox?.get(_targetPagesKey(), defaultValue: 20) ?? 20;

  Future<void> setTargetPages(int pages) async {
    await _safeSettings.put(_targetPagesKey(), pages);
  }

  // ── Date helpers ──────────────────────────────────────────────────────────

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String get todayKey => _dateKey(DateTime.now());

  // ── Record access ─────────────────────────────────────────────────────────

  WirdDayRecord? getRecord(String dateKey) {
    if (!hasUser) return null;
    try {
      final raw = _safeBox.get(_userKey(dateKey));
      if (raw == null) return null;
      return WirdDayRecord.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw as String)));
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
    if (!hasUser) return;
    await _safeBox.put(_userKey(record.date), jsonEncode(record.toJson()));
  }

  // ── Session tracking ──────────────────────────────────────────────────────

  /// Called when user enters the Quran reader page.
  Future<void> startReadingSession(int currentPage) async {
    if (!hasUser) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _safeSettings.put(_activeSessionKey, WirdSession.current);
    await _safeSettings.put(_sessionStartKey, now);
    await _safeSettings.put(_sessionStartPageKey, currentPage);
    await _safeSettings.put(_sessionUserKey, _currentUserId);
    developer.log('📖 Wird session started at page $currentPage for user $_currentUserId',
        name: 'WirdService');
  }

  /// Called when user leaves the Quran reader page.
  /// Returns pages credited if session was valid (≥ 1 minute).
  Future<int> endReadingSession(int currentPage) async {
    try {
      final startMs = _settingsBox?.get(_sessionStartKey) as int?;
      final startPage = _settingsBox?.get(_sessionStartPageKey) as int?;
      final session = _settingsBox?.get(_activeSessionKey) as String?;
      final sessionUser = _settingsBox?.get(_sessionUserKey) as String?;

      if (startMs == null || startPage == null || session == null) return 0;

      // Don't credit if session belongs to a different user
      if (sessionUser != null && sessionUser != _currentUserId) {
        await _clearSessionData();
        return 0;
      }

      final durationMs = DateTime.now().millisecondsSinceEpoch - startMs;
      final durationMinutes = durationMs ~/ 60000;

      await _clearSessionData();

      if (durationMinutes < 1) {
        developer.log('⏱️ Session too short (${durationMinutes}min), not credited',
            name: 'WirdService');
        return 0;
      }

      final pagesRead = (currentPage - startPage).abs();
      if (pagesRead <= 0) {
        developer.log('📄 No pages advanced, not credited', name: 'WirdService');
        return 0;
      }

      final today = getTodayRecord();
      final updatedSessionPages = Map<String, int>.from(today.sessionPages);
      updatedSessionPages[session] =
          (updatedSessionPages[session] ?? 0) + pagesRead;

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

  Future<void> _clearSessionData() async {
    await _settingsBox?.delete(_activeSessionKey);
    await _settingsBox?.delete(_sessionStartKey);
    await _settingsBox?.delete(_sessionStartPageKey);
    await _settingsBox?.delete(_sessionUserKey);
  }

  /// Manually add pages (e.g., from a manual input).
  Future<void> addPages(int pages, {String? session}) async {
    if (!hasUser) return;
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

  int getCurrentStreak() {
    if (!hasUser) return 0;
    int streak = 0;
    var date = DateTime.now();

    final todayRecord = getRecord(todayKey);
    if (todayRecord != null && todayRecord.isCompleted) {
      streak = 1;
      date = date.subtract(const Duration(days: 1));
    } else {
      date = date.subtract(const Duration(days: 1));
    }

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

  int getLongestStreak() {
    if (!hasUser) return 0;
    // Only iterate keys that belong to this user
    final prefix = '${_currentUserId}_';
    final keys = _safeBox.keys
        .cast<String>()
        .where((k) => k.startsWith(prefix))
        .map((k) => k.substring(prefix.length))
        .toList()
      ..sort();
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
        current = diff == 1 ? current + 1 : 1;
      }

      if (current > longest) longest = current;
      prevDate = date;
    }

    return longest;
  }

  // ── Statistics ────────────────────────────────────────────────────────────

  Iterable<String> get _userDateKeys {
    if (!hasUser) return [];
    final prefix = '${_currentUserId}_';
    return _safeBox.keys
        .cast<String>()
        .where((k) => k.startsWith(prefix))
        .map((k) => k.substring(prefix.length));
  }

  int getTotalPagesRead() {
    int total = 0;
    for (final key in _userDateKeys) {
      total += getRecord(key)?.pagesRead ?? 0;
    }
    return total;
  }

  int getTotalMinutes() {
    int total = 0;
    for (final key in _userDateKeys) {
      total += getRecord(key)?.totalMinutes ?? 0;
    }
    return total;
  }

  int getTotalCompletedDays() {
    int count = 0;
    for (final key in _userDateKeys) {
      if (getRecord(key)?.isCompleted == true) count++;
    }
    return count;
  }

  List<int> getLastNDayPages(int n) {
    return List.generate(n, (i) {
      final date = DateTime.now().subtract(Duration(days: n - 1 - i));
      return getRecord(_dateKey(date))?.pagesRead ?? 0;
    });
  }

  double getTotalJuzRead() => getTotalPagesRead() / 20.0;
  double getTotalHours() => getTotalMinutes() / 60.0;

  List<WirdDayRecord> getLastNDayRecords(int n) {
    return List.generate(n, (i) {
      final date = DateTime.now().subtract(Duration(days: n - 1 - i));
      final key = _dateKey(date);
      return getRecord(key) ??
          WirdDayRecord(
            date: key,
            pagesRead: 0,
            targetPages: targetPages,
            sessionPages: {},
            totalMinutes: 0,
          );
    });
  }

  bool isSessionDoneToday(String session) {
    if (!hasUser) return false;
    final today = getTodayRecord();
    return (today.sessionPages[session] ?? 0) >= today.pagesPerSession;
  }

  int completedSessionsToday() =>
      WirdSession.all.where(isSessionDoneToday).length;
}
