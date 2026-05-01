import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HajjTracking {
  final String id;
  final String userId;
  final bool isInHajjMode;
  final int currentDayOfHajj;
  final int totalDays;
  final List<HajjPillar> pillars;
  final List<SupplicationRecord> supplications;
  final DateTime startDate;

  HajjTracking({
    required this.id,
    required this.userId,
    this.isInHajjMode = false,
    this.currentDayOfHajj = 0,
    this.totalDays = 5,
    this.pillars = const [],
    this.supplications = const [],
    required this.startDate,
  });

  int get completedPillars => pillars.where((p) => p.isCompleted).length;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'isInHajjMode': isInHajjMode,
      'currentDayOfHajj': currentDayOfHajj,
      'totalDays': totalDays,
      'pillars': pillars.map((p) => p.toMap()).toList(),
      'supplications': supplications.map((s) => s.toMap()).toList(),
      'startDate': Timestamp.fromDate(startDate),
    };
  }

  factory HajjTracking.fromMap(Map<String, dynamic> map, String docId) {
    return HajjTracking(
      id: docId,
      userId: map['userId'] ?? '',
      isInHajjMode: map['isInHajjMode'] ?? false,
      currentDayOfHajj: map['currentDayOfHajj'] ?? 0,
      totalDays: map['totalDays'] ?? 5,
      pillars: (map['pillars'] as List<dynamic>?)
          ?.map((p) => HajjPillar.fromMap(p as Map<String, dynamic>))
          .toList() ?? [],
      supplications: (map['supplications'] as List<dynamic>?)
          ?.map((s) => SupplicationRecord.fromMap(s as Map<String, dynamic>))
          .toList() ?? [],
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class HajjPillar {
  final String name;
  final String description;
  final String location;
  final LatLng coordinates;
  final bool isCompleted;
  final int dayNumber;

  const HajjPillar({
    required this.name,
    required this.description,
    required this.location,
    required this.coordinates,
    this.isCompleted = false,
    required this.dayNumber,
  });

  static final List<HajjPillar> defaultPillars = [
    HajjPillar(
      name: 'الإحرام والتلبية',
      description: 'الإحرام من الميقات والتلبية',
      location: 'الميقات',
      coordinates: LatLng(21.4225, 39.8262),
      dayNumber: 1,
    ),
    HajjPillar(
      name: 'الطواف حول الكعبة',
      description: 'طواف القدوم سبع مرات',
      location: 'الكعبة المشرفة',
      coordinates: LatLng(21.4224, 39.8262),
      dayNumber: 1,
    ),
    HajjPillar(
      name: 'السعي بين الصفا والمروة',
      description: 'السعي بين الصفا والمروة سبع مرات',
      location: 'الصفا والمروة',
      coordinates: LatLng(21.4224, 39.8269),
      dayNumber: 2,
    ),
    HajjPillar(
      name: 'الوقوف بعرفة',
      description: 'الوقوف بجبل عرفة من الزوال إلى الغروب',
      location: 'جبل عرفة',
      coordinates: LatLng(21.3585, 39.9767),
      dayNumber: 3,
    ),
    HajjPillar(
      name: 'المزدلفة',
      description: 'البيتوتة بالمزدلفة والمبيت بها',
      location: 'المزدلفة',
      coordinates: LatLng(21.3376, 39.9521),
      dayNumber: 3,
    ),
  ];

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'location': location,
      'coordinates': {'latitude': coordinates.latitude, 'longitude': coordinates.longitude},
      'isCompleted': isCompleted,
      'dayNumber': dayNumber,
    };
  }

  factory HajjPillar.fromMap(Map<String, dynamic> map) {
    final coords = map['coordinates'] as Map<String, dynamic>?;
    return HajjPillar(
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      location: map['location'] ?? '',
      coordinates: LatLng(
        coords?['latitude'] as double? ?? 0,
        coords?['longitude'] as double? ?? 0,
      ),
      isCompleted: map['isCompleted'] ?? false,
      dayNumber: map['dayNumber'] ?? 0,
    );
  }

  HajjPillar copyWith({bool? isCompleted}) {
    return HajjPillar(
      name: name,
      description: description,
      location: location,
      coordinates: coordinates,
      isCompleted: isCompleted ?? this.isCompleted,
      dayNumber: dayNumber,
    );
  }
}

class SupplicationRecord {
  final String id;
  final String supplication;
  final String location;
  final DateTime recordedAt;
  final String audioPath;

  SupplicationRecord({
    required this.id,
    required this.supplication,
    required this.location,
    required this.recordedAt,
    this.audioPath = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplication': supplication,
      'location': location,
      'recordedAt': Timestamp.fromDate(recordedAt),
      'audioPath': audioPath,
    };
  }

  factory SupplicationRecord.fromMap(Map<String, dynamic> map) {
    return SupplicationRecord(
      id: map['id'] ?? '',
      supplication: map['supplication'] ?? '',
      location: map['location'] ?? '',
      recordedAt: (map['recordedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      audioPath: map['audioPath'] ?? '',
    );
  }
}
