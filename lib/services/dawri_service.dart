import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    batch.set(
      _db.collection('dawri_index').doc(supervisorId),
      {'dawriIds': FieldValue.arrayUnion([ref.id])},
      SetOptions(merge: true),
    );
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
    final member = DawriMember(
      userId: userId,
      name: userName,
      joinedAt: now,
    );
    batch.set(memberRef, member.toJson());
    batch.set(
      _db.collection('dawri_index').doc(userId),
      {'dawriIds': FieldValue.arrayUnion([dawri.id])},
      SetOptions(merge: true),
    );
    await batch.commit();
    developer.log('✅ ${userName} joined dawri ${dawri.id}', name: 'DawriService');
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
        _db.collection('dawri').doc(dawriId).collection('members').doc(userId));
    batch.set(
      _db.collection('dawri_index').doc(userId),
      {'dawriIds': FieldValue.arrayRemove([dawriId])},
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// Delete entire league (supervisor only).
  Future<void> deleteDawri(String dawriId) async {
    // Delete all member sub-docs
    final membersSnap =
        await _db.collection('dawri').doc(dawriId).collection('members').get();
    final batch = _db.batch();
    for (final m in membersSnap.docs) {
      batch.delete(m.reference);
    }
    // Delete entries
    final entriesSnap =
        await _db.collection('dawri').doc(dawriId).collection('entries').get();
    for (final e in entriesSnap.docs) {
      batch.delete(e.reference);
    }
    // Delete main doc
    batch.delete(_db.collection('dawri').doc(dawriId));
    await batch.commit();
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Get all leagues the user belongs to (via index doc).
  Future<List<Dawri>> getUserDawriList(String userId) async {
    final indexDoc =
        await _db.collection('dawri_index').doc(userId).get();
    if (!indexDoc.exists) return [];
    final ids = List<String>.from(
        (indexDoc.data()?['dawriIds'] as List?) ?? []);
    if (ids.isEmpty) return [];

    final futures = ids.map((id) => getDawri(id));
    final results = await Future.wait(futures);
    return results.whereType<Dawri>().toList();
  }

  Future<Dawri?> getDawri(String dawriId) async {
    final doc = await _db.collection('dawri').doc(dawriId).get();
    if (!doc.exists) return null;
    final dawri = Dawri.fromJson(doc.data()!, doc.id);
    // Load members
    final membersSnap =
        await _db.collection('dawri').doc(dawriId).collection('members').get();
    final members = membersSnap.docs
        .map((d) => DawriMember.fromJson(d.data()))
        .toList();
    return dawri.copyWith(members: members);
  }

  /// Real-time stream of a single dawri + its members.
  Stream<Dawri?> watchDawri(String dawriId) {
    return _db
        .collection('dawri')
        .doc(dawriId)
        .snapshots()
        .asyncMap((snap) async {
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
    final date = _today();
    final entryId = '${userId}_$date';

    // Calculate points
    int pts = 0;
    for (final status in prayers.values) {
      pts += status.points;
    }
    // Extra points: activityId → count * pointsPerUnit
    for (final entry in extras.entries) {
      final activity = DawriExtraActivity.all
          .firstWhere((a) => a.id == entry.key, orElse: () => const DawriExtraActivity(
              id: '', nameAr: '', description: '', icon: '', pointsPerUnit: 0));
      pts += entry.value * activity.pointsPerUnit;
    }

    final dayEntry = DawriDayEntry(
      date: date,
      prayers: prayers,
      extras: extras,
      totalPoints: pts,
    );

    final batch = _db.batch();
    // Save entry doc
    batch.set(
      _db.collection('dawri').doc(dawriId).collection('entries').doc(entryId),
      dayEntry.toJson(),
    );

    // Update member aggregate
    final memberRef =
        _db.collection('dawri').doc(dawriId).collection('members').doc(userId);
    final memberSnap = await memberRef.get();
    if (memberSnap.exists) {
      final existing = DawriMember.fromJson(memberSnap.data()!);
      // Recalculate today's summary for the member
      final missedToday =
          prayers.values.where((s) => s == PrayerStatus.missed).length;
      final onTimeToday = prayers.values
          .where((s) =>
              s == PrayerStatus.onTime ||
              s == PrayerStatus.congregation ||
              s == PrayerStatus.mosque)
          .length;
      // Recalculate streak (simplified: streak = currentStreak if has entry today)
      final streak = await _computeStreak(dawriId, userId);

      batch.update(memberRef, {
        'todayPrayers': prayers.map((k, v) => MapEntry(k, v.id)),
        'todayExtras': extras,
        'missedToday': missedToday,
        'onTimeToday': onTimeToday,
        'currentStreak': streak,
        'totalPoints': FieldValue.increment(
            pts - (existing.todayPrayers.values.fold(0, (s, v) => s + v.points))),
      });
    }
    await batch.commit();
    developer.log('✅ Saved day entry for $userId in $dawriId', name: 'DawriService');
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
    final entries = <DawriDayEntry>[];
    for (int i = 0; i < 7; i++) {
      final d = weekStart.add(Duration(days: i));
      final date = _dateKey(d);
      final entryId = '${userId}_$date';
      try {
        final doc = await _db
            .collection('dawri')
            .doc(dawriId)
            .collection('entries')
            .doc(entryId)
            .get();
        if (doc.exists) {
          entries.add(DawriDayEntry.fromJson(doc.data()!));
        }
      } catch (_) {}
    }
    return entries;
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

    final List<DawriMemberWeekStats> stats = [];
    for (final member in dawri.members) {
      int pts = 0;
      if (period == 'today') {
        final entry = await getTodayEntry(
            dawriId: dawri.id, userId: member.userId);
        pts = entry?.totalPoints ?? 0;
      } else {
        // Sum over range
        for (int i = 0; i <= rangeEnd.difference(rangeStart).inDays; i++) {
          final d = rangeStart.add(Duration(days: i));
          final entryId = '${member.userId}_${_dateKey(d)}';
          try {
            final doc = await _db
                .collection('dawri')
                .doc(dawri.id)
                .collection('entries')
                .doc(entryId)
                .get();
            if (doc.exists) {
              pts += (doc.data()?['totalPoints'] as int? ?? 0);
            }
          } catch (_) {}
        }
      }
      stats.add(DawriMemberWeekStats(
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
      ));
    }

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
      ranked.add(DawriMemberWeekStats(
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
      ));
    }
    return ranked;
  }

  // ── Invite code management ─────────────────────────────────────────────────

  Future<void> regenerateInviteCode(String dawriId) async {
    final newCode = generateInviteCode();
    await _db
        .collection('dawri')
        .doc(dawriId)
        .update({'inviteCode': newCode});
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
      'trackingMode':
          trackingMode == DawriTrackingMode.custom ? 'custom' : 'basic',
      'selectedActivityIds': selectedActivityIds,
    });
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Compute consecutive-day streak (simplified: count backwards from today).
  Future<int> _computeStreak(String dawriId, String userId) async {
    int streak = 0;
    final now = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final d = now.subtract(Duration(days: i));
      final entryId = '${userId}_${_dateKey(d)}';
      final doc = await _db
          .collection('dawri')
          .doc(dawriId)
          .collection('entries')
          .doc(entryId)
          .get();
      if (doc.exists && (doc.data()?['totalPoints'] as int? ?? 0) > 0) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }
    return streak;
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
  }) =>
      Dawri(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        trackingMode: trackingMode ?? this.trackingMode,
        supervisorId: supervisorId,
        memberIds: memberIds ?? this.memberIds,
        members: members ?? this.members,
        inviteCode: inviteCode ?? this.inviteCode,
        selectedActivityIds:
            selectedActivityIds ?? this.selectedActivityIds,
        createdAt: createdAt,
        startDate: startDate,
        endDate: endDate,
        isActive: isActive ?? this.isActive,
      );
}
