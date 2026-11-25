import 'package:shared_preferences/shared_preferences.dart';

/// Persistência da janela selecionada na Visão Geral.
abstract interface class HomeStatsWindowStore {
  Future<int?> readStatsPeriod();

  Future<void> writeStatsPeriod(int statsPeriod);
}

class SharedPreferencesHomeStatsWindowStore implements HomeStatsWindowStore {
  const SharedPreferencesHomeStatsWindowStore();

  static const _statsPeriodKey = 'home_stats_period';

  @override
  Future<int?> readStatsPeriod() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_statsPeriodKey);
  }

  @override
  Future<void> writeStatsPeriod(int statsPeriod) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_statsPeriodKey, statsPeriod);
  }
}
