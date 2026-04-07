# RunLab — Log de Implementação: Fases 0 e 1

**Data:** 2026-04-06
**Versão base:** 1.0.2+3
**Objetivo:** Ativar analytics, crashlytics e novos formatos de anúncio para gerar dados e receita.

---

## FASE 0 — Observabilidade (Analytics + Crashlytics)

### Por que foi feito

Sem dados de comportamento, qualquer decisão sobre o produto é chute. A Fase 0 instala os "olhos" do app: saber onde os usuários chegam, o que fazem e quando o app quebra.

---

### 1. Novas dependências (`pubspec.yaml`)

```yaml
firebase_analytics: ^11.4.4
firebase_crashlytics: ^4.2.0
```

**O que fazem:**
- `firebase_analytics`: grava eventos de uso no Firebase Analytics (painel gratuito no Firebase Console).
- `firebase_crashlytics`: captura crashes automaticamente e os envia ao Firebase, com stack trace, dispositivo e versão do app.

---

### 2. Configuração Gradle (`android/settings.gradle.kts`, `android/app/build.gradle.kts`)

Adicionados os plugins do Google:

```kotlin
// settings.gradle.kts
id("com.google.gms.google-services") version "4.4.2" apply false
id("com.google.firebase.crashlytics") version "3.0.3" apply false

// app/build.gradle.kts
id("com.google.gms.google-services")
id("com.google.firebase.crashlytics")
```

**Por que necessário:** O Firebase Android precisa que esses plugins processem o `google-services.json` em tempo de build para injetar as credenciais do projeto.

> **AÇÃO MANUAL NECESSÁRIA:**
> Baixe o `google-services.json` do Firebase Console (Configurações do projeto → Seus apps → Android) e coloque em `android/app/google-services.json`. Sem esse arquivo, o build falhará.

---

### 3. Novo serviço: `lib/core/services/analytics_service.dart`

Singleton que centraliza todos os eventos de analytics. Princípio: **nenhuma tela deve importar `firebase_analytics` diretamente** — tudo passa por aqui, facilitando trocas futuras.

**Eventos implementados:**

| Evento | Onde é disparado | O que mede |
|--------|-----------------|------------|
| `run_started` | Início de corrida | Quantos usuários iniciam corridas |
| `run_completed` | Ao salvar treino | Quantos completam (vs. abandonam) |
| `run_discarded` | Ao descartar treino | Taxa de abandono |
| `share_created` | Ao gerar card | Engajamento com compartilhamento |
| `premium_template_unlocked` | Ao assistir rewarded ad | Conversão de templates |
| `achievement_unlocked` | Ao ganhar conquista | Retenção / gamificação |
| `ad_interstitial_shown` | Após salvar treino | Impressões de interstitial |
| `ad_rewarded_shown` | Ao tentar template premium | Impressões de rewarded |

**Crashlytics:**
- `setUserId`: correlaciona crashes com usuários anônimos (sem PII)
- `setCustomKey`: para adicionar contexto (ex: tela atual)
- `recordError`: para erros não-fatais em fluxos de fallback

---

### 4. Inicialização no `main.dart`

```dart
await Firebase.initializeApp();

// Captura erros Flutter (ex: setState após dispose)
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

// Captura erros assíncronos fora do framework
PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  return true;
};
```

Também gera um `user_analytics_id` anônimo e persistente por dispositivo, para que o Firebase possa agrupar eventos do mesmo usuário entre sessões sem usar dados pessoais.

---

### 5. Instrumentação no `active_run_screen.dart`

- **`logRunStarted`**: disparado ao chamar `_startRun()`, registra o tipo de corrida (com meta de distância ou livre).
- **`logRunCompleted`**: disparado após `dbService.saveRun(run)`, registra distância, duração, pace, calorias, tipo e humor.
- **`logAchievementUnlocked`**: disparado para cada conquista nova desbloqueada no mesmo fluxo.

---

## FASE 1 — Monetização com Novos Formatos de Anúncio

### Por que foi feito

O banner (único formato ativo antes) tem o menor CPM de todos os formatos. O usuário ignora banner depois de 2 dias de uso. Os formatos interstitial e rewarded têm CPM 5x–15x maior e são contextualizados na ação do usuário.

---

### 6. Expansão do `AdService` (`lib/core/services/ad_service.dart`)

**Novos métodos:**

#### `loadInterstitialAd()` / `showInterstitialAd({required VoidCallback onAdDismissed})`

- Pré-carrega o interstitial em background ao inicializar o app.
- `showInterstitialAd` recebe um callback `onAdDismissed` — a navegação acontece **dentro do callback**, garantindo que o usuário sempre saia da tela, mesmo se o ad falhar.
- Após exibir, já pré-carrega o próximo (garante disponibilidade para a próxima sessão de treino).

