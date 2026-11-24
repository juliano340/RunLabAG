# RunLabAG

**Português (Brasil)** · [English](README.en.md)

RunLabAG é um aplicativo Flutter de acompanhamento de corridas e performance pessoal. Ele combina rastreamento GPS, histórico, recordes e análises em um dashboard pessoal, com dados armazenados localmente no aparelho.

## Funcionalidades

- Rastreamento GPS com rota colorida por ritmo e suavização visual;
- Início normal e início expresso da corrida;
- Pausa manual, autopausa e retomada automática;
- Registro e edição manual de treinos;
- Desenho de rotas por toque ou traço livre;
- Histórico com navegação entre treinos;
- Recordes pessoais e distâncias monitoradas;
- Análises semanais, mensais e comparativos entre períodos;
- Compartilhamento de treinos com múltiplos estilos;
- Backup e restauração local dos dados.

## Stack

- Flutter e Dart
- Provider para gerenciamento de estado
- sqflite para persistência local
- Google Maps e geolocator
- google_mobile_ads
- Firebase Analytics e Crashlytics
- lucide_icons
- Fontes Outfit, Space Grotesk e Inter incluídas no aplicativo

## Estrutura do projeto

```text
lib/
├── app/
│   └── composition_root.dart
├── core/
│   ├── data/repositories/
│   ├── domain/models/
│   ├── domain/repositories/
│   ├── domain/services/
│   ├── services/
│   └── widgets/
└── features/
    ├── run/
    │   ├── application/
    │   ├── data/
    │   └── domain/
    ├── history/
    ├── dashboard/
    ├── analytics/
    ├── profile/
    ├── onboarding/
    └── strength_training/
```

## Arquitetura

- `app/composition_root.dart` monta o grafo de dependências uma única vez;
- `RunSessionController` concentra GPS, timer, autopausa, splits e persistência,
  enquanto `ActiveRunScreen` cuida apenas de UI, mapa e navegação;
- Repositórios são consumidos por interfaces no domínio, com implementações
  sqflite e decorators de cache na camada de dados;
- `ReadModelCache` compartilha resumos, perfil, recordes e estatísticas entre as
  abas, com single-flight e invalidação após escritas;
- Atualizações de corrida são separadas em tick de 1 s, estado estrutural e rota.

## Pré-requisitos

- Flutter SDK 3.41 ou superior
- Android Studio ou VS Code
- Dispositivo Android ou emulador

## Configuração

1. Instale as dependências:

   ```bash
   flutter pub get
   ```

2. Configure a chave do Google Maps em `android/local.properties`:

   ```properties
   MAPS_API_KEY=sua_chave_aqui
   ```

3. Para habilitar os serviços do Firebase, adicione seu arquivo
   `android/app/google-services.json`. Esse arquivo não é versionado.

4. Para gerar builds de release assinados, crie `android/key.properties`
   com os dados da sua keystore. Esse arquivo não é versionado.

## Executando

```bash
flutter run
```

No Android, o aplicativo solicita as permissões de localização, notificação e
armazenamento necessárias para rastreamento e backup automático.

## Build de release

```bash
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols
```

O APK arm64 é gerado em:

```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Testes

```bash
flutter test
flutter analyze
```

## Dados e backup

Os treinos e o perfil são armazenados localmente com sqflite. Quando o backup
automático está ativo e a permissão de armazenamento foi concedida, os arquivos
são salvos em:

```text
/Download/RunLab/
```

A restauração de backup pode ser feita pela tela de perfil.
