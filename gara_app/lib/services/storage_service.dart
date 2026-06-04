import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class StorageService {
  final SupabaseService _supabase = SupabaseService();

  Future<String> uploadImage({
    required File imageFile,
    required String patientId,
    required String fileName,
  }) async {
    final path = 'consultations/$patientId/images/$fileName';
    await _supabase.client.storage.from('media').upload(
      path,
      imageFile,
      fileOptions: const FileOptions(contentType: 'image/jpeg'),
    );
    return _supabase.client.storage.from('media').getPublicUrl(path);
  }

  Future<String> uploadVoice({
    required File voiceFile,
    required String patientId,
    required String fileName,
  }) async {
    final path = 'consultations/$patientId/voice/$fileName';
    await _supabase.client.storage.from('media').upload(
      path,
      voiceFile,
      fileOptions: const FileOptions(contentType: 'audio/mp4'),
    );
    return _supabase.client.storage.from('media').getPublicUrl(path);
  }

  Future<String> uploadPdf({
    required File pdfFile,
    required String patientId,
    required String fileName,
  }) async {
    final path = 'documents/$patientId/$fileName';
    await _supabase.client.storage.from('clinical_documents').upload(
      path,
      pdfFile,
      fileOptions: const FileOptions(contentType: 'application/pdf'),
    );
    return _supabase.client.storage.from('clinical_documents').getPublicUrl(path);
  }
}
