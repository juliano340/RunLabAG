import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  bool _isInitialized = false;
  bool _adsEnabled = true;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;

  RewardedAd? _rewardedAd;
  bool _isRewardedReady = false;

  bool get adsEnabled => _adsEnabled;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _adsEnabled = prefs.getBool('dev_ads_enabled') ?? true;

    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (_isInitialized || !_adsEnabled) return;

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      loadInterstitialAd();
      loadRewardedAd();
    } catch (e) {
      debugPrint('AdService initialization failed: $e');
    }
  }

  Future<void> setAdsEnabled(bool enabled) async {
    _adsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dev_ads_enabled', enabled);

    if (enabled && !_isInitialized && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await MobileAds.instance.initialize();
        _isInitialized = true;
        loadInterstitialAd();
        loadRewardedAd();
      } catch (e) {
        debugPrint('AdService initialization failed: $e');
      }
    }
  }

  // ──────────────────────────────────────────────
  // IDs de anúncio
  // ──────────────────────────────────────────────

  String get bannerAdUnitId {
    if (!_adsEnabled) return '';
    if (Platform.isAndroid) return 'ca-app-pub-8578901708699710/9471050199';
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/2934735716';
    return '';
  }

  String get interstitialAdUnitId {
    if (!_adsEnabled) return '';
    if (Platform.isAndroid) return 'ca-app-pub-8578901708699710/4763822846'; // produção
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/4411468910'; // teste iOS
    return '';
  }

  String get rewardedAdUnitId {
    if (!_adsEnabled) return '';
    if (Platform.isAndroid) return 'ca-app-pub-8578901708699710/8729719095'; // produção
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/1712485313'; // teste iOS
    return '';
  }

  // ──────────────────────────────────────────────
  // Interstitial
  // ──────────────────────────────────────────────

  void loadInterstitialAd() {
    if (!_adsEnabled || !_isInitialized) return;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialReady = true;
          _interstitialAd!.setImmersiveMode(true);
        },
        onAdFailedToLoad: (error) {
          _isInterstitialReady = false;
          debugPrint('Interstitial failed to load: $error');
        },
      ),
    );
  }

  /// Exibe o interstitial se estiver pronto. Chama [onAdDismissed] após fechar
  /// (seja por assistir ou por fechar). Use para encadear a navegação após o ad.
  void showInterstitialAd({required VoidCallback onAdDismissed}) {
    if (!_adsEnabled || !_isInterstitialReady || _interstitialAd == null) {
      onAdDismissed();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialReady = false;
        loadInterstitialAd(); // Pré-carrega o próximo
        onAdDismissed();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialReady = false;
        loadInterstitialAd();
        onAdDismissed();
      },
    );

    _interstitialAd!.show();
    _interstitialAd = null;
    _isInterstitialReady = false;
  }

  // ──────────────────────────────────────────────
  // Rewarded
  // ──────────────────────────────────────────────

  void loadRewardedAd() {
    if (!_adsEnabled || !_isInitialized) return;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedReady = true;
        },
        onAdFailedToLoad: (error) {
          _isRewardedReady = false;
          debugPrint('Rewarded ad failed to load: $error');
        },
      ),
    );
  }

  /// Exibe o rewarded ad.
  /// [onRewarded]: chamado quando o usuário assiste e ganha a recompensa.
  /// [onDismissed]: chamado sempre que o ad fecha (com ou sem recompensa).
  void showRewardedAd({
    required VoidCallback onRewarded,
    required VoidCallback onDismissed,
  }) {
    if (!_adsEnabled || !_isRewardedReady || _rewardedAd == null) {
      // Sem ad disponível: não concede recompensa
      onDismissed();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _isRewardedReady = false;
        loadRewardedAd(); // Pré-carrega o próximo
        onDismissed();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _isRewardedReady = false;
        loadRewardedAd();
        onDismissed();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        onRewarded();
      },
    );
    _rewardedAd = null;
    _isRewardedReady = false;
  }

  bool get isRewardedAdReady => _isRewardedReady && _adsEnabled;
}
