import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/profile_model.dart';
import '../services/auth_service.dart';
import '../services/error_handler.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isLoggedIn = false;
  bool _isDoctor = false;
  bool _hasBiometrics = false;
  bool _biometricEnabled = false;
  bool _hasPin = false;
  bool _rememberMe = false;
  String? _errorMessage;
  ProfileModel? _profile;
  String _userId = '';
  String _lastPhone = '';
  int _avatarVersion = 0;

  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  bool get isDoctor => _isDoctor;
  bool get hasBiometrics => _hasBiometrics;
  bool get biometricEnabled => _biometricEnabled;
  bool get hasPin => _hasPin;
  bool get rememberMe => _rememberMe;
  String? get errorMessage => _errorMessage;
  ProfileModel? get profile => _profile;
  String get userId => _userId;
  String get lastPhone => _lastPhone;
  int get avatarVersion => _avatarVersion;

  void setRememberMe(bool v) {
    _rememberMe = v;
    notifyListeners();
  }

  void _setError(String? raw) {
    _errorMessage = ErrorHandler.friendly(raw);
    notifyListeners();
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    _hasBiometrics = await _authService.hasBiometrics();
    _biometricEnabled = await _authService.isBiometricEnabled();
    _hasPin = await _authService.hasPin();

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();

    final profile = await _authService.autoLogin();
    if (profile != null) {
      _userId = profile.id;
      _profile = profile;
      _isLoggedIn = true;
      _isDoctor = profile.isDoctor;
      _isLoading = false;
      notifyListeners();
      return true;
    }

    final creds = await _authService.getRememberedCredentials();
    if (creds != null) {
      final loginProfile = await _authService.login(creds['phone']!, creds['password']!);
      if (loginProfile != null) {
        _userId = loginProfile.id;
        _profile = loginProfile;
        _isLoggedIn = true;
        _isDoctor = loginProfile.isDoctor;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> authenticateWithBiometrics() async {
    final success = await _authService.authenticateWithBiometrics();
    if (success) {
      await _authService.setBiometricEnabled(true);
      _biometricEnabled = true;
      notifyListeners();
    }
    return success;
  }

  Future<bool> verifyPin(String pin) async {
    return await _authService.verifyPin(pin);
  }

  Future<String?> savePin(String pin) async {
    if (pin.length < 4) return 'PIN must be at least 4 digits';
    await _authService.savePin(pin);
    _hasPin = true;
    notifyListeners();
    return null;
  }

  Future<String?> registerPatient({
    required String phoneNumber,
    required String fullName,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (password.length < 6) {
        _isLoading = false;
        _errorMessage = 'Password must be at least 6 characters';
        notifyListeners();
        return _errorMessage;
      }

      final exists = await _authService.phoneExists(phoneNumber);
      if (exists) {
        final loginResult = await _authService.login(phoneNumber, password);
        if (loginResult != null) {
          _userId = loginResult.id;
          _profile = loginResult;
          _isLoggedIn = true;
          _isDoctor = loginResult.isDoctor;
          _lastPhone = phoneNumber;
          if (_rememberMe) {
            await _authService.saveRememberedCredentials(phoneNumber, password);
          }
          _isLoading = false;
          notifyListeners();
          return null;
        }
        _isLoading = false;
        _setError('An account with this phone number already exists. Try logging in instead.');
        notifyListeners();
        return _errorMessage;
      }

      final profile = await _authService.register(
        phone: phoneNumber,
        password: password,
        fullName: fullName,
      );

      _userId = profile.id;
      _profile = profile;
      _isLoggedIn = true;
      _isDoctor = false;
      _lastPhone = phoneNumber;

      if (_rememberMe) {
        await _authService.saveRememberedCredentials(phoneNumber, password);
      }

      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      _setError(e.toString());
      notifyListeners();
      return _errorMessage;
    }
  }

  Future<String?> loginPatient({
    required String phoneNumber,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final profile = await _authService.login(phoneNumber, password);

      if (profile == null) {
        _isLoading = false;
        _setError('Wrong phone number or password');
        notifyListeners();
        return _errorMessage;
      }

      _userId = profile.id;
      _profile = profile;
      _isLoggedIn = true;
      _isDoctor = profile.isDoctor;
      _lastPhone = phoneNumber;

      if (_rememberMe) {
        await _authService.saveRememberedCredentials(phoneNumber, password);
      }

      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      _setError(e.toString());
      notifyListeners();
      return _errorMessage;
    }
  }

  Future<String?> registerDoctor({
    required String phoneNumber,
    required String fullName,
    required String registrationToken,
    required String password,
  }) async {
    if (registrationToken != AppConstants.doctorRegistrationToken) {
      return 'Invalid doctor registration token';
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final alreadyRegistered = await _authService.isDoctorAlreadyRegistered();
      if (alreadyRegistered) {
        _isLoading = false;
        _setError('A doctor is already registered. Only one doctor account is allowed.');
        notifyListeners();
        return _errorMessage;
      }

      final exists = await _authService.phoneExists(phoneNumber);
      if (exists) {
        final loginResult = await _authService.login(phoneNumber, password);
        if (loginResult != null) {
          _userId = loginResult.id;
          _profile = loginResult;
          _isLoggedIn = true;
          _isDoctor = true;
          _lastPhone = phoneNumber;
          if (_rememberMe) {
            await _authService.saveRememberedCredentials(phoneNumber, password);
          }
          _isLoading = false;
          notifyListeners();
          return null;
        }
        _isLoading = false;
        _setError('An account with this phone number already exists. Try logging in instead.');
        notifyListeners();
        return _errorMessage;
      }

      final profile = await _authService.register(
        phone: phoneNumber,
        password: password,
        fullName: fullName,
        isDoctor: true,
      );

      _userId = profile.id;
      _profile = profile;
      _isLoggedIn = true;
      _isDoctor = true;
      _lastPhone = phoneNumber;

      if (_rememberMe) {
        await _authService.saveRememberedCredentials(phoneNumber, password);
      }

      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      _setError(e.toString());
      notifyListeners();
      return _errorMessage;
    }
  }

  Future<String?> verifyAndResetPassword(String phone, String pin) async {
    final storedPin = await _authService.getStoredPin();
    if (storedPin == null) return 'No PIN set on this device. Use the device where you registered.';
    if (pin != storedPin) return 'Wrong PIN';

    final exists = await _authService.phoneExists(phone);
    if (!exists) {
      return 'No account found with this phone number';
    }
    return null;
  }

  Future<String?> resetPassword({
    required String phone,
    required String oldPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) {
      return 'Password must be at least 6 characters';
    }
    try {
      final profile = await _authService.login(phone, oldPassword);
      if (profile == null) {
        return 'Wrong current password';
      }
      await _authService.updatePassword(profile.id, newPassword);
      if (_rememberMe) {
        await _authService.saveRememberedCredentials(phone, newPassword);
      }
      return null;
    } catch (e) {
      return ErrorHandler.friendly(e.toString());
    }
  }

  Future<void> updateProfile({String? fullName, String? avatarUrl}) async {
    if (_userId.isEmpty) return;
    try {
      await _authService.updateProfile(
        id: _userId,
        fullName: fullName,
        avatarUrl: avatarUrl,
      );
      _profile = await _authService.getProfile(_userId);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> updateDoctorSettings({
    required int consultationFee,
    required String fullName,
    required String phoneNumber,
    String? clinicName,
  }) async {
    if (_userId.isEmpty) return;
    try {
      final payload = <String, dynamic>{
        'id': _userId,
        'full_name': fullName.trim(),
        'clinic_name': (clinicName?.trim().isNotEmpty == true) ? clinicName!.trim() : null,
        'phone_number': phoneNumber.trim(),
        'consultation_fee': consultationFee,
      };
      debugPrint('[AuthProvider] updateDoctorSettings upsert: $payload');
      final result = await SupabaseService().client
          .from('profiles')
          .upsert(payload, onConflict: 'id')
          .select()
          .maybeSingle();
      if (result != null) {
        _profile = ProfileModel.fromMap(result);
        notifyListeners();
        debugPrint('[AuthProvider] Doctor settings saved: name=$fullName, phone=$phoneNumber, fee=$consultationFee');
      } else {
        debugPrint('[AuthProvider] WARNING: upsert returned null (RLS may be blocking)');
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<String?> uploadAvatar(Uint8List imageBytes, {String extension = 'jpg'}) async {
    if (_userId.isEmpty) return 'Not logged in';
    try {
      final url = await _authService.uploadAvatar(
        imageBytes: imageBytes,
        userId: _userId,
        extension: extension,
      );
      await updateProfile(avatarUrl: url);
      _avatarVersion++;
      notifyListeners();
      return null; // null = success
    } catch (e) {
      _setError(e.toString());
      return ErrorHandler.friendly(e.toString());
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _userId = '';
    _profile = null;
    _isLoggedIn = false;
    _isDoctor = false;
    _isLoading = false;
    _lastPhone = '';
    _rememberMe = false;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
