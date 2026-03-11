import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  int _currentPage = 0;
  final int _totalPages = 4;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  double _parseNumber(String value) {
    // Replace comma with dot for parsing
    final sanitized = value.replaceAll(',', '.');
    return double.tryParse(sanitized) ?? 0.0;
  }

  void _nextPage() {
    if (_formKey.currentState!.validate()) {
      if (_currentPage < _totalPages - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _submit();
      }
    }
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
    final profile = UserProfile(
      name: _nameController.text,
      age: int.tryParse(_ageController.text) ?? 0,
      weight: _parseNumber(_weightController.text),
      height: _parseNumber(_heightController.text),
    );

    final dbService = DatabaseService();
    await dbService.saveUserProfile(profile);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasCompletedOnboarding', true);

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
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
                      title: 'Quanto você pesa?',
                      subtitle: 'Cálculo de calorias depende do seu peso.',
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
                      onPressed: _nextPage,
                      child: Text(
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
