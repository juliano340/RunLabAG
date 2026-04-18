import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/services/database_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../../../core/services/theme_service.dart';
import '../../../../core/services/backup_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:runlabag/core/services/ad_service.dart';
import 'package:runlabag/features/water/presentation/providers/water_provider.dart';
import '../../../../core/services/notification_service.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _dbService = DatabaseService();
  final _backupService = BackupService();
  UserProfile? _profile;
  bool _isLoading = true;
  bool _autoBackupEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadAutoBackupPreference();
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

  Future<void> _loadAutoBackupPreference() async {
    final enabled = await _backupService.isAutoBackupEnabled();
    if (mounted) {
      setState(() => _autoBackupEnabled = enabled);
    }
  }

  Future<void> _toggleAutoBackup(bool enabled) async {
    if (enabled) {
      final granted = await _backupService.requestStoragePermission();
      if (!granted) {
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Permissão negada. Libere "Acesso a todos os arquivos" nas configurações.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }
    await _backupService.setAutoBackupEnabled(enabled);
    if (mounted) {
      setState(() => _autoBackupEnabled = enabled);
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
        weeklyGoal: _profile!.weeklyGoal,
        monthlyGoal: _profile!.monthlyGoal,
        waterGoal: _profile!.waterGoal,
        kmNotificationsEnabled: _profile!.kmNotificationsEnabled,
      );

      await _dbService.saveUserProfile(updatedProfile);
      if (mounted) {
        context.read<WaterProvider>().refresh();
      }
      _loadProfile();
    }
  }

  Future<void> _removeProfilePicture() async {
    if (_profile == null) return;

    // Delete local file if it exists
    if (_profile!.profilePicturePath != null) {
      try {
        final file = File(_profile!.profilePicturePath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error deleting profile pic: $e');
      }
    }

    final updatedProfile = UserProfile(
      name: _profile!.name,
      age: _profile!.age,
      weight: _profile!.weight,
      height: _profile!.height,
      profilePicturePath: null,
      weeklyGoal: _profile!.weeklyGoal,
      monthlyGoal: _profile!.monthlyGoal,
      waterGoal: _profile!.waterGoal,
      kmNotificationsEnabled: _profile!.kmNotificationsEnabled,
    );

    await _dbService.saveUserProfile(updatedProfile);
    if (mounted) {
      context.read<WaterProvider>().refresh();
    }
    _loadProfile();
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
    final weeklyGoalController = TextEditingController(text: _profile!.weeklyGoal.toString().replaceAll('.', ','));
    final waterGoalController = TextEditingController(text: _profile!.waterGoal.toInt().toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
        backgroundColor: cs.surface,
        title: Text('Editar Perfil', style: GoogleFonts.outfit(color: cs.onSurface)),
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
                const SizedBox(height: 16),
                _buildEditField(weeklyGoalController, 'Meta Semanal (km)', LucideIcons.target, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 16),
                _buildEditField(waterGoalController, 'Meta de Água (ml)', LucideIcons.droplet, keyboardType: TextInputType.number),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCELAR', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: cs.primary),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final updatedProfile = UserProfile(
                  name: nameController.text,
                  age: int.tryParse(ageController.text) ?? _profile!.age,
                  weight: _parseNumber(weightController.text),
                  height: _parseNumber(heightController.text),
                  profilePicturePath: _profile!.profilePicturePath,
                  weeklyGoal: _parseNumber(weeklyGoalController.text),
                  monthlyGoal: _profile!.monthlyGoal,
                  waterGoal: _parseNumber(waterGoalController.text),
                  kmNotificationsEnabled: _profile!.kmNotificationsEnabled,
                );
                await _dbService.saveUserProfile(updatedProfile);
                if (context.mounted) {
                  context.read<WaterProvider>().refresh();
                  Navigator.pop(context);
                  _loadProfile();
                }
              }
            },
            child: Text('SALVAR', style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.bold)),
          ),
        ],
      );
      },
    );
  }

  Widget _buildEditField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: cs.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: cs.onSurfaceVariant),
        prefixIcon: Icon(icon, color: cs.primary, size: 20),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.outline)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.primary)),
      ),
      validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
    );
  }
  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(LucideIcons.camera, color: cs.primary),
                title: Text('Câmera', style: GoogleFonts.outfit(color: cs.onSurface)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(LucideIcons.image, color: cs.primary),
                title: Text('Galeria', style: GoogleFonts.outfit(color: cs.onSurface)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_profile?.profilePicturePath != null)
                ListTile(
                  leading: Icon(LucideIcons.trash2, color: cs.error),
                  title: Text('Remover Foto', style: GoogleFonts.outfit(color: cs.error)),
                  onTap: () {
                    Navigator.pop(context);
                    _removeProfilePicture();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
    }


    return SafeArea(
      child: SingleChildScrollView(
        key: const PageStorageKey('profile_scroll'),
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
                      color: Theme.of(context).colorScheme.primaryContainer,
                      border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
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
                                Icon(LucideIcons.user, size: 60, color: Theme.of(context).colorScheme.primary),
                            )
                          : Icon(LucideIcons.user, size: 60, color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _showImagePickerOptions,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Icon(LucideIcons.camera, color: Theme.of(context).colorScheme.onPrimary, size: 18),
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
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoBadge('${_profile?.age ?? 0} anos'),
                _buildInfoBadge('${_profile?.weight.toStringAsFixed(1) ?? 0} kg'),
                _buildInfoBadge('${_profile?.height.toInt() ?? 0} cm'),
                _buildInfoBadge('Meta: ${_profile?.weeklyGoal.toStringAsFixed(1) ?? 20} km'),
                _buildInfoBadge('Água: ${(_profile?.waterGoal ?? 2000).toInt()} ml'),
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
                              color: Theme.of(context).colorScheme.primary,
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
                  Divider(color: Theme.of(context).colorScheme.outline, height: 1),
                  _buildProfileTile(context, LucideIcons.lock, 'Privacidade', onTap: () => Navigator.pushNamed(context, '/privacy')),
                  Divider(color: Theme.of(context).colorScheme.outline, height: 1),
                  Builder(
                    builder: (context) {
                      final cs = Theme.of(context).colorScheme;
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return ListTile(
                        leading: Icon(
                          isDark ? LucideIcons.moon : LucideIcons.sun,
                          color: cs.primary,
                        ),
                        title: Text(
                          'Modo Escuro',
                          style: GoogleFonts.outfit(color: cs.onSurface),
                        ),
                        trailing: Switch(
                          value: isDark,
                          onChanged: context.watch<ThemeService>().isToggling
                              ? null
                              : (_) => context.read<ThemeService>().toggleTheme(),
                          activeThumbColor: cs.primary,
                        ),
                      );
                    },
                  ),
                  Divider(color: Theme.of(context).colorScheme.outline, height: 1),
                  ListTile(
                    leading: Icon(LucideIcons.bell, color: Theme.of(context).colorScheme.primary),
                    title: Text(
                      'Notificar a cada km',
                      style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface),
                    ),
                    subtitle: Text(
                      'Vibração e push a cada km completado no treino',
                      style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11),
                    ),
                    trailing: Switch(
                      key: const ValueKey('notifications_switch'),
                      value: _profile?.kmNotificationsEnabled ?? true,
                      onChanged: _profile == null ? null : (value) async {
                        final updated = UserProfile(
                          name: _profile!.name,
                          age: _profile!.age,
                          weight: _profile!.weight,
                          height: _profile!.height,
                          profilePicturePath: _profile!.profilePicturePath,
                          weeklyGoal: _profile!.weeklyGoal,
                          monthlyGoal: _profile!.monthlyGoal,
                          waterGoal: _profile!.waterGoal,
                          lastGoalUpdate: _profile!.lastGoalUpdate,
                          kmNotificationsEnabled: value,
                        );
                        await _dbService.saveUserProfile(updated);
                        if (mounted) setState(() => _profile = updated);
                      },
                      activeThumbColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  if (kDebugMode && _profile?.kmNotificationsEnabled == true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, right: 16.0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            // Dispara uma notificação de teste simulando o km 1
                            NotificationService.sendKmMilestone(1, "5:30");
                          },
                          icon: Icon(LucideIcons.playCircle, size: 16, color: Theme.of(context).colorScheme.primary),
                          label: Text('Testar Notificação', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(height: 32),
            
            // Data & Backup Section
            Text(
              'DADOS E PRIVACIDADE',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            GlassContainer(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildBackupTile(
                    context,
                    LucideIcons.upload,
                    'Exportar Meus Treinos',
                    'Cria um arquivo de backup do seu histórico',
                    onTap: () async {
                      try {
                        await _backupService.exportBackup();
                      } catch (e) {
                        if (mounted && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Erro ao exportar backup', style: TextStyle(color: Colors.white))),
                          );
                        }
                      }
                    },
                  ),
                  Divider(color: Theme.of(context).colorScheme.outline, height: 1),
                  _buildBackupTile(
                    context,
                    LucideIcons.download,
                    'Restaurar Backup',
                    'Recupere seus dados de um arquivo .json',
                    onTap: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['json'],
                      );

                      if (result != null) {
                        final file = File(result.files.single.path!);
                        final content = await file.readAsString();
                        final success = await _backupService.importBackup(content);

                        if (mounted && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                ? 'Dados restaurados com sucesso!'
                                : 'Erro ao importar arquivo',
                                style: const TextStyle(color: Colors.white)),
                              backgroundColor: success ? Colors.green : Colors.red,
                            ),
                          );
                          if (success) _loadProfile();
                        }
                      }
                    },
                  ),
                  Divider(color: Theme.of(context).colorScheme.outline, height: 1),
                  _buildAutoBackupToggle(context),
                ],
              ),
            ),
            // Help & Support Section
            const SizedBox(height: 32),
            Text(
              'AJUDA E SUPORTE',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            GlassContainer(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildProfileTile(
                    context, 
                    LucideIcons.helpCircle, 
                    'Suporte e FAQ', 
                    onTap: () async {
                      final Uri url = Uri.parse('https://www.juliano340.com/runlab/suporte');
                      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Não foi possível abrir o link de suporte', style: TextStyle(color: Colors.white))),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 32),
              Text(
                'DESENVOLVEDOR',
                style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              GlassContainer(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(LucideIcons.code, color: Theme.of(context).colorScheme.primary),
                      title: Text(
                        'Exibir Anúncios (Banner)',
                        style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface),
                      ),
                      trailing: Switch(
                        value: AdService().adsEnabled,
                        onChanged: (value) async {
                          await AdService().setAdsEnabled(value);
                          if (mounted) setState(() {});
                        },
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoBackupToggle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SwitchListTile(
      value: _autoBackupEnabled,
      onChanged: _toggleAutoBackup,
      activeThumbColor: cs.primary,
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(LucideIcons.hardDrive, color: cs.primary, size: 20),
      ),
      title: Text(
        'Backup Automático',
        style: GoogleFonts.outfit(
          color: cs.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        'Salva em ${_backupService.autoBackupFolderPath} após treinos > 5min',
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
      ),
    );
  }

  Widget _buildBackupTile(BuildContext context, IconData icon, String title, String subtitle, {required VoidCallback onTap}) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: cs.primary, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.outfit(
          color: cs.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
      ),
      onTap: onTap,
    );
  }

  Widget _buildInfoBadge(String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(color: cs.onSurfaceVariant, fontSize: 12),
      ),
    );
  }

  Widget _buildProfileTile(BuildContext context, IconData icon, String title, {VoidCallback? onTap}) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.primary),
      title: Text(
        title,
        style: GoogleFonts.outfit(color: cs.onSurface),
      ),
      trailing: Icon(LucideIcons.chevronRight, color: cs.onSurfaceVariant),
      onTap: onTap ?? () {},
    );
  }
}
