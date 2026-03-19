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

  bool get adsEnabled => _adsEnabled;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _adsEnabled = prefs.getBool('dev_ads_enabled') ?? true;

    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (_isInitialized || !_adsEnabled) return;
    
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
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
      } catch (e) {
        debugPrint('AdService initialization failed: $e');
      }
    }
  }

  // IDs de teste oficiais do Google
  String get bannerAdUnitId {
    if (!_adsEnabled) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-8578901708699710/9471050199';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716';
    }
    return '';
  }

  // IDs de anúncios premiados (opcional para o futuro)
  String get rewardedAdUnitId {
    if (!_adsEnabled) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313';
    }
    return '';
  }
}
