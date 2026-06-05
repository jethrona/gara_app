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
    final safeName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final path = 'consultations/$patientId/images/$safeName';
    await _supabase.client.storage.from('media').uploadBinary(
      path,
      imageBytes,
      fileOptions: const FileOptions(
        contentType: 'image/jpeg',
        upsert: true,
      ),
    );
    return _supabase.client.storage.from('media').getPublicUrl(path);
  }

  Future<String> uploadVoice({
    required Uint8List voiceBytes,
    required String patientId,
    required String fileName,
  }) async {
    final safeName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final path = 'consultations/$patientId/voice/$safeName';
    final ext = fileName.split('.').last.toLowerCase();
    final contentType = switch (ext) {
      'webm' => 'audio/webm',
      'ogg' => 'audio/ogg',
      'wav' => 'audio/wav',
      _ => 'audio/aac',
    };
    await _supabase.client.storage.from('media').uploadBinary(
      path,
      voiceBytes,
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: true,
      ),
    );
    return _supabase.client.storage.from('media').getPublicUrl(path);
  }

  Future<String> uploadPdf({
    required Uint8List pdfBytes,
    required String patientId,
    required String fileName,
  }) async {
    final safeName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final path = 'documents/$patientId/$safeName';
    await _supabase.client.storage.from('clinical_documents').uploadBinary(
      path,
      pdfBytes,
      fileOptions: const FileOptions(
        contentType: 'application/pdf',
        upsert: true,
      ),
    );
    return _supabase.client.storage.from('clinical_documents').getPublicUrl(path);
  }
}
