import 'package:flutter/material.dart';
import 'package:runlabag/core/services/database_service.dart';
import 'package:runlabag/features/water/data/models/water_consumption.dart';

class WaterProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  
  int _dailyIntake = 0;
  double _dailyGoal = 2000.0;
  List<Map<String, dynamic>> _todayLogs = [];
  bool _isLoading = false;

  int get dailyIntake => _dailyIntake;
  double get dailyGoal => _dailyGoal;
  List<Map<String, dynamic>> get todayLogs => _todayLogs;
  bool get isLoading => _isLoading;
  double get progress => (_dailyIntake / _dailyGoal).clamp(0.0, 1.0);

  WaterProvider() {
    refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    try {
      final profile = await _db.getUserProfile();
      if (profile != null) {
        _dailyGoal = profile.waterGoal;
      }

      _dailyIntake = await _db.getTotalDailyWaterIntake();
      _todayLogs = await _db.getDailyWaterIntake();
    } catch (e) {
      debugPrint('Error refreshing water data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addWater(int amount) async {
    await _db.saveWaterIntake(amount);
    await refresh();
  }

  Future<void> removeWaterLog(int id) async {
    await _db.deleteWaterIntake(id);
    await refresh();
  }

  Future<void> updateGoal(double newGoal) async {
    final profile = await _db.getUserProfile();
    if (profile != null) {
      final updatedProfile = UserProfile(
        name: profile.name,
        age: profile.age,
        weight: profile.weight,
        height: profile.height,
        profilePicturePath: profile.profilePicturePath,
        weeklyGoal: profile.weeklyGoal,
        monthlyGoal: profile.monthlyGoal,
        waterGoal: newGoal,
      );
      await _db.saveUserProfile(updatedProfile);
      _dailyGoal = newGoal;
      notifyListeners();
    }
  }
}
