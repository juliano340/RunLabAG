import 'database_service.dart';

class RecommendationResult {
  final double recommendedGoal;
  final String message;
  final bool isIncrease;

  RecommendationResult({
    required this.recommendedGoal,
    required this.message,
    this.isIncrease = false,
  });
}

class RecommendationService {
  /// Calcula a recomendação de meta para a próxima semana baseada na performance da semana atual/passada.
  static RecommendationResult calculateWeeklyRecommendation({
    required UserProfile profile,
    required List<RunModel> runs,
  }) {
    final double currentGoal = profile.weeklyGoal;
    
    // 1. Calcular volume total e dias ativos
    double totalDistance = 0;
    Set<String> activeDates = {};
    
    for (var run in runs) {
      totalDistance += run.distanceKm;
      // Consideramos apenas a data YYYY-MM-DD para contar dias únicos
      activeDates.add(run.date.toIso8601String().split('T')[0]);
    }
    
    int activeDays = activeDates.length;
    double achievementRatio = totalDistance / currentGoal;
    
    // 2. Cooldown: Apenas uma mudança a cada 7 dias para permitir adaptação
    if (profile.lastGoalUpdate != null) {
      final daysSinceUpdate = DateTime.now().difference(profile.lastGoalUpdate!).inDays;
      if (daysSinceUpdate < 7) {
        return RecommendationResult(
          recommendedGoal: currentGoal,
          message: "Meta atualizada recentemente! Mantenha os ${currentGoal.toStringAsFixed(1)}km por mais alguns dias para consolidar seu ritmo.",
          isIncrease: false,
        );
      }
    }

    // 3. Lógica de Progressão (Sobrecarga Progressiva)
    
    // CASO A: Meta Batida (ou quase batida - 90%+)
    if (achievementRatio >= 0.9) {
      double increasePercent;
      String justification;

      if (activeDays >= 4) {
        // Alta frequência permite progressão mais agressiva
        increasePercent = 0.12; 
        justification = "Excelente constância! Com $activeDays dias ativos, seu corpo está pronto para evoluir.";
      } else if (activeDays >= 3) {
        increasePercent = 0.08;
        justification = "Boa consistência. Vamos subir o volume gradualmente.";
      } else {
        // Pouca frequência, aumento conservador para evitar lesão
        increasePercent = 0.05;
        justification = "Meta batida! Recomendamos um aumento leve para consolidar sua base.";
      }

      double nextGoal = totalDistance * (1 + increasePercent);
      
      // Arredondar para o 0.5 mais próximo
      nextGoal = (nextGoal * 2).roundToDouble() / 2;

      return RecommendationResult(
        recommendedGoal: nextGoal,
        message: "$justification Sugerimos ${nextGoal.toStringAsFixed(1)}km para a próxima semana.",
        isIncrease: true,
      );
    } 
    
    // CASO B: Meta Não Batida (Abaixo de 50%)
    if (achievementRatio < 0.5 && totalDistance > 0) {
      double nextGoal = currentGoal * 0.9; // Redução leve para reajustar
      nextGoal = (nextGoal * 2).roundToDouble() / 2;
      
      return RecommendationResult(
        recommendedGoal: nextGoal,
        message: "Parece que esta semana foi desafiadora. Que tal um ajuste leve para ${nextGoal.toStringAsFixed(1)}km para retomar o fôlego?",
        isIncrease: false,
      );
    }

    // CASO C: Meta Mantida
    return RecommendationResult(
      recommendedGoal: currentGoal,
      message: "Mantenha o foco! O importante é a consistência. Sugerimos manter os ${currentGoal.toStringAsFixed(1)}km por mais uma semana.",
      isIncrease: false,
    );
  }
}
