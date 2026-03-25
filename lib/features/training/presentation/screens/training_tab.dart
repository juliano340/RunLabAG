import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/services/database_service.dart';
import '../../data/models/training_plan.dart';
import '../../services/training_service.dart';

class TrainingTab extends StatefulWidget {
  const TrainingTab({super.key});

  @override
  State<TrainingTab> createState() => _TrainingTabState();
}

class _TrainingTabState extends State<TrainingTab> {
  final DatabaseService _dbService = DatabaseService();
  late TrainingService _trainingService;
  
  UserPlanEnrollment? _activeEnrollment;
  TrainingPlan? _activePlan;
  PlanSession? _todaySession;
  List<TrainingPlan> _availablePlans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _trainingService = TrainingService(_dbService);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await _trainingService.initializePresets();
    
    final enrollment = await _trainingService.getActiveEnrollment();
    final plans = await _trainingService.getAvailablePlans();
    
    TrainingPlan? activePlan;
    PlanSession? today;
    
    if (enrollment != null) {
      activePlan = plans.firstWhere((p) => p.id == enrollment.planId);
      today = await _trainingService.getTodaySession();
    }

    if (mounted) {
      setState(() {
        _activeEnrollment = enrollment;
        _activePlan = activePlan;
        _todaySession = today;
        _availablePlans = plans;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryNeon));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Treinamento',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Evolua com planos profissionais.',
                style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 32),
              
              if (_activeEnrollment != null && _activePlan != null)
                _buildActivePlanStatus()
              else
                _buildNoActivePlan(),

              const SizedBox(height: 32),
              Text(
                'Planos Disponíveis',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ..._availablePlans.map((plan) => _buildPlanCard(plan)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivePlanStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Plano Atual',
          style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GlassContainer(
          borderColor: AppColors.primaryNeon.withValues(alpha: 0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _activePlan!.title,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Semana ${_activeEnrollment!.currentWeek} • Dia ${_activeEnrollment!.currentDay}',
                          style: GoogleFonts.outfit(color: AppColors.primaryNeonLight, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _activePlan!.level.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _activePlan!.level.label,
                          style: GoogleFonts.outfit(color: _activePlan!.level.color, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _confirmCancel(),
                          child: const Icon(LucideIcons.xCircle, color: Colors.white54, size: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_todaySession != null)
                _buildTodayTaskCard()
              else
                _buildRestDayCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTodayTaskCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.zap, color: AppColors.primaryNeon, size: 18),
              const SizedBox(width: 8),
              Text(
                'Treino de Hoje: ${_todaySession!.title}',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _todaySession!.description,
            style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Distância Alvo', style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 11)),
                  Text('${_todaySession!.targetDistance} km', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              ElevatedButton(
                onPressed: () {
                  // TODO: Iniciar treino focado nesta sessão
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNeon,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('COMEÇAR AGORA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRestDayCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.coffee, color: Colors.brown[300], size: 24),
          const SizedBox(height: 8),
          Text(
            'Hoje é dia de descanso!',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          Text(
            'Aproveite para alongar e recuperar as energias.',
            style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoActivePlan() {
    return GlassContainer(
      child: Column(
        children: [
          Icon(LucideIcons.calendarDays, color: AppColors.textMuted, size: 32),
          const SizedBox(height: 16),
          Text(
            'Nenhum plano ativo',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Escolha um plano abaixo para começar sua jornada de evolução guiada.',
            style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(TrainingPlan plan) {
    final bool isSelected = _activeEnrollment?.planId == plan.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        onTap: () => _showPlanDetails(plan),
        padding: const EdgeInsets.all(16),
        borderColor: isSelected ? AppColors.primaryNeon : null,
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: plan.level.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(LucideIcons.award, color: plan.level.color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    '${plan.totalWeeks} Semanas • ${plan.goal}',
                    style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  void _showPlanDetails(TrainingPlan plan) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundDarkGreen,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(plan.title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x, color: Colors.white54)),
                ],
              ),
              const SizedBox(height: 16),
              Text(plan.description, style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 14)),
              const SizedBox(height: 24),
              Row(
                children: [
                  _tile('Duração', '${plan.totalWeeks} sem.'),
                  _tile('Nível', plan.level.label),
                  _tile('Meta', plan.goal),
                ],
              ),
              const SizedBox(height: 32),
              if (_activeEnrollment?.planId == plan.id)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      _confirmCancel();
                    },
                    child: Text('CANCELAR INSCRIÇÃO', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNeon,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      await _trainingService.enrollInPlan(plan.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                        _loadAll();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Você se inscreveu no plano ${plan.title}! 🏃‍♂️💨')),
                        );
                      }
                    },
                    child: Text('INSCREVER-SE NO PLANO', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  ),
                ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        );
      },
    );
  }

  void _confirmCancel() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundDarkGreen,
        title: Text('Sair do Plano?', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Você perderá o progresso atual deste plano de treinamento.', style: GoogleFonts.outfit(color: AppColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCELAR', style: GoogleFonts.outfit(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await _trainingService.cancelCurrentPlan();
              if (!context.mounted) return;
              Navigator.pop(context);
              _loadAll();
            },
            child: Text('SAIR DO PLANO', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _tile(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 11)),
          Text(value, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
