import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacidade e Termos',
          style: GoogleFonts.outfit(
            color: cs.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context, 'Sua Privacidade é Nossa Prioridade'),
            _buildParagraph(
              context,
              'O RunLab: Performance e Treino foi desenvolvido com uma filosofia de "Privacidade em Primeiro Lugar". Não exigimos criação de conta e seus treinos não são sincronizados com uma nuvem do RunLab.',
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(context, '1. Coleta de Dados Locais'),
            _buildParagraph(
              context,
              'Todas as informações que você insere no aplicativo (nome, idade, peso, altura) e todos os seus registros de treino são armazenados exclusivamente no armazenamento local do seu dispositivo (Android/iOS).',
            ),
            _buildParagraph(
              context,
              'Você tem total controle sobre esses dados e pode apagá-los ou exportá-los a qualquer momento através da aba de Perfil.',
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(context, '2. Uso de Localização (GPS)'),
            _buildParagraph(
              context,
              'Para medir sua distância, ritmo e traçar sua rota no mapa, o RunLab solicita acesso à sua localização precisa. ',
            ),
            _buildParagraph(
              context,
              '• Estes dados são processados apenas enquanto você está gravando uma atividade.\n'
              '• O histórico de rotas permanece salvo apenas no seu dispositivo.\n'
              '• Nós nunca compartilhamos sua localização com terceiros ou anunciantes.',
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(context, '3. Monetização e Publicidade'),
            _buildParagraph(
              context,
              'Para manter o RunLab gratuito e em constante desenvolvimento, exibimos anúncios através do Google AdMob. ',
            ),
            _buildParagraph(
              context,
              '• Os anúncios são exibidos de forma a não interferir na sua corrida.\n'
              '• O Google AdMob pode coletar identificadores de publicidade para exibir anúncios mais relevantes.\n'
              '• Nenhum dado de sua localização ou perfil de treino é compartilhado com o serviço de anúncios.',
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(context, '4. Serviços de Terceiros'),
            _buildParagraph(
              context,
              'O RunLab utiliza o Google Maps SDK para exibir mapas, o Google AdMob para anúncios e o Firebase Analytics/Crashlytics para métricas de uso e diagnóstico de falhas. Ao utilizar o aplicativo, você também está sujeito às políticas de privacidade desses serviços.',
            ),
            _buildParagraph(
              context,
              '• O Analytics pode receber distância, duração, ritmo, calorias, tipo e humor do treino, além de eventos de uso e conquistas.\n'
              '• Rotas, coordenadas GPS, nome, idade, peso e altura não são enviados nesses eventos.\n'
              '• O Crashlytics recebe informações técnicas do dispositivo e detalhes de erros para ajudar na estabilidade.\n'
              '• O AdMob pode coletar identificadores de publicidade. Esses dados não são usados pelo RunLab para reconstruir sua rota ou perfil de treino.',
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(context, '5. Mudanças e Contato'),
            _buildParagraph(
              context,
              'Como não coletamos e-mails, não podemos notificá-lo sobre mudanças nesta política. Recomendamos revisar esta seção periodicamente.',
            ),
            const SizedBox(height: 48),
            Center(
              child: Text(
                'Última atualização: Novembro de 2026',
                style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildSectionTitle(BuildContext context, String title) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: cs.primary,
        ),
      ),
    );
  }

  Widget _buildParagraph(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 15,
          color: cs.onSurfaceVariant,
          height: 1.5,
        ),
      ),
    );
  }
}
