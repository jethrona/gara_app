import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/profile_model.dart';
import 'supabase_service.dart';

class AuthService {
  final SupabaseService _supabase = SupabaseService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final Random _random = Random.secure();
  final Uuid _uuid = const Uuid();

  static const String _sessionKey = 'gara_session_token';
  static const String _userIdKey = 'gara_user_id';
  static const String _pinKey = 'gara_pin_code';
  static const String _biometricEnabledKey = 'gara_biometric_enabled';
  static const String _rememberPhoneKey = 'gara_remember_phone';
  static const String _rememberPasswordKey = 'gara_remember_password';

  // ── Biometrics / PIN ──

  Future<bool> hasBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your Gara account',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBiometricEnabled() async {
    final v = await _secureStorage.read(key: _biometricEnabledKey);
    return v == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _secureStorage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  Future<bool> hasPin() async {
    final pin = await _secureStorage.read(key: _pinKey);
    return pin != null && pin.isNotEmpty;
  }

  Future<void> savePin(String pin) async {
    await _secureStorage.write(key: _pinKey, value: pin);
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _secureStorage.read(key: _pinKey);
    return stored == pin;
  }

  Future<String?> getStoredPin() async {
    return await _secureStorage.read(key: _pinKey);
  }

  // ── Password hashing ──

  String _generateSalt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64.encode(bytes);
  }

  String _hashPassword(String password, String salt) {
    return sha256.convert(utf8.encode(password + salt)).toString();
  }

  // ── Session management ──

  Future<void> _saveSession(String userId, String token) async {
    await _secureStorage.write(key: _sessionKey, value: token);
    await _secureStorage.write(key: _userIdKey, value: userId);
  }

  Future<String?> _getStoredUserId() async {
    return await _secureStorage.read(key: _userIdKey);
  }

  Future<String?> _getStoredSessionToken() async {
    return await _secureStorage.read(key: _sessionKey);
  }

  Future<void> _clearSession() async {
    await _secureStorage.delete(key: _sessionKey);
    await _secureStorage.delete(key: _userIdKey);
  }

  // ── Public auth API ──

  Future<ProfileModel> register({
    required String phone,
    required String password,
    required String fullName,
    bool isDoctor = false,
  }) async {
    final salt = _generateSalt();
    final hash = _hashPassword(password, salt);
    final sessionToken = _uuid.v4();
    final userId = _uuid.v4();

    final response = await _supabase.client.from('profiles').insert({
      'id': userId,
      'phone_number': phone,
      'full_name': fullName,
      'is_doctor': isDoctor,
      'password_hash': hash,
      'password_salt': salt,
      'session_token': sessionToken,
    }).select().single();

    await _saveSession(userId, sessionToken);
    return ProfileModel.fromMap(response);
  }

  Future<ProfileModel?> login(String phone, String password) async {
    final response = await _supabase.client
        .from('profiles')
        .select()
        .eq('phone_number', phone)
        .limit(1);

    final list = response as List;
    if (list.isEmpty) return null;

    final profile = ProfileModel.fromMap(list.first);
    final storedHash = list.first['password_hash'] as String?;
    final storedSalt = list.first['password_salt'] as String?;

    if (storedHash == null || storedSalt == null) return null;

    final computedHash = _hashPassword(password, storedSalt);
    if (computedHash != storedHash) return null;

    final sessionToken = _uuid.v4();
    await _supabase.client
        .from('profiles')
        .update({'session_token': sessionToken})
        .eq('id', profile.id);

    await _saveSession(profile.id, sessionToken);
    return profile;
  }

  Future<ProfileModel?> autoLogin() async {
    final token = await _getStoredSessionToken();
    final userId = await _getStoredUserId();
    if (token == null || userId == null) return null;

    final response = await _supabase.client
        .from('profiles')
        .select()
        .eq('id', userId)
        .eq('session_token', token)
        .limit(1);

    final list = response as List;
    if (list.isEmpty) return null;

    return ProfileModel.fromMap(list.first);
  }

  Future<void> signOut() async {
    final userId = await _getStoredUserId();
    if (userId != null) {
      await _supabase.client
          .from('profiles')
          .update({'session_token': null})
          .eq('id', userId);
    }
    await _clearSession();
    await clearRememberedCredentials();
  }

  Future<ProfileModel?> getProfile(String userId) async {
    try {
      final response = await _supabase.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return ProfileModel.fromMap(response);
    } catch (_) {
      return null;
    }
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
    } catch (_) {
      return false;
    }
  }

  Future<bool> phoneExists(String phone) async {
    final response = await _supabase.client
        .from('profiles')
        .select('id')
        .eq('phone_number', phone)
        .limit(1);
    return (response as List).isNotEmpty;
  }

  Future<void> updatePassword(String userId, String newPassword) async {
    final salt = _generateSalt();
    final hash = _hashPassword(newPassword, salt);
    await _supabase.client.from('profiles').update({
      'password_hash': hash,
      'password_salt': salt,
    }).eq('id', userId);
  }

  // ── Avatar upload ──

  Future<String> uploadAvatar({
    required Uint8List imageBytes,
    required String userId,
    String extension = 'jpg',
  }) async {
    final path = 'avatars/$userId.$extension';
    await _supabase.client.storage.from('media').uploadBinary(
      path,
      imageBytes,
      fileOptions: FileOptions(
        contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
        upsert: true,
      ),
    );
    return _supabase.client.storage.from('media').getPublicUrl(path);
  }

  // ── Remember me ──

  Future<void> saveRememberedCredentials(String phone, String password) async {
    await _secureStorage.write(key: _rememberPhoneKey, value: phone);
    await _secureStorage.write(key: _rememberPasswordKey, value: password);
  }

  Future<Map<String, String>?> getRememberedCredentials() async {
    final phone = await _secureStorage.read(key: _rememberPhoneKey);
    final password = await _secureStorage.read(key: _rememberPasswordKey);
    if (phone != null && password != null) return {'phone': phone, 'password': password};
    return null;
  }

  Future<void> clearRememberedCredentials() async {
    await _secureStorage.delete(key: _rememberPhoneKey);
    await _secureStorage.delete(key: _rememberPasswordKey);
  }
}
