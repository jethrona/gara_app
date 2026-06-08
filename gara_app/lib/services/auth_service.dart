import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/profile_model.dart';
import 'supabase_service.dart';

// ── Safe storage: uses FlutterSecureStorage on mobile, SharedPreferences on web ──
class _Storage {
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<String?> read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
    try {
      return await _secure.read(key: key);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
  }

  Future<void> write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
      return;
    }
    try {
      await _secure.write(key: key, value: value);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    }
  }

  Future<void> delete(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      return;
    }
    try {
      await _secure.delete(key: key);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    }
  }
}

class AuthService {
  final SupabaseService _supabase = SupabaseService();
  final _Storage _storage = _Storage();
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
    if (kIsWeb) return false;
    try {
      return await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    if (kIsWeb) return false;
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
    final v = await _storage.read(_biometricEnabledKey);
    return v == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(_biometricEnabledKey, enabled.toString());
  }

  Future<bool> hasPin() async {
    final pin = await _storage.read(_pinKey);
    return pin != null && pin.isNotEmpty;
  }

  Future<void> savePin(String pin) async {
    await _storage.write(_pinKey, pin);
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(_pinKey);
    return stored == pin;
  }

  Future<String?> getStoredPin() async {
    return await _storage.read(_pinKey);
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
    await _storage.write(_sessionKey, token);
    await _storage.write(_userIdKey, userId);
  }

  Future<String?> _getStoredUserId() async {
    return await _storage.read(_userIdKey);
  }

  Future<String?> _getStoredSessionToken() async {
    return await _storage.read(_sessionKey);
  }

  Future<void> _clearSession() async {
    await _storage.delete(_sessionKey);
    await _storage.delete(_userIdKey);
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
    String? clinicName,
    String? avatarUrl,
    String? phoneNumber,
    int? consultationFee,
  }) async {
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (clinicName != null) updates['clinic_name'] = clinicName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (phoneNumber != null) updates['phone_number'] = phoneNumber;
    if (consultationFee != null) updates['consultation_fee'] = consultationFee;
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

  // ── Password Reset OTP ──

  /// Generates a 6-digit OTP, stores it + expiry on the profile row,
  /// and returns the OTP code. In production this would be sent via SMS.
  Future<String?> generateResetOtp(String phone) async {
    final response = await _supabase.client
        .from('profiles')
        .select('id')
        .eq('phone_number', phone)
        .limit(1);
    final list = response as List;
    if (list.isEmpty) return null;

    final otp = _random.nextInt(900000) + 100000; // 6 digits
    final expiry = DateTime.now().add(const Duration(minutes: 15)).toIso8601String();

    await _supabase.client
        .from('profiles')
        .update({'reset_otp': otp.toString(), 'reset_otp_expiry': expiry})
        .eq('phone_number', phone);

    debugPrint('[AuthService] OTP for $phone: $otp (expires $expiry)');
    return otp.toString();
  }

  /// Verifies OTP and, if valid, updates the password.
  /// Returns null on success, error message on failure.
  Future<String?> verifyAndResetPassword(
      String phone, String otp, String newPassword) async {
    final response = await _supabase.client
        .from('profiles')
        .select('id, reset_otp, reset_otp_expiry')
        .eq('phone_number', phone)
        .limit(1);
    final list = response as List;
    if (list.isEmpty) return 'No account found with this phone number';

    final row = list.first as Map<String, dynamic>;
    final storedOtp = row['reset_otp'] as String?;
    final expiryStr = row['reset_otp_expiry'] as String?;

    if (storedOtp == null || expiryStr == null) {
      return 'No reset code requested. Please request a new code.';
    }

    if (storedOtp != otp) {
      return 'Wrong reset code. Please try again.';
    }

    final expiry = DateTime.parse(expiryStr);
    if (DateTime.now().isAfter(expiry)) {
      return 'Reset code has expired. Please request a new one.';
    }

    // OTP valid — update password and clear OTP fields
    final userId = row['id'] as String;
    final salt = _generateSalt();
    final hash = _hashPassword(newPassword, salt);
    await _supabase.client.from('profiles').update({
      'password_hash': hash,
      'password_salt': salt,
      'reset_otp': null,
      'reset_otp_expiry': null,
    }).eq('id', userId);

    debugPrint('[AuthService] Password reset successful for $phone');
    return null;
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
    await _storage.write(_rememberPhoneKey, phone);
    await _storage.write(_rememberPasswordKey, password);
  }

  Future<Map<String, String>?> getRememberedCredentials() async {
    final phone = await _storage.read(_rememberPhoneKey);
    final password = await _storage.read(_rememberPasswordKey);
    if (phone != null && password != null) return {'phone': phone, 'password': password};
    return null;
  }

  Future<void> clearRememberedCredentials() async {
    await _storage.delete(_rememberPhoneKey);
    await _storage.delete(_rememberPasswordKey);
  }
}
