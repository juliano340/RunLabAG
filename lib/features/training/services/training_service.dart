import '../../../core/services/database_service.dart';
import '../data/models/training_plan.dart';

class TrainingService {
  final DatabaseService _dbService;

  TrainingService(this._dbService);

  /// Inicializa o banco de dados com alguns planos padrão se ainda não existirem
  Future<void> initializePresets() async {
    final existingPlans = await _dbService.getTrainingPlans();
    if (existingPlans.isNotEmpty) return;

    // Plano Iniciante: 5km
    final beginner5k = TrainingPlan(
      id: 'beginner_5k',
      title: 'Meu Primeiro 5km',
      description: 'Perfeito para quem está começando do zero. Foco em alternar caminhada e corrida para construir resistência.',
      totalWeeks: 4,
      level: PlanLevel.beginner,
      goal: 'Completar 5km sem parar',
    );

    await _dbService.saveTrainingPlan(beginner5k);

    // Plano Iniciante: 5km (Sessions on Day 1, 3, 5)
    final sessions = [
      PlanSession(
        id: 'b5k_w1_d1',
        planId: 'beginner_5k',
        week: 1,
        day: 1, 
        title: 'Boas-vindas!',
        type: SessionType.easy,
        targetDistance: 1.5,
        description: 'Trote leve de 15 min para começar com o pé direito.',
      ),
      PlanSession(
        id: 'b5k_w1_d3',
        planId: 'beginner_5k',
        week: 1,
        day: 3, 
        title: 'Consolidação',
        type: SessionType.easy,
        targetDistance: 2.0,
        description: 'Alterne 2 min correndo e 1 min caminhando.',
      ),
      PlanSession(
        id: 'b5k_w1_d5',
        planId: 'beginner_5k',
        week: 1,
        day: 5, 
        title: 'Primeiro Desafio',
        type: SessionType.long,
        targetDistance: 3.0,
        description: 'Mantenha um ritmo constante. O objetivo é a distância.',
      ),
    ];

    for (var s in sessions) {
      await _dbService.savePlanSession(s);
    }

    // Plano Intermediário: 10km
    final intermediate10k = TrainingPlan(
      id: 'inter_10k',
      title: 'Evolução 10km',
      description: 'Para quem já corre 5km e quer dobrar a distância com segurança.',
      totalWeeks: 6,
      level: PlanLevel.intermediate,
      goal: 'Correr 10km abaixo de 60min',
    );

    await _dbService.saveTrainingPlan(intermediate10k);

    // Sessão exemplo para 10km (Day 1)
    await _dbService.savePlanSession(PlanSession(
      id: 'i10k_w1_d1',
      planId: 'inter_10k',
      week: 1,
      day: 1,
      title: 'Velocidade Base',
      type: SessionType.intervals,
      targetDistance: 4.0,
      description: 'Aquecimento 1km + 4x 500m rápido com 1 min de descanso.',
    ));
  }

  Future<List<TrainingPlan>> getAvailablePlans() async {
    return await _dbService.getTrainingPlans();
  }

  Future<UserPlanEnrollment?> getActiveEnrollment() async {
    return await _dbService.getActiveEnrollment();
  }

  Future<void> enrollInPlan(String planId) async {
    final enrollment = UserPlanEnrollment(
      planId: planId,
      startDate: DateTime.now(),
    );
    await _dbService.saveEnrollment(enrollment);
  }

  Future<PlanSession?> getTodaySession() async {
    final enrollment = await getActiveEnrollment();
    if (enrollment == null) return null;

    final now = DateTime.now();
    final start = DateTime(enrollment.startDate.year, enrollment.startDate.month, enrollment.startDate.day);
    final today = DateTime(now.year, now.month, now.day);
    
    final daysSinceStart = today.difference(start).inDays;
    
    final currentWeek = (daysSinceStart / 7).floor() + 1;
    final currentDay = (daysSinceStart % 7) + 1;

    final sessions = await _dbService.getPlanSessions(enrollment.planId);
    
    try {
      return sessions.firstWhere((s) => s.week == currentWeek && s.day == currentDay);
    } catch (_) {
      return null;
    }
  }

  /// Verifica se um treino recente "bate" com a sessão planejada
  Future<bool> matchRunToPlan(RunModel run) async {
    final session = await getTodaySession();
    if (session == null) return false;

    // Se correr pelo menos 90% da distância alvo, consideramos cumprido
    final isCompliant = run.distanceKm >= (session.targetDistance * 0.9);
    
    if (isCompliant) {
      // Aqui poderíamos marcar a sessão como concluída em uma tabela separada
      // Por simplicidade, apenas retornamos o status
    }
    
    return isCompliant;
  }

  Future<void> cancelCurrentPlan() async {
    await _dbService.deactivateActiveEnrollment();
  }
}
