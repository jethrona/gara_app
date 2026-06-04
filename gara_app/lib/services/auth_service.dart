import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import 'supabase_service.dart';

class AuthService {
  final SupabaseService _supabase = SupabaseService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _deviceTokenKey = 'gara_device_token';
  static const String _pinKey = 'gara_pin_code';
  static const String _profileKey = 'gara_profile_cache';
  static const String _biometricEnabledKey = 'gara_biometric_enabled';
  static const String _rememberPhoneKey = 'gara_remember_phone';
  static const String _rememberPasswordKey = 'gara_remember_password';

  Future<bool> hasBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your Gara account',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  Future<bool> isBiometricEnabled() async {
    final val = await _secureStorage.read(key: _biometricEnabledKey);
    return val == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _secureStorage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  Future<String?> getDeviceToken() async {
    return await _secureStorage.read(key: _deviceTokenKey);
  }

  Future<void> saveDeviceToken(String token) async {
    await _secureStorage.write(key: _deviceTokenKey, value: token);
  }

  Future<bool> hasPin() async {
    final pin = await _secureStorage.read(key: _pinKey);
    return pin != null && pin.isNotEmpty;
  }

  Future<String?> getStoredPin() async {
    return await _secureStorage.read(key: _pinKey);
  }

  Future<void> savePin(String pin) async {
    await _secureStorage.write(key: _pinKey, value: pin);
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _secureStorage.read(key: _pinKey);
    return stored == pin;
  }

  String _phoneToEmail(String phone) => '$phone@gara.app';

  Future<AuthResponse> registerWithEmailPassword(String phone, String password) async {
    final response = await _supabase.client.auth.signUp(
      email: _phoneToEmail(phone),
      password: password,
    );
    if (response.user != null && response.session == null) {
      try {
        return await loginWithEmailPassword(phone, password);
      } catch (_) {
        throw Exception('Email confirmation required. Please disable "Confirm email" in Supabase Authentication settings, or contact support.');
      }
    }
    return response;
  }

  Future<AuthResponse> loginWithEmailPassword(String phone, String password) async {
    return await _supabase.client.auth.signInWithPassword(
      email: _phoneToEmail(phone),
      password: password,
    );
  }

  Future<ProfileModel> createProfile({
    required String id,
    required String phoneNumber,
    required String fullName,
    bool isDoctor = false,
  }) async {
    final profile = ProfileModel(
      id: id,
      phoneNumber: phoneNumber,
      fullName: fullName,
      isDoctor: isDoctor,
    );

    await _supabase.client.from('profiles').upsert(profile.toMap());
    await _cacheProfile(profile);
    return profile;
  }

  Future<void> updateProfile({
    required String id,
    String? fullName,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    if (updates.isNotEmpty) {
      await _supabase.client.from('profiles').update(updates).eq('id', id);
    }
  }

  Future<bool> isDoctorAlreadyRegistered() async {
    try {
      final response = await _supabase.client
          .from('profiles')
          .select('id')
          .eq('is_doctor', true)
          .limit(1);
      return (response as List).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<ProfileModel?> getProfile(String userId) async {
    try {
      final response = await _supabase.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return ProfileModel.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  Future<void> _cacheProfile(ProfileModel profile) async {
    await _secureStorage.write(key: _profileKey, value: profile.toMap().toString());
  }

  Future<ProfileModel?> getCachedProfile() async {
    return null;
  }

  Future<bool> isSessionActive() async {
    final session = _supabase.client.auth.currentSession;
    return session != null;
  }

  Future<void> saveRememberedCredentials(String phone, String password) async {
    await _secureStorage.write(key: _rememberPhoneKey, value: phone);
    await _secureStorage.write(key: _rememberPasswordKey, value: password);
  }

  Future<Map<String, String>?> getRememberedCredentials() async {
    final phone = await _secureStorage.read(key: _rememberPhoneKey);
    final password = await _secureStorage.read(key: _rememberPasswordKey);
    if (phone != null && password != null) {
      return {'phone': phone, 'password': password};
    }
    return null;
  }

  Future<void> clearRememberedCredentials() async {
    await _secureStorage.delete(key: _rememberPhoneKey);
    await _secureStorage.delete(key: _rememberPasswordKey);
  }

  Future<void> sendPasswordResetEmail(String phone) async {
    await _supabase.client.auth.resetPasswordForEmail(
      _phoneToEmail(phone),
    );
  }

  Future<void> updatePassword(String newPassword) async {
    await _supabase.client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> signOut() async {
    await _supabase.client.auth.signOut();
  }

  Future<User?> getCurrentUser() async {
    return _supabase.client.auth.currentUser;
  }

  Future<String> uploadAvatar({
    required File imageFile,
    required String userId,
  }) async {
    final ext = imageFile.path.split('.').last;
    final path = 'avatars/$userId.$ext';
    await _supabase.client.storage.from('media').upload(
      path,
      imageFile,
      fileOptions: FileOptions(contentType: ext == 'png' ? 'image/png' : 'image/jpeg', upsert: true),
    );
    return _supabase.client.storage.from('media').getPublicUrl(path);
  }
}
