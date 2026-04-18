import 'package:lucide_icons/lucide_icons.dart';
import 'database_service.dart';

class AchievementService {
  final DatabaseService _dbService = DatabaseService();

  /// Verifica e salva novas conquistas com base no último treino.
  /// Retorna apenas conquistas REALMENTE novas (ainda não desbloqueadas).
  Future<List<Map<String, dynamic>>> checkAwards(RunModel latestRun) async {
    final List<Map<String, dynamic>> candidates = [];
    final allRuns = await _dbService.getRuns();
    final stats = await _dbService.getUserStats();
    final double totalDist = double.tryParse(stats['totalDistance'] ?? '0') ?? 0;

    // Conquistas já desbloqueadas — usadas para filtrar duplicatas
    final earned = await _dbService.getEarnedAchievements();
    final Set<String> earnedIds = earned.map((e) => e['id'] as String).toSet();

    // 1. Primeiro Passo: Complete sua primeira corrida
    if (allRuns.length == 1) {
      candidates.add({
        'id': 'first_run',
        'title': 'Primeiro Passo',
        'desc': 'Complete sua primeira corrida',
        'icon': LucideIcons.footprints.codePoint,
      });
    }

    // 2. Coruja Noturna: Corra após as 20h
    if (latestRun.date.hour >= 20 || latestRun.date.hour < 5) {
      candidates.add({
        'id': 'night_owl',
        'title': 'Coruja Noturna',
        'desc': 'Corra após as 20h',
        'icon': LucideIcons.moon.codePoint,
      });
    }

    // 3. Finalizador 5K
    if (latestRun.distanceKm >= 5.0) {
      candidates.add({
        'id': 'finisher_5k',
        'title': 'Finalizador 5K',
        'desc': 'Corra 5 quilômetros em uma sessão',
        'icon': LucideIcons.medal.codePoint,
      });
    }

    // 4. Mestre 10K
    if (latestRun.distanceKm >= 10.0) {
      candidates.add({
        'id': 'master_10k',
        'title': 'Mestre 10K',
        'desc': 'Corra 10 quilômetros em uma sessão',
        'icon': LucideIcons.trophy.codePoint,
      });
    }

    // 5. Treino de Maratona: 100km total
    if (totalDist >= 100.0) {
      candidates.add({
        'id': 'marathon_training',
        'title': 'Treino de Maratona',
        'desc': 'Corra 100km de distância total',
        'icon': LucideIcons.target.codePoint,
      });
    }

    // 6. Demônio da Velocidade: Ritmo abaixo de 4:30/km
    // latestRun.pace format is "M:SS"
    if (latestRun.pace != '0:00') {
      try {
        final parts = latestRun.pace.split(':');
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        final totalSeconds = (minutes * 60) + seconds;
        if (totalSeconds < 270) { // 270s = 4:30 min
          candidates.add({
            'id': 'speed_demon',
            'title': 'Demônio da Velocidade',
            'desc': 'Ritmo abaixo de 4:30/km por 1km',
            'icon': LucideIcons.zap.codePoint,
          });
        }
      } catch (e) {
        // Ignorar erro de parsing
      }
    }

    // Filtra apenas conquistas ainda não desbloqueadas — o bug antigo
    // disparava o toast "nova conquista" mesmo para conquistas repetidas.
    final List<Map<String, dynamic>> newlyEarned = candidates
        .where((a) => !earnedIds.contains(a['id']))
        .toList();

    // Salvar no banco
    for (var achievement in newlyEarned) {
      await _dbService.saveAchievement(
        achievement['id'],
        achievement['title'],
        achievement['desc'],
        achievement['icon'],
      );
    }

    return newlyEarned;
  }

  /// Gera mensagens de incentivo para cada KM
  static String getIncentiveMessage(int km) {
    final messages = [
      'Ótimo começo! 1km pra conta! 🔥',
      'Ritmo excelente! 2km concluídos! 🏃‍♂️',
      'Metade de 6km? Não, são 3km de pura garra! 💪',
      '4km! Você está voando baixo! ⚡',
      'UAU! 5km! Você é uma máquina! 🏆',
      '6km! Mantém esse foco! 🏁',
      '7km! Sua resistência é incrível! 🔋',
      '8km! Quase lá, não para agora! 💥',
      '9km! Só mais um pouco para o double digit! 🚀',
      '10km! INSANO! Você é lendário! 👑',
    ];
    
    if (km <= messages.length) {
      return messages[km - 1];
    }
    return 'Mais um KM concluído! $km km! Continue assim! ⭐';
  }
}
