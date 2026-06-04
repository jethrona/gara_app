import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/constants.dart';
import '../models/profile_model.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../services/error_handler.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final SupabaseService _supabaseService = SupabaseService();

  bool _isLoading = false;
  bool _isLoggedIn = false;
  bool _isDoctor = false;
  bool _hasBiometrics = false;
  bool _biometricEnabled = false;
  bool _hasPin = false;
  bool _rememberMe = false;
  String? _errorMessage;
  ProfileModel? _profile;
  User? _user;
  String _lastPhone = '';

  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  bool get isDoctor => _isDoctor;
  bool get hasBiometrics => _hasBiometrics;
  bool get biometricEnabled => _biometricEnabled;
  bool get hasPin => _hasPin;
  bool get rememberMe => _rememberMe;
  String? get errorMessage => _errorMessage;
  ProfileModel? get profile => _profile;
  User? get user => _user;
  String get lastPhone => _lastPhone;

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

    final session = _supabaseService.client.auth.currentSession;
    if (session != null) {
      _user = session.user;
      if (_user != null) {
        _profile = await _authService.getProfile(_user!.id);
        _isLoggedIn = true;
        _isDoctor = _profile?.isDoctor ?? false;
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> tryAutoLogin() async {
    final creds = await _authService.getRememberedCredentials();
    if (creds == null) return false;

    final phone = creds['phone']!;
    final password = creds['password']!;

    try {
      final response = await _authService.loginWithEmailPassword(phone, password);
      if (response.user != null) {
        _user = response.user;
        _lastPhone = phone;
        _profile = await _authService.getProfile(_user!.id);
        _isLoggedIn = true;
        _isDoctor = _profile?.isDoctor ?? false;
        notifyListeners();
        return true;
      }
    } catch (_) {}

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

      final response = await _authService.registerWithEmailPassword(phoneNumber, password);

      if (response.user == null) {
        _isLoading = false;
        _setError('Failed to create account');
        notifyListeners();
        return _errorMessage;
      }

      _user = response.user;
      _lastPhone = phoneNumber;

      _profile = await _authService.createProfile(
        id: _user!.id,
        phoneNumber: phoneNumber,
        fullName: fullName,
      );

      _isLoggedIn = true;
      _isDoctor = false;

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
      final response = await _authService.loginWithEmailPassword(phoneNumber, password);

      if (response.user == null) {
        _isLoading = false;
        _setError('Invalid credentials');
        notifyListeners();
        return _errorMessage;
      }

      _user = response.user;
      _lastPhone = phoneNumber;
      _profile = await _authService.getProfile(_user!.id);
      _isLoggedIn = true;
      _isDoctor = _profile?.isDoctor ?? false;

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

      final response = await _authService.registerWithEmailPassword(phoneNumber, password);

      if (response.user == null) {
        _isLoading = false;
        _setError('Failed to create account');
        notifyListeners();
        return _errorMessage;
      }

      _user = response.user;
      _lastPhone = phoneNumber;

      _profile = await _authService.createProfile(
        id: _user!.id,
        phoneNumber: phoneNumber,
        fullName: fullName,
        isDoctor: true,
      );

      _isLoggedIn = true;
      _isDoctor = true;

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

  Future<String?> sendPasswordResetEmail(String phone) async {
    try {
      await _authService.sendPasswordResetEmail(phone);
      return null;
    } catch (e) {
      return ErrorHandler.friendly(e.toString());
    }
  }

  Future<String?> verifyAndResetPassword(String phone, String pin) async {
    final storedPin = await _authService.getStoredPin();
    if (storedPin == null) return 'No PIN set on this device. Use the device where you registered.';
    if (pin != storedPin) return 'Wrong PIN';

    final creds = await _authService.getRememberedCredentials();
    if (creds != null && creds['phone'] == phone) {
      return null;
    }

    try {
      final response = await _supabaseService.client
          .from('profiles')
          .select('id')
          .eq('phone_number', phone)
          .maybeSingle();

      if (response == null) return 'No account found with this phone number';
      return null;
    } catch (_) {
      return 'Could not verify account. Try again later.';
    }
  }

  Future<String?> resetPasswordWithPin(String newPassword) async {
    if (newPassword.length < 6) {
      return 'Password must be at least 6 characters';
    }
    try {
      final session = _supabaseService.client.auth.currentSession;
      if (session != null) {
        await _authService.updatePassword(newPassword);
        if (_rememberMe) {
          final creds = await _authService.getRememberedCredentials();
          if (creds != null) {
            await _authService.saveRememberedCredentials(creds['phone']!, newPassword);
          }
        }
        return null;
      }

      final creds = await _authService.getRememberedCredentials();
      if (creds != null) {
        await _authService.loginWithEmailPassword(creds['phone']!, creds['password']!);
        await _authService.updatePassword(newPassword);
        await _authService.saveRememberedCredentials(creds['phone']!, newPassword);
        return null;
      }

      return 'Cannot reset password while logged out. Sign in first, or use a device where you checked "Remember me".';
    } catch (e) {
      return ErrorHandler.friendly(e.toString());
    }
  }

  Future<void> updateProfile({String? fullName, String? avatarUrl}) async {
    if (_user == null) return;

    try {
      await _authService.updateProfile(
        id: _user!.id,
        fullName: fullName,
        avatarUrl: avatarUrl,
      );

      _profile = await _authService.getProfile(_user!.id);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<String?> uploadAvatar(File imageFile) async {
    if (_user == null) return null;

    try {
      final url = await _authService.uploadAvatar(
        imageFile: imageFile,
        userId: _user!.id,
      );
      await updateProfile(avatarUrl: url);
      return url;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    await _authService.clearRememberedCredentials();
    _user = null;
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
