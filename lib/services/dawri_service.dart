import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/dawri_model.dart';

/// DawriService handles all Firestore operations for the league (دوريات) feature.
///
/// Firestore layout:
///   dawri/{dawriId}               — Dawri metadata
///   dawri/{dawriId}/members/{uid} — per-member aggregated data
///   dawri/{dawriId}/entries/{uid}_{yyyy-MM-dd} — daily prayer/extra entries
///   dawri_index/{uid}             — index doc: list of dawriIds the user belongs to
class DawriService {
  static final DawriService _instance = DawriService._internal();
  factory DawriService() => _instance;
  DawriService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// How far back history is read when recomputing streaks and badges.
  static const int _historyDays = 400;

  /// Firestore batches are limited to 500 operations.
  static const int _maxBatchOps = 450;

  CollectionReference<Map<String, dynamic>> _entriesCol(String dawriId) =>
      _db.collection('dawri').doc(dawriId).collection('entries');

  /// All entries of [userId] between [from] and [to] (inclusive) in one query.
  /// Entry ids are `{uid}_{yyyy-MM-dd}`, so a document-id range selects
  /// exactly that user's days in chronological order.
  Future<List<DawriDayEntry>> _userEntries({
    required String dawriId,
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    final snap = await _entriesCol(dawriId)
        .where(
          FieldPath.documentId,
          isGreaterThanOrEqualTo: '${userId}_${_dateKey(from)}',
        )
        .where(
          FieldPath.documentId,
          isLessThanOrEqualTo: '${userId}_${_dateKey(to)}',
        )
        .get();
    return snap.docs.map((d) => DawriDayEntry.fromJson(d.data())).toList();
  }

  /// Generate a random 8-character uppercase alphanumeric invite code (no ambiguous chars)
  static String generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(8, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  // ── Create / Join / Leave ─────────────────────────────────────────────────

  /// Create a new league. Returns the Dawri with Firestore-assigned id.
  Future<Dawri> createDawri({
    required String supervisorId,
    required String supervisorName,
    required String name,
    String description = '',
    DawriTrackingMode trackingMode = DawriTrackingMode.basic,
    List<String> selectedActivityIds = const [],
  }) async {
    final now = DateTime.now();
    final weekEnd = now.add(const Duration(days: 7));
    final inviteCode = generateInviteCode();
    final ref = _db.collection('dawri').doc();

    final dawri = Dawri(
      id: ref.id,
      name: name,
      description: description,
      trackingMode: trackingMode,
      supervisorId: supervisorId,
      memberIds: [supervisorId],
      inviteCode: inviteCode,
      selectedActivityIds: selectedActivityIds,
      createdAt: now,
      startDate: now,
      endDate: weekEnd,
    );

    final member = DawriMember(
      userId: supervisorId,
      name: supervisorName,
      isSupervisor: true,
      joinedAt: now,
    );

    // Step 1: Write the main dawri doc first so sub-collection rules can
    //         resolve memberIds / supervisorId in subsequent writes.
    await ref.set(dawri.toJson());

    // Step 2: Write member sub-doc + user index in a batch.
    final batch = _db.batch();
    batch.set(ref.collection('members').doc(supervisorId), member.toJson());
    batch.set(_db.collection('dawri_index').doc(supervisorId), {
      'dawriIds': FieldValue.arrayUnion([ref.id]),
    }, SetOptions(merge: true));
    await batch.commit();

    developer.log('✅ Created dawri ${ref.id}', name: 'DawriService');
    return dawri.copyWith(members: [member]);
  }

  /// Join a league by invite code. Returns the Dawri or throws.
  Future<Dawri> joinByCode({
    required String userId,
    required String userName,
    required String code,
  }) async {
    final normalised = code.trim().toUpperCase();
    final query = await _db
        .collection('dawri')
        .where('inviteCode', isEqualTo: normalised)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('رمز الدعوة غير صحيح أو الدوري غير نشط');
    }

    final doc = query.docs.first;
    final dawri = Dawri.fromJson(doc.data(), doc.id);

    if (dawri.memberIds.contains(userId)) {
      throw Exception('أنت بالفعل عضو في هذا الدوري');
    }

    final now = DateTime.now();

    // Step 1: Add userId to memberIds array on the main dawri doc first.
    await doc.reference.update({
      'memberIds': FieldValue.arrayUnion([userId]),
    });

    // Step 2: Write member sub-doc + user index.
    final batch = _db.batch();
    final memberRef = doc.reference.collection('members').doc(userId);
    final member = DawriMember(userId: userId, name: userName, joinedAt: now);
    batch.set(memberRef, member.toJson());
    batch.set(_db.collection('dawri_index').doc(userId), {
      'dawriIds': FieldValue.arrayUnion([dawri.id]),
    }, SetOptions(merge: true));
    await batch.commit();
    developer.log(
      '✅ ${userName} joined dawri ${dawri.id}',
      name: 'DawriService',
    );
    return dawri;
  }

  /// Leave a league (non-supervisor). Supervisor must delete instead.
  Future<void> leaveDawri({
    required String dawriId,
    required String userId,
  }) async {
    final batch = _db.batch();
    batch.update(_db.collection('dawri').doc(dawriId), {
      'memberIds': FieldValue.arrayRemove([userId]),
    });
    batch.delete(
      _db.collection('dawri').doc(dawriId).collection('members').doc(userId),
    );
    batch.set(_db.collection('dawri_index').doc(userId), {
      'dawriIds': FieldValue.arrayRemove([dawriId]),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  /// Delete entire league (supervisor only).
  Future<void> deleteDawri(String dawriId) async {
    final dawriRef = _db.collection('dawri').doc(dawriId);
    final membersSnap = await dawriRef.collection('members').get();
    final entriesSnap = await dawriRef.collection('entries').get();
    final refs = <DocumentReference>[
      ...membersSnap.docs.map((d) => d.reference),
      ...entriesSnap.docs.map((d) => d.reference),
    ];

    // Sub-collections first (in chunks), main doc last so the rules can
    // still resolve supervisorId while the children are deleted.
    for (int i = 0; i < refs.length; i += _maxBatchOps) {
      final batch = _db.batch();
      for (final ref in refs.skip(i).take(_maxBatchOps)) {
        batch.delete(ref);
      }
      await batch.commit();
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final batch = _db.batch();
    batch.delete(dawriRef);
    if (uid != null) {
      batch.set(_db.collection('dawri_index').doc(uid), {
        'dawriIds': FieldValue.arrayRemove([dawriId]),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Get all leagues the user belongs to (via index doc).
  Future<List<Dawri>> getUserDawriList(String userId) async {
    final indexDoc = await _db.collection('dawri_index').doc(userId).get();
    if (!indexDoc.exists) return [];
    final ids = List<String>.from(
      (indexDoc.data()?['dawriIds'] as List?) ?? [],
    );
    if (ids.isEmpty) return [];

    final results = await Future.wait(
      ids.map((id) async {
        try {
          return await getDawri(id);
        } catch (_) {
          return null;
        }
      }),
    );

    // Drop ids of leagues that were deleted (or that we were removed from).
    final stale = <String>[
      for (int i = 0; i < ids.length; i++)
        if (results[i] == null || !results[i]!.memberIds.contains(userId))
          ids[i],
    ];
    if (stale.isNotEmpty) {
      try {
        await _db.collection('dawri_index').doc(userId).set({
          'dawriIds': FieldValue.arrayRemove(stale),
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    return results
        .whereType<Dawri>()
        .where((d) => d.memberIds.contains(userId))
        .toList();
  }

  Future<Dawri?> getDawri(String dawriId) async {
    final doc = await _db.collection('dawri').doc(dawriId).get();
    if (!doc.exists) return null;
    final dawri = Dawri.fromJson(doc.data()!, doc.id);
    // Load members
    final membersSnap = await _db
        .collection('dawri')
        .doc(dawriId)
        .collection('members')
        .get();
    final members = membersSnap.docs
        .map((d) => DawriMember.fromJson(d.data()))
        .toList();
    return (await _rollCycleIfNeeded(dawri)).copyWith(members: members);
  }

  /// Leagues renew weekly. When the stored cycle has ended, move it forward;
  /// only the supervisor is allowed to persist the new dates.
  Future<Dawri> _rollCycleIfNeeded(Dawri dawri) async {
    final now = DateTime.now();
    if (dawri.endDate.isAfter(now)) return dawri;
    final end = dawri.currentCycleEnd(now);
    final start = dawri.currentCycleStart(now);
    if (FirebaseAuth.instance.currentUser?.uid == dawri.supervisorId) {
      try {
        await _db.collection('dawri').doc(dawri.id).update({
          'startDate': Timestamp.fromDate(start),
          'endDate': Timestamp.fromDate(end),
        });
      } catch (e) {
        developer.log(
          '⚠️ Could not roll dawri cycle: $e',
          name: 'DawriService',
        );
      }
    }
    return dawri.copyWith(startDate: start, endDate: end);
  }

  /// Real-time stream of a single dawri + its members.
  Stream<Dawri?> watchDawri(String dawriId) {
    return _db.collection('dawri').doc(dawriId).snapshots().asyncMap((
      snap,
    ) async {
      if (!snap.exists) return null;
      final dawri = Dawri.fromJson(snap.data()!, snap.id);
      final membersSnap = await _db
          .collection('dawri')
          .doc(dawriId)
          .collection('members')
          .get();
      final members = membersSnap.docs
          .map((d) => DawriMember.fromJson(d.data()))
          .toList();
      return dawri.copyWith(members: members);
    });
  }

  // ── Daily Entry ───────────────────────────────────────────────────────────

  /// Save/update today's prayer log for a user in a league.
  Future<void> saveDayEntry({
    required String dawriId,
    required String userId,
    required Map<String, PrayerStatus> prayers,
    Map<String, int> extras = const {},
  }) async {
    final now = DateTime.now();
    final date = _today();
    final entryId = '${userId}_$date';

    final pts = calculatePoints(prayers, extras);
    final dayEntry = DawriDayEntry(
      date: date,
      prayers: prayers,
      extras: extras,
      totalPoints: pts,
    );

    // History (one query) — used for the points delta, streak and badges.
    final history = await _userEntries(
      dawriId: dawriId,
      userId: userId,
      from: now.subtract(const Duration(days: _historyDays)),
      to: now,
    );
    final previousToday = history.where((e) => e.date == date).firstOrNull;
    final byDate = {for (final e in history) e.date: e, date: dayEntry};

    final memberRef = _db
        .collection('dawri')
        .doc(dawriId)
        .collection('members')
        .doc(userId);
    final memberSnap = await memberRef.get();
    final existingBadges = memberSnap.exists
        ? DawriMember.fromJson(memberSnap.data()!).badges
        : const <String>[];

    final missedToday = prayers.values
        .where((s) => s == PrayerStatus.missed)
        .length;
    final onTimeToday = prayers.values
        .where(
          (s) =>
              s == PrayerStatus.onTime ||
              s == PrayerStatus.congregation ||
              s == PrayerStatus.mosque,
        )
        .length;

    final batch = _db.batch();
    batch.set(_entriesCol(dawriId).doc(entryId), dayEntry.toJson());
    batch.set(memberRef, {
      'userId': userId,
      'todayDate': date,
      'todayPrayers': prayers.map((k, v) => MapEntry(k, v.id)),
      'todayExtras': extras,
      'missedToday': missedToday,
      'onTimeToday': onTimeToday,
      'currentStreak': _currentStreak(byDate, now),
      'badges': computeLeagueBadges(byDate.values, existing: existingBadges),
      // Only add the difference vs. what was already saved for today.
      'totalPoints': FieldValue.increment(
        pts - (previousToday?.totalPoints ?? 0),
      ),
    }, SetOptions(merge: true));
    await batch.commit();
    developer.log(
      '✅ Saved day entry for $userId in $dawriId',
      name: 'DawriService',
    );
  }

  static int calculatePoints(
    Map<String, PrayerStatus> prayers,
    Map<String, int> extras,
  ) {
    int pts = 0;
    for (final status in prayers.values) {
      pts += status.points;
    }
    for (final entry in extras.entries) {
      for (final a in DawriExtraActivity.all) {
        if (a.id == entry.key) pts += entry.value * a.pointsPerUnit;
      }
    }
    return pts;
  }

  /// Get today's entry for a user in a league.
  Future<DawriDayEntry?> getTodayEntry({
    required String dawriId,
    required String userId,
  }) async {
    final date = _today();
    final entryId = '${userId}_$date';
    final doc = await _db
        .collection('dawri')
        .doc(dawriId)
        .collection('entries')
        .doc(entryId)
        .get();
    if (!doc.exists) return null;
    return DawriDayEntry.fromJson(doc.data()!);
  }

  /// Get entries for a user in the current week.
  Future<List<DawriDayEntry>> getWeekEntries({
    required String dawriId,
    required String userId,
    required DateTime weekStart,
  }) async {
    try {
      return await _userEntries(
        dawriId: dawriId,
        userId: userId,
        from: weekStart,
        to: weekStart.add(const Duration(days: 6)),
      );
    } catch (_) {
      return [];
    }
  }

  // ── Leaderboard ───────────────────────────────────────────────────────────

  /// Build leaderboard for today / this week / this month.
  Future<List<DawriMemberWeekStats>> getLeaderboard({
    required Dawri dawri,
    String period = 'today', // 'today' | 'week' | 'month'
  }) async {
    final now = DateTime.now();
    final DateTime rangeStart;
    final DateTime rangeEnd = DateTime(now.year, now.month, now.day, 23, 59);
    switch (period) {
      case 'week':
        rangeStart = now.subtract(Duration(days: now.weekday - 1));
        break;
      case 'month':
        rangeStart = DateTime(now.year, now.month, 1);
        break;
      default:
        rangeStart = DateTime(now.year, now.month, now.day);
    }

    // One range query per member, all members in parallel.
    final stats = await Future.wait(
      dawri.members.map((member) async {
        int pts = 0;
        try {
          final entries = await _userEntries(
            dawriId: dawri.id,
            userId: member.userId,
            from: rangeStart,
            to: rangeEnd,
          );
          for (final e in entries) {
            pts += e.totalPoints;
          }
        } catch (_) {}
        return DawriMemberWeekStats(
          userId: member.userId,
          name: member.name,
          rank: 0,
          weekPoints: pts,
          totalPoints: member.totalPoints,
          streak: member.currentStreak,
          missedCount: member.missedToday,
          onTimeCount: member.onTimeToday,
          todayPrayers: member.todayPrayers,
          todayExtras: member.todayExtras,
          isSupervisor: member.isSupervisor,
          badges: member.badges,
        );
      }),
    );

    // Sort by weekPoints descending, then totalPoints
    stats.sort((a, b) {
      if (b.weekPoints != a.weekPoints) {
        return b.weekPoints.compareTo(a.weekPoints);
      }
      return b.totalPoints.compareTo(a.totalPoints);
    });

    // Assign ranks
    final ranked = <DawriMemberWeekStats>[];
    for (int i = 0; i < stats.length; i++) {
      final s = stats[i];
      ranked.add(
        DawriMemberWeekStats(
          userId: s.userId,
          name: s.name,
          rank: i + 1,
          weekPoints: s.weekPoints,
          totalPoints: s.totalPoints,
          streak: s.streak,
          missedCount: s.missedCount,
          onTimeCount: s.onTimeCount,
          todayPrayers: s.todayPrayers,
          todayExtras: s.todayExtras,
          isSupervisor: s.isSupervisor,
          badges: s.badges,
        ),
      );
    }
    return ranked;
  }

  // ── Invite code management ─────────────────────────────────────────────────

  Future<void> regenerateInviteCode(String dawriId) async {
    final newCode = generateInviteCode();
    await _db.collection('dawri').doc(dawriId).update({'inviteCode': newCode});
  }

  // ── Settings update ────────────────────────────────────────────────────────

  Future<void> updateDawriSettings({
    required String dawriId,
    required String name,
    String description = '',
    DawriTrackingMode trackingMode = DawriTrackingMode.basic,
    List<String> selectedActivityIds = const [],
  }) async {
    await _db.collection('dawri').doc(dawriId).update({
      'name': name,
      'description': description,
      'trackingMode': trackingMode == DawriTrackingMode.custom
          ? 'custom'
          : 'basic',
      'selectedActivityIds': selectedActivityIds,
    });
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Consecutive days with points, ending today — or yesterday when today
  /// hasn't been logged yet, so the streak doesn't drop before you log.
  int _currentStreak(Map<String, DawriDayEntry> byDate, DateTime now) {
    bool active(DateTime d) => (byDate[_dateKey(d)]?.totalPoints ?? 0) > 0;
    var day = DateTime(now.year, now.month, now.day);
    if (!active(day)) day = day.subtract(const Duration(days: 1));
    int streak = 0;
    while (active(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// League badges (ids match `member_profile_sheet.dart`). Badges already
  /// earned are kept even if the history window no longer contains them.
  static List<String> computeLeagueBadges(
    Iterable<DawriDayEntry> entries, {
    List<String> existing = const [],
  }) {
    final earned = <String>{...existing};
    int mosquePrayers = 0;
    final activeDays = <String>{};
    final quranDays = <String>{};
    final azkarDays = <String>{};

    for (final e in entries) {
      if (e.prayers[DawriPrayer.fajr] == PrayerStatus.mosque) {
        earned.add('mosque_fajr');
      }
      mosquePrayers += e.prayers.values
          .where((s) => s == PrayerStatus.mosque)
          .length;
      if (e.totalPoints > 0) activeDays.add(e.date);
      if ((e.extras[DawriExtraActivity.quranReading.id] ?? 0) > 0) {
        quranDays.add(e.date);
      }
      if ((e.extras[DawriExtraActivity.azkar.id] ?? 0) > 0) {
        azkarDays.add(e.date);
      }
    }

    if (mosquePrayers >= 40) earned.add('mosque_steps');
    final longestActive = _longestRun(activeDays);
    if (longestActive >= 7) earned.add('streak_7');
    if (longestActive >= 30) earned.add('streak_30');
    if (_longestRun(quranDays) >= 7) earned.add('quran_week');
    if (_longestRun(azkarDays) >= 7) earned.add('azkar_week');
    return earned.toList();
  }

  static int _longestRun(Set<String> dateKeys) {
    final days =
        dateKeys
            .map(DateTime.tryParse)
            .whereType<DateTime>()
            .map((d) => DateTime.utc(d.year, d.month, d.day))
            .toList()
          ..sort();
    int best = 0, run = 0;
    DateTime? prev;
    for (final d in days) {
      run = (prev != null && d.difference(prev).inDays == 1) ? run + 1 : 1;
      if (run > best) best = run;
      prev = d;
    }
    return best;
  }
}

// Extension to support copyWith for Dawri
extension DawriCopyWith on Dawri {
  Dawri copyWith({
    List<DawriMember>? members,
    String? name,
    String? description,
    bool? isActive,
    String? inviteCode,
    DawriTrackingMode? trackingMode,
    List<String>? selectedActivityIds,
    List<String>? memberIds,
    DateTime? startDate,
    DateTime? endDate,
  }) => Dawri(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    trackingMode: trackingMode ?? this.trackingMode,
    supervisorId: supervisorId,
    memberIds: memberIds ?? this.memberIds,
    members: members ?? this.members,
    inviteCode: inviteCode ?? this.inviteCode,
    selectedActivityIds: selectedActivityIds ?? this.selectedActivityIds,
    createdAt: createdAt,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    isActive: isActive ?? this.isActive,
  );
}
