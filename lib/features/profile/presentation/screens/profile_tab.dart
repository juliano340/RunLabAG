import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/services/database_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../../../core/services/theme_service.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _dbService = DatabaseService();
  UserProfile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _dbService.getUserProfile();
    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 500,
    );

    if (image != null && _profile != null) {
      // Salva a imagem localmente no diretório de documentos
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'profile_pic_${DateTime.now().millisecondsSinceEpoch}${p.extension(image.path)}';
      final savedImage = await File(image.path).copy(p.join(appDir.path, fileName));

      final updatedProfile = UserProfile(
        name: _profile!.name,
        age: _profile!.age,
        weight: _profile!.weight,
        height: _profile!.height,
        profilePicturePath: savedImage.path,
      );

      await _dbService.saveUserProfile(updatedProfile);
      _loadProfile();
    }
  }

  double _parseNumber(String value) {
    final sanitized = value.replaceAll(',', '.');
    return double.tryParse(sanitized) ?? 0.0;
  }

  void _showEditProfileDialog() {
    if (_profile == null) return;

    final nameController = TextEditingController(text: _profile!.name);
    final ageController = TextEditingController(text: _profile!.age.toString());
    final weightController = TextEditingController(text: _profile!.weight.toString().replaceAll('.', ','));
    final heightController = TextEditingController(text: _profile!.height.toInt().toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundDarkGreen,
        title: Text('Editar Perfil', style: GoogleFonts.outfit(color: Colors.white)),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEditField(nameController, 'Nome', LucideIcons.user),
                const SizedBox(height: 16),
                _buildEditField(ageController, 'Idade', LucideIcons.calendar, keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                _buildEditField(weightController, 'Peso (kg)', LucideIcons.scale, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 16),
                _buildEditField(heightController, 'Altura (cm)', LucideIcons.ruler, keyboardType: TextInputType.number),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNeon),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final updatedProfile = UserProfile(
                  name: nameController.text,
                  age: int.tryParse(ageController.text) ?? _profile!.age,
                  weight: _parseNumber(weightController.text),
                  height: _parseNumber(heightController.text),
                  profilePicturePath: _profile!.profilePicturePath,
                );
                await _dbService.saveUserProfile(updatedProfile);
                if (context.mounted) {
                  Navigator.pop(context);
                  _loadProfile();
                }
              }
            },
            child: const Text('SALVAR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        prefixIcon: Icon(icon, color: AppColors.primaryNeon, size: 20),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.cardBorder)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryNeon)),
      ),
      validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
    );
  }
  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundDarkGreen,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera, color: AppColors.primaryNeon),
              title: Text('Câmera', style: GoogleFonts.outfit(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.image, color: AppColors.primaryNeon),
              title: Text('Galeria', style: GoogleFonts.outfit(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryNeon));
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.cardBackground,
                      border: Border.all(color: AppColors.primaryNeon, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryNeon.withValues(alpha: 0.2),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _profile?.profilePicturePath != null
                          ? Image.file(
                              File(_profile!.profilePicturePath!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => 
                                const Icon(LucideIcons.user, size: 60, color: AppColors.primaryNeon),
                            )
                          : const Icon(LucideIcons.user, size: 60, color: AppColors.primaryNeon),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _showImagePickerOptions,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primaryNeon,
                        child: const Icon(LucideIcons.camera, color: Colors.black, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _profile?.name ?? 'Atleta',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildInfoBadge('${_profile?.age ?? 0} anos'),
                const SizedBox(width: 8),
                _buildInfoBadge('${_profile?.weight.toStringAsFixed(1) ?? 0} kg'),
                const SizedBox(width: 8),
                _buildInfoBadge('${_profile?.height.toInt() ?? 0} cm'),
              ],
            ),
            const SizedBox(height: 24),
            
            // BMI Card
            if (_profile != null)
              GlassContainer(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryNeon.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.heartPulse, color: AppColors.primaryNeon),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seu IMC: ${_profile!.bmi.toStringAsFixed(1)}',
                            style: GoogleFonts.outfit(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _profile!.bmiStatus,
                            style: GoogleFonts.outfit(
                              color: AppColors.primaryNeon,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 32),
            GlassContainer(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildProfileTile(context, LucideIcons.user, 'Editar Dados do Perfil', onTap: _showEditProfileDialog),
                  const Divider(color: AppColors.cardBorder, height: 1),
                  _buildProfileTile(context, LucideIcons.settings, 'Configurações de Conta'),
                  const Divider(color: AppColors.cardBorder, height: 1),
                  _buildProfileTile(context, LucideIcons.bell, 'Notificações'),
                  const Divider(color: AppColors.cardBorder, height: 1),
                  _buildProfileTile(context, LucideIcons.lock, 'Privacidade'),
                  const Divider(color: AppColors.cardBorder, height: 1),
                  _buildProfileTile(context, LucideIcons.helpCircle, 'Ajuda e Suporte'),
                  const Divider(color: AppColors.cardBorder, height: 1),
                  Consumer<ThemeService>(
                    builder: (context, themeService, child) {
                      return ListTile(
                        leading: Icon(
                          themeService.isDarkMode ? LucideIcons.moon : LucideIcons.sun,
                          color: AppColors.primaryNeon,
                        ),
                        title: Text(
                          'Modo Escuro',
                          style: GoogleFonts.outfit(color: AppColors.textLight),
                        ),
                        trailing: Switch(
                          value: themeService.isDarkMode,
                          onChanged: (_) => themeService.toggleTheme(),
                          activeThumbColor: AppColors.primaryNeon,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cardBackground,
                foregroundColor: AppColors.error,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.cardBorder),
                ),
              ),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('isLoggedIn');
                await prefs.remove('hasCompletedOnboarding'); // Permite refazer onboarding se sair
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
              icon: const Icon(LucideIcons.logOut),
              label: Text(
                'Sair',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12),
      ),
    );
  }

  Widget _buildProfileTile(BuildContext context, IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryNeon),
      title: Text(
        title,
        style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface),
      ),
      trailing: const Icon(LucideIcons.chevronRight, color: AppColors.textMuted),
      onTap: onTap ?? () {},
    );
  }
}
