import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklyPlan {
  final String id;
  final String userId;
  final String monthlyGoalId;
  final DateTime weekStartDate;
  final List<DailyPlan> dailyPlans;
  final DateTime createdAt;

  WeeklyPlan({
    required this.id,
    required this.userId,
    required this.monthlyGoalId,
    required this.weekStartDate,
    required this.dailyPlans,
    required this.createdAt,
  });

  int get totalCompletedDays => dailyPlans.where((plan) => plan.isCompleted).length;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'monthlyGoalId': monthlyGoalId,
      'weekStartDate': Timestamp.fromDate(weekStartDate),
      'dailyPlans': dailyPlans.map((plan) => plan.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory WeeklyPlan.fromMap(Map<String, dynamic> map, String docId) {
    return WeeklyPlan(
      id: docId,
      userId: map['userId'] ?? '',
      monthlyGoalId: map['monthlyGoalId'] ?? '',
      weekStartDate: (map['weekStartDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dailyPlans: (map['dailyPlans'] as List<dynamic>?)
          ?.map((plan) => DailyPlan.fromMap(plan as Map<String, dynamic>))
          .toList() ?? [],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class DailyPlan {
  final DateTime date;
  final String task;
  final String description;
  final int targetAmount;
  final bool isCompleted;
  final int actualAmount;

  DailyPlan({
    required this.date,
    required this.task,
    required this.description,
    required this.targetAmount,
    this.isCompleted = false,
    this.actualAmount = 0,
  });

  double get progress => targetAmount > 0 ? actualAmount / targetAmount : 0;

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'task': task,
      'description': description,
      'targetAmount': targetAmount,
      'isCompleted': isCompleted,
      'actualAmount': actualAmount,
    };
  }

  factory DailyPlan.fromMap(Map<String, dynamic> map) {
    return DailyPlan(
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      task: map['task'] ?? '',
      description: map['description'] ?? '',
      targetAmount: map['targetAmount'] ?? 0,
      isCompleted: map['isCompleted'] ?? false,
      actualAmount: map['actualAmount'] ?? 0,
    );
  }

  DailyPlan copyWith({
    bool? isCompleted,
    int? actualAmount,
  }) {
    return DailyPlan(
      date: date,
      task: task,
      description: description,
      targetAmount: targetAmount,
      isCompleted: isCompleted ?? this.isCompleted,
      actualAmount: actualAmount ?? this.actualAmount,
    );
  }
}
