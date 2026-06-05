import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class StorageService {
  final SupabaseService _supabase = SupabaseService();

  Future<String> uploadImage({
    required Uint8List imageBytes,
    required String patientId,
    required String fileName,
  }) async {
    final path = 'consultations/$patientId/images/$fileName';
    await _supabase.client.storage.from('media').uploadBinary(
      path,
      imageBytes,
      fileOptions: const FileOptions(contentType: 'image/jpeg'),
    );
    return _supabase.client.storage.from('media').getPublicUrl(path);
  }

  Future<String> uploadVoice({
    required Uint8List voiceBytes,
    required String patientId,
    required String fileName,
  }) async {
    final path = 'consultations/$patientId/voice/$fileName';
    await _supabase.client.storage.from('media').uploadBinary(
      path,
      voiceBytes,
      fileOptions: const FileOptions(contentType: 'audio/mp4'),
    );
    return _supabase.client.storage.from('media').getPublicUrl(path);
  }

  Future<String> uploadPdf({
    required Uint8List pdfBytes,
    required String patientId,
    required String fileName,
  }) async {
    final path = 'documents/$patientId/$fileName';
    await _supabase.client.storage.from('clinical_documents').uploadBinary(
      path,
      pdfBytes,
      fileOptions: const FileOptions(contentType: 'application/pdf'),
    );
    return _supabase.client.storage.from('clinical_documents').getPublicUrl(path);
  }
}
