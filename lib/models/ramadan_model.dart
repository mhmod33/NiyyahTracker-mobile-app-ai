import 'package:cloud_firestore/cloud_firestore.dart';

class RamadanTracking {
  final String id;
  final String userId;
  final int currentDay;
  final int totalDays;
  final int quranPagesTarget;
  final int quranPagesCompleted;
  final List<RamadanDayRecord> dayRecords;
  final bool isLaylalQadrMarked;
  final DateTime laylalQadrDate;

  RamadanTracking({
    required this.id,
    required this.userId,
    this.currentDay = 1,
    this.totalDays = 30,
    this.quranPagesTarget = 0,
    this.quranPagesCompleted = 0,
    this.dayRecords = const [],
    this.isLaylalQadrMarked = false,
    required this.laylalQadrDate,
  });

  double get quranProgress => quranPagesTarget > 0 ? quranPagesCompleted / quranPagesTarget : 0;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'currentDay': currentDay,
      'totalDays': totalDays,
      'quranPagesTarget': quranPagesTarget,
      'quranPagesCompleted': quranPagesCompleted,
      'dayRecords': dayRecords.map((record) => record.toMap()).toList(),
      'isLaylalQadrMarked': isLaylalQadrMarked,
      'laylalQadrDate': Timestamp.fromDate(laylalQadrDate),
    };
  }

  factory RamadanTracking.fromMap(Map<String, dynamic> map, String docId) {
    return RamadanTracking(
      id: docId,
      userId: map['userId'] ?? '',
      currentDay: map['currentDay'] ?? 1,
      totalDays: map['totalDays'] ?? 30,
      quranPagesTarget: map['quranPagesTarget'] ?? 0,
      quranPagesCompleted: map['quranPagesCompleted'] ?? 0,
      dayRecords: (map['dayRecords'] as List<dynamic>?)
          ?.map((record) => RamadanDayRecord.fromMap(record as Map<String, dynamic>))
          .toList() ?? [],
      isLaylalQadrMarked: map['isLaylalQadrMarked'] ?? false,
      laylalQadrDate: (map['laylalQadrDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class RamadanDayRecord {
  final int dayNumber;
  final DateTime date;
  final bool suhoorRecorded;
  final bool iftarRecorded;
  final bool taraweehCompleted;
  final int quranPagesRead;
  final String notes;

  RamadanDayRecord({
    required this.dayNumber,
    required this.date,
    this.suhoorRecorded = false,
    this.iftarRecorded = false,
    this.taraweehCompleted = false,
    this.quranPagesRead = 0,
    this.notes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'dayNumber': dayNumber,
      'date': Timestamp.fromDate(date),
      'suhoorRecorded': suhoorRecorded,
      'iftarRecorded': iftarRecorded,
      'taraweehCompleted': taraweehCompleted,
      'quranPagesRead': quranPagesRead,
      'notes': notes,
    };
  }

  factory RamadanDayRecord.fromMap(Map<String, dynamic> map) {
    return RamadanDayRecord(
      dayNumber: map['dayNumber'] ?? 0,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      suhoorRecorded: map['suhoorRecorded'] ?? false,
      iftarRecorded: map['iftarRecorded'] ?? false,
      taraweehCompleted: map['taraweehCompleted'] ?? false,
      quranPagesRead: map['quranPagesRead'] ?? 0,
      notes: map['notes'] ?? '',
    );
  }

  RamadanDayRecord copyWith({
    bool? suhoorRecorded,
    bool? iftarRecorded,
    bool? taraweehCompleted,
    int? quranPagesRead,
    String? notes,
  }) {
    return RamadanDayRecord(
      dayNumber: dayNumber,
      date: date,
      suhoorRecorded: suhoorRecorded ?? this.suhoorRecorded,
      iftarRecorded: iftarRecorded ?? this.iftarRecorded,
      taraweehCompleted: taraweehCompleted ?? this.taraweehCompleted,
      quranPagesRead: quranPagesRead ?? this.quranPagesRead,
      notes: notes ?? this.notes,
    );
  }
}
