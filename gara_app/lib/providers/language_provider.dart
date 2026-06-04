import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LanguageProvider extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _langKey = 'gara_language';

  Locale _locale = const Locale('en');
  bool _isKinyarwanda = false;

  Locale get locale => _locale;
  bool get isKinyarwanda => _isKinyarwanda;

  Future<void> init() async {
    final saved = await _secureStorage.read(key: _langKey);
    if (saved == 'rw') {
      _locale = const Locale('rw');
      _isKinyarwanda = true;
      notifyListeners();
    }
  }

  Future<void> toggleLanguage() async {
    if (_isKinyarwanda) {
      _locale = const Locale('en');
      _isKinyarwanda = false;
      await _secureStorage.write(key: _langKey, value: 'en');
    } else {
      _locale = const Locale('rw');
      _isKinyarwanda = true;
      await _secureStorage.write(key: _langKey, value: 'rw');
    }
    notifyListeners();
  }

  String t(String en, String rw) {
    return _isKinyarwanda ? rw : en;
  }
}