#### `loadRewardedAd()` / `showRewardedAd({required VoidCallback onRewarded, required VoidCallback onDismissed})`

- Dois callbacks separados: `onRewarded` (usuário assistiu completo) e `onDismissed` (fechou, com ou sem recompensa).
- `isRewardedAdReady` getter público para verificar disponibilidade antes de mostrar o botão de desbloquear.

> **IDs de anúncio:**
> Interstitial e Rewarded usam IDs de **teste** do Google. Após aprovação do AdMob:
> - Criar unidades de anúncio do tipo "Intersticial" e "Recompensado" no painel AdMob
> - Substituir as constantes `interstitialAdUnitId` e `rewardedAdUnitId` pelos IDs de produção

---

### 7. Interstitial após salvar treino (`active_run_screen.dart`)

**Fluxo:**
1. Usuário toca "SALVAR TREINO"
2. Treino é salvo no SQLite
3. Conquistas são verificadas
4. SnackBar de parabéns (se houver)
5. **Interstitial é exibido** (tela cheia, 1x por sessão de treino)
6. Usuário fecha o interstitial → `Navigator.pop()` volta ao dashboard

**Por que esse momento:** É o pico de satisfação do ciclo de uso. O usuário acabou de completar algo. Tolerância a anúncio nesse momento é a mais alta. Nunca interrompe durante a corrida.

---

### 8. Templates premium com Rewarded Ad (`run_share_screen.dart`)

**Templates gratuitos:** Boxed, Centralizado
**Templates premium (rewarded):** Barra Inferior, Minimalista, Vertical Moderno

**Fluxo quando usuário tenta template premium:**
1. Dialog explicando que é premium e oferece troca por vídeo
2. Usuário toca "ASSISTIR" → rewarded ad é exibido
3. Se assistir completo → template desbloqueado **para a sessão atual**
4. Se ad indisponível → template liberado mesmo assim (não bloqueia o usuário, evita reviews ruins)

**Indicação visual:** botão "ESTILO" no carousel mostra ícone de cadeado âmbar quando o próximo template é premium e ainda não foi desbloqueado.

**Log:** `premium_template_unlocked` com nome do template — permite medir qual template converte mais.

---

## Resumo dos arquivos modificados

| Arquivo | Tipo de mudança |
|---------|----------------|
| `pubspec.yaml` | +2 dependências Firebase |
| `android/settings.gradle.kts` | +2 plugins Google/Crashlytics |
| `android/app/build.gradle.kts` | +2 plugins aplicados ao app |
| `lib/main.dart` | Inicialização Firebase + Crashlytics handlers |
| `lib/core/services/analytics_service.dart` | **NOVO** — serviço de analytics |
| `lib/core/services/ad_service.dart` | +Interstitial, +Rewarded |
| `lib/features/run/presentation/screens/active_run_screen.dart` | +Analytics, +Interstitial pós-save |
| `lib/features/run/presentation/screens/run_share_screen.dart` | +Premium templates, +Rewarded, +Analytics |

---

## Próximos passos obrigatórios antes de publicar

1. **`google-services.json`**: Baixar do Firebase Console → `android/app/google-services.json`
   - Sem ele, o Firebase não inicializa mas o **app continua funcionando normalmente**
   - Analytics e Crashlytics só ficam ativos depois de adicionar o arquivo
2. **IDs de produção AdMob**: Criar unidades no AdMob e substituir os IDs de teste em `AdService`
3. **`flutter pub get`**: Instalar as novas dependências
4. **Testar em device físico**: Crashlytics e ads não funcionam em emulador para produção
5. **Verificar política de anúncios**: Confirmar que interstitial após treino está em conformidade com as políticas do AdMob para apps fitness

## Nota sobre inicialização defensiva

O `AnalyticsService` usa inicialização defensiva: se o Firebase falhar por qualquer motivo
(sem `google-services.json`, sem internet no primeiro boot, etc.), o app não quebra.
Todos os métodos verificam `_isInitialized` antes de agir. O build e o fluxo do app
funcionam 100% sem Firebase configurado.

---

## O que monitorar nos primeiros 7 dias

No Firebase Analytics, acompanhar:

- **Funil**: `run_started` → `run_completed` (taxa de conclusão)
- **Engajamento**: `share_created` por usuário ativo
- **Receita**: `ad_interstitial_shown` e `ad_rewarded_shown` (volume)
- **Conversão rewarded**: `premium_template_unlocked` / `ad_rewarded_shown` (% que assiste completo)
- **Crashlytics**: zero crashes novos introduzidos

Se a taxa `run_started` → `run_completed` for < 60%, há algo no fluxo de finalização que merece investigação antes de escalar aquisição de usuários.
