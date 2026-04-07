import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:runlabag/core/theme/app_colors.dart';
import 'package:runlabag/core/services/database_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _weeklyGoalController = TextEditingController(text: '20');
  final _waterGoalController = TextEditingController(text: '2000');

  int _currentPage = 0;
  final int _totalPages = 7;
  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _weeklyGoalController.dispose();
    _waterGoalController.dispose();
    super.dispose();
  }

  double _parseNumber(String value) {
    // Replace comma with dot for parsing
    final sanitized = value.replaceAll(',', '.');
    return double.tryParse(sanitized) ?? 0.0;
  }

  void _nextPage() async {
    if (_formKey.currentState!.validate()) {
      if (_currentPage < _totalPages - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        await _requestPermissionsAndSubmit();
      }
    }
  }

  Future<void> _requestPermissionsAndSubmit() async {
    if (_isLoading) return;
    
    // First request basic permissions
    await [
      Permission.location,
      Permission.notification,
    ].request();

    // If on Android, also prompt for Background Location if possible
    if (Platform.isAndroid) {
      await Permission.locationAlways.request();
    }

    _submit();
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _submit() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final profile = UserProfile(
        name: _nameController.text,
        age: int.tryParse(_ageController.text) ?? 0,
        weight: _parseNumber(_weightController.text),
        height: _parseNumber(_heightController.text),
        weeklyGoal: _parseNumber(_weeklyGoalController.text),
        waterGoal: _parseNumber(_waterGoalController.text),
      );

      final dbService = DatabaseService();
      await dbService.saveUserProfile(profile);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasCompletedOnboarding', true);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } catch (e) {
      debugPrint('Error saving onboarding: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar perfil: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: List.generate(_totalPages, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index <= _currentPage
                            ? AppColors.primaryNeon
                            : AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            
            Expanded(
              child: Form(
                key: _formKey,
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  children: [
                    _buildStep(
                      title: 'Qual o seu nome?',
                      subtitle: 'Como os seus amigos te chamam?',
                      child: _buildTextField(
                        controller: _nameController,
                        label: 'Nome',
                        icon: LucideIcons.user,
                        hint: 'Ex: João Silva',
                        validator: (v) => v == null || v.isEmpty ? 'Nome é obrigatório' : null,
                      ),
                    ),
                    _buildStep(
                      title: 'Qual a sua idade?',
                      subtitle: 'Isso nos ajuda a calcular seu metabolismo.',
                      child: _buildTextField(
                        controller: _ageController,
                        label: 'Idade',
                        icon: LucideIcons.calendar,
                        keyboardType: TextInputType.number,
                        hint: 'Anos',
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Idade é obrigatória';
                          if (int.tryParse(v) == null) return 'Idade inválida';
                          return null;
                        },
                      ),
                    ),
                    _buildStep(
                      title: 'Qual o seu peso?',
                      subtitle: 'Isso nos ajuda a calcular sua performance.',
                      child: _buildTextField(
                        controller: _weightController,
                        label: 'Peso (kg)',
                        icon: LucideIcons.scale,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        hint: 'Ex: 75,5',
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Peso é obrigatório';
                          if (_parseNumber(v) <= 0) return 'Peso inválido';
                          return null;
                        },
                      ),
                    ),
                    _buildStep(
                      title: 'Qual a sua altura?',
                      subtitle: 'Precisamos disso para calcular o seu IMC.',
                      child: _buildTextField(
                        controller: _heightController,
                        label: 'Altura (cm)',
                        icon: LucideIcons.ruler,
                        keyboardType: TextInputType.number,
                        hint: 'Ex: 175',
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Altura é obrigatória';
                          if (_parseNumber(v) <= 0) return 'Altura inválida';
                          return null;
                        },
                      ),
                    ),
                    _buildStep(
                      title: 'Qual a sua meta?',
                      subtitle: 'Quantos quilômetros você quer correr por semana?',
                      child: _buildTextField(
                        controller: _weeklyGoalController,
                        label: 'Meta Semanal (km)',
                        icon: LucideIcons.target,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        hint: 'Ex: 20',
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Meta é obrigatória';
                          if (_parseNumber(v) <= 0) return 'Meta inválida';
                          return null;
                        },
                      ),
                    ),
                    _buildStep(
                      title: 'Qual a sua meta de água?',
                      subtitle: 'Quanto de água você quer tomar por dia?',
                      child: _buildTextField(
                        controller: _waterGoalController,
                        label: 'Meta de Água (ml)',
                        icon: LucideIcons.droplets,
                        keyboardType: TextInputType.number,
                        hint: 'Ex: 2000',
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Meta é obrigatória';
                          if (_parseNumber(v) <= 0) return 'Meta inválida';
                          return null;
                        },
                      ),
                    ),
                    _buildStep(
                      title: 'Permissões do Sistema',
                      subtitle: 'Precisamos de acesso para garantir o melhor acompanhamento.',
                      child: Column(
                        children: [
                          _buildPermissionItem(
                            icon: LucideIcons.mapPin,
                            title: 'Localização (GPS)',
                            description: 'Para rastrear seu percurso e ritmo em tempo real.',
                          ),
                          const SizedBox(height: 16),
                          _buildPermissionItem(
                            icon: LucideIcons.bell,
                            title: 'Notificações',
                            description: 'Para avisos de KM, metas e lembretes de hidratação.',
                          ),
                          const SizedBox(height: 16),
                          _buildPermissionItem(
                            icon: LucideIcons.navigation,
                            title: 'Sempre Ativo',
                            description: 'Permite que o GPS funcione mesmo com a tela bloqueada.',
                          ),
                          const Spacer(),
                          Text(
                            'Clique em "FINALIZAR" para configurar.',
                            style: GoogleFonts.outfit(
                              color: AppColors.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      flex: 1,
                      child: TextButton(
                        onPressed: _previousPage,
                        child: Text(
                          'VOLTAR',
                          style: GoogleFonts.outfit(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryNeon,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _isLoading ? null : _nextPage,
                      child: _isLoading 
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : Text(
                            _currentPage == _totalPages - 1 ? 'FINALIZAR' : 'PRÓXIMO',
                            style: GoogleFonts.outfit(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryNeon.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryNeon, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.outfit(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: GoogleFonts.outfit(
              color: AppColors.textMuted,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 48),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            color: AppColors.textLight,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            prefixIcon: Icon(icon, color: AppColors.primaryNeon, size: 24),
            filled: true,
            fillColor: AppColors.cardBackground,
            contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            errorStyle: const TextStyle(color: Colors.redAccent),
          ),
          validator: validator,
          onFieldSubmitted: (_) => _nextPage(),
        ),
      ],
    );
  }
}
