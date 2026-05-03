import '../models/monthly_goal_model.dart';
import 'package:flutter/material.dart';

class GoalsStatisticsService {
  static GoalsStatisticsService? _instance;
  static GoalsStatisticsService get instance {
    _instance ??= GoalsStatisticsService._internal();
    return _instance!;
  }

  GoalsStatisticsService._internal();

  Map<String, dynamic> calculateGoalsStatistics(List<MonthlyGoal> goals) {
    final totalGoals = goals.length;
    final completedGoals = goals.where((goal) => goal.isCompleted).length;
    final inProgressGoals = totalGoals - completedGoals;
    
    // Calculate overall progress
    final totalProgress = goals.fold<double>(0.0, (sum, goal) => sum + goal.progress);
    final averageProgress = totalGoals > 0 ? totalProgress / totalGoals : 0.0;
    
    // Group by category
    final categoryStats = <String, Map<String, dynamic>>{};
    for (final goal in goals) {
      final category = goal.category;
      if (!categoryStats.containsKey(category)) {
        categoryStats[category] = {
          'total': 0,
          'completed': 0,
          'totalTarget': 0,
          'totalCurrent': 0,
        };
      }
      
      categoryStats[category]!['total']++;
      categoryStats[category]!['totalTarget'] += goal.targetValue;
      categoryStats[category]!['totalCurrent'] += goal.currentValue;
      
      if (goal.isCompleted) {
        categoryStats[category]!['completed']++;
      }
    }
    
    // Calculate category progress
    for (final entry in categoryStats.entries) {
      final stats = entry.value;
      final totalTarget = stats['totalTarget'] as int;
      final totalCurrent = stats['totalCurrent'] as int;
      stats['progress'] = totalTarget > 0 ? totalCurrent / totalTarget : 0.0;
    }
    
    // Find most active category
    String? mostActiveCategory;
    int maxGoals = 0;
    for (final entry in categoryStats.entries) {
      final total = entry.value['total'] as int;
      if (total > maxGoals) {
        maxGoals = total;
        mostActiveCategory = entry.key;
      }
    }
    
    // Calculate time-based statistics
    final now = DateTime.now();
    final goalsEndingSoon = goals.where((goal) {
      final daysLeft = goal.endDate.difference(now).inDays;
      return daysLeft <= 7 && daysLeft > 0 && !goal.isCompleted;
    }).length;
    
    final overdueGoals = goals.where((goal) {
      return goal.endDate.isBefore(now) && !goal.isCompleted;
    }).length;
    
    return {
      'totalGoals': totalGoals,
      'completedGoals': completedGoals,
      'inProgressGoals': inProgressGoals,
      'completionRate': totalGoals > 0 ? completedGoals / totalGoals : 0.0,
      'averageProgress': averageProgress,
      'categoryStats': categoryStats,
      'mostActiveCategory': mostActiveCategory,
      'goalsEndingSoon': goalsEndingSoon,
      'overdueGoals': overdueGoals,
    };
  }

  String getProgressLevel(double progress) {
    if (progress >= 1.0) return 'مكتمل';
    if (progress >= 0.8) return 'ممتاز';
    if (progress >= 0.6) return 'جيد';
    if (progress >= 0.4) return 'متوسط';
    if (progress >= 0.2) return 'ضعيف';
    return 'بداية';
  }

  Color getProgressColor(double progress, bool isDark) {
    if (progress >= 1.0) {
      return isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32);
    }
    if (progress >= 0.8) {
      return isDark ? const Color(0xFF66BB6A) : const Color(0xFF388E3C);
    }
    if (progress >= 0.6) {
      return isDark ? const Color(0xFF9CCC65) : const Color(0xFF689F38);
    }
    if (progress >= 0.4) {
      return isDark ? const Color(0xFFFFB74D) : const Color(0xFFFF9800);
    }
    if (progress >= 0.2) {
      return isDark ? const Color(0xFFFF8A65) : const Color(0xFFFF5722);
    }
    return isDark ? const Color(0xFFEF5350) : const Color(0xFFD32F2F);
  }

  List<Map<String, dynamic>> getGoalsByPriority(List<MonthlyGoal> goals) {
    final now = DateTime.now();
    final goalsWithPriority = <Map<String, dynamic>>[];
    
    for (final goal in goals) {
      if (goal.isCompleted) continue;
      
      final daysLeft = goal.endDate.difference(now).inDays;
      String priority;
      int priorityScore;
      
      if (daysLeft < 0) {
        priority = 'متأخر';
        priorityScore = 100;
      } else if (daysLeft <= 3) {
        priority = 'عاجل';
        priorityScore = 80;
      } else if (daysLeft <= 7) {
        priority = 'قريب';
        priorityScore = 60;
      } else if (daysLeft <= 14) {
        priority = 'متوسط';
        priorityScore = 40;
      } else {
        priority = 'طويل الأمد';
        priorityScore = 20;
      }
      
      // Adjust priority based on progress
      final progressScore = (1.0 - goal.progress) * 30;
      priorityScore += progressScore.round();
      
      goalsWithPriority.add({
        'goal': goal,
        'priority': priority,
        'priorityScore': priorityScore,
        'daysLeft': daysLeft,
      });
    }
    
    // Sort by priority score (descending)
    goalsWithPriority.sort((a, b) => (b['priorityScore'] as int).compareTo(a['priorityScore'] as int));
    
    return goalsWithPriority;
  }

  Map<String, dynamic> getMonthlyTrend(List<MonthlyGoal> goals) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    
    final currentMonthGoals = goals.where((goal) => 
      goal.startDate.isAfter(currentMonth) || goal.startDate.isAtSameMomentAs(currentMonth)
    ).length;
    
    final lastMonthGoals = goals.where((goal) => 
      goal.startDate.isAfter(lastMonth) || goal.startDate.isAtSameMomentAs(lastMonth)
    ).length;
    
    final trend = currentMonthGoals - lastMonthGoals;
    final trendPercentage = lastMonthGoals > 0 ? (trend / lastMonthGoals) * 100 : 0.0;
    
    return {
      'currentMonth': currentMonthGoals,
      'lastMonth': lastMonthGoals,
      'trend': trend,
      'trendPercentage': trendPercentage,
      'isIncreasing': trend > 0,
    };
  }
}
