import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacidade e Termos',
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Sua Privacidade é Nossa Prioridade'),
            _buildParagraph(
              'O RunLab: Performance e Treino foi desenvolvido com uma filosofia de "Privacidade em Primeiro Lugar". Diferente de outros aplicativos de corrida, não exigimos criação de conta e não armazenamos seus dados em nossos servidores.',
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('1. Coleta de Dados Locais'),
            _buildParagraph(
              'Todas as informações que você insere no aplicativo (nome, idade, peso, altura) e todos os seus registros de treino são armazenados exclusivamente na memória do seu dispositivo (Android/iOS).',
            ),
            _buildParagraph(
              'Você tem total controle sobre esses dados e pode apagá-los ou exportá-los a qualquer momento através da aba de Perfil.',
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('2. Uso de Localização (GPS)'),
            _buildParagraph(
              'Para medir sua distância, ritmo e traçar sua rota no mapa, o RunLab solicita acesso à sua localização precisa. ',
            ),
            _buildParagraph(
              '• Estes dados são processados apenas enquanto você está gravando uma atividade.\n'
              '• O histórico de rotas permanece salvo apenas no seu dispositivo.\n'
              '• Nós nunca compartilhamos sua localização com terceiros ou anunciantes.',
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('3. Monetização e Publicidade'),
            _buildParagraph(
              'Para manter o RunLab gratuito e em constante desenvolvimento, exibimos anúncios através do Google AdMob. ',
            ),
            _buildParagraph(
              '• Os anúncios são exibidos de forma a não interferir na sua corrida.\n'
              '• O Google AdMob pode coletar identificadores de publicidade para exibir anúncios mais relevantes.\n'
              '• Nenhum dado de sua localização ou perfil de treino é compartilhado com o serviço de anúncios.',
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('4. Serviços de Terceiros'),
            _buildParagraph(
              'O RunLab utiliza o Google Maps SDK para exibir mapas. Ao utilizar as funcionalidades de mapa, você também está sujeito à Política de Privacidade do Google.',
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('4. Mudanças e Contato'),
            _buildParagraph(
              'Como não coletamos e-mails, não podemos notificá-lo sobre mudanças nesta política. Recomendamos revisar esta seção periodicamente.',
            ),
            const SizedBox(height: 48),
            Center(
              child: Text(
                'Última atualização: Março de 2026',
                style: GoogleFonts.outfit(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.backgroundDarkGreen,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 15,
          color: Colors.black87,
          height: 1.5,
        ),
      ),
    );
  }
}
