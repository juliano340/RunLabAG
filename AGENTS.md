# RunLab AG — Contexto para Codex

## Projeto
App Flutter de rastreamento de corridas (Android/iOS). Arquitetura por features com Provider para estado global.

## Stack
- Flutter + Dart (null safety)
- Provider (ThemeService, WaterProvider, StrengthWorkoutProvider)
- sqflite (banco local)
- google_mobile_ads (banner + intersticial + rewarded)
- google_fonts (Outfit)
- lucide_icons

## Estrutura de telas (IndexedStack no MainScreen)
```
MainScreen (IndexedStack, índices 0–3)
  [0] HomeTab
  [1] HistoryTab
  [2] RecordsTab
  [3] ProfileTab
```
Todas as abas ficam vivas na árvore o tempo todo — mudanças de tema causam rebuild em todas elas simultaneamente.

## ThemeService
- Usa `Timer` com `cancel()` para debounce (NÃO usar Future.delayed acumulado)
- `bool _isToggling` controla se o switch está desabilitado
- Cooldown: 300ms
- Sempre cancelar o timer anterior antes de criar um novo

## Bugs já corrigidos (não regredir)

### GlobalKey conflict no Switch de tema / IndexedStack
**Sintoma**: Erro `Duplicate GlobalKey detected in widget tree` (tipo `_InkFeatures`) na aba de Recordes após alternar tema rapidamente.

**Causa**: O `IndexedStack` mantém as abas vivas. Quando o tema muda, todos os widgets `Material` tentam atualizar seus "Ink Surfaces" simultaneamente. Se houver chaves globais envolvidas (mesmo internas do framework), ocorre colisão.

**Correção Definitiva (v5.0)**: Resetar atomicamente o `Scaffold` principal usando o brilho do tema como chave. Isso limpa todos os resíduos de renderização antigos.

```dart
// lib/features/dashboard/presentation/screens/main_screen.dart
Scaffold(
  key: ValueKey(Theme.of(context).brightness),
  ...
)
```
> [!IMPORTANT]
> Se o erro de "Red Screen" no tema voltar, verifique se o Scaffold do MainScreen ainda possui essa chave dinâmica. Ela é o que garante a estabilidade do app.

### Overflow no cabeçalho do RecordsTab
**Causa**: `Row` com título "Recordes Pessoais" (28sp) + badge de conquistas sem `Expanded` — ultrapassava a largura em telas de 360dp.

**Correção**: Envolver o `Column` do título em `Expanded` + `SizedBox(width: 12)` antes do badge.

## GlassContainer
- `enableBlur: true` por padrão usa `BackdropFilter` (efeito glass visível em dark mode — fundo é 20% opacidade verde)
- Em light mode o blur não é visível (fundo opaco `cardLight`)
- NÃO desabilitar o blur em RecordsTab — o efeito é intencional em dark mode

## AdBannerWidget
- `const AdBannerWidget()` no MainScreen — estado preservado entre rebuilds
- Usa `AdWidget(ad: _bannerAd!)` da google_mobile_ads — tem platform view interna
- Não tem GlobalKey explícita no código do app

## Convenções
- `PageStorageKey` nas ScrollViews das abas para preservar posição de scroll
- `context.watch<ThemeService>()` apenas dentro de `Builder` para evitar rebuild da aba inteira
- Dados do usuário: `DatabaseService` (sqflite), `UserProfile` model
- Distâncias monitoradas padrão: [1.0, 5.0, 10.0, 15.0] km

## Imported Claude Cowork project instructions

Esse é um projeto de monitoramento de treinos e quero fazer como um dashboard de performance pessoal
