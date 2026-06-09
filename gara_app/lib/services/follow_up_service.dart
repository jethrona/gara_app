import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/follow_up_model.dart';
import 'supabase_service.dart';

class FollowUpService {
  final SupabaseService _supabase = SupabaseService();

  Future<FollowUpModel> createFollowUp({
    required int consultationId,
    required String doctorId,
    required String patientId,
    required String doctorMessage,
  }) async {
    final response = await _supabase.client
        .from('follow_ups')
        .insert({
          'consultation_id': consultationId,
          'doctor_id': doctorId,
          'patient_id': patientId,
          'doctor_message': doctorMessage,
        })
        .select()
        .single();
    return FollowUpModel.fromMap(response);
  }

  Future<List<FollowUpModel>> getDoctorFollowUps(String doctorId) async {
    final response = await _supabase.client
        .from('follow_ups')
        .select('''
          *,
          doctor:doctor_id(full_name),
          patient:patient_id(full_name)
        ''')
        .eq('doctor_id', doctorId)
        .order('created_at', ascending: false);
    return (response as List).map((e) {
      final map = Map<String, dynamic>.from(e);
      if (e['doctor'] != null) map['doctor_name'] = e['doctor']['full_name'];
      if (e['patient'] != null) map['patient_name'] = e['patient']['full_name'];
      return FollowUpModel.fromMap(map);
    }).toList();
  }

  Future<List<FollowUpModel>> getPatientFollowUps(String patientId) async {
    final response = await _supabase.client
        .from('follow_ups')
        .select('''
          *,
          doctor:doctor_id(full_name),
          patient:patient_id(full_name)
        ''')
        .eq('patient_id', patientId)
        .order('created_at', ascending: false);
    return (response as List).map((e) {
      final map = Map<String, dynamic>.from(e);
      if (e['doctor'] != null) map['doctor_name'] = e['doctor']['full_name'];
      if (e['patient'] != null) map['patient_name'] = e['patient']['full_name'];
      return FollowUpModel.fromMap(map);
    }).toList();
  }

  Future<void> submitReply({
    required int followUpId,
    required String patientReply,
  }) async {
    await _supabase.client
        .from('follow_ups')
        .update({
          'patient_reply': patientReply,
          'replied_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', followUpId);
  }

  Future<int> getUnrepliedCount(String patientId) async {
    final response = await _supabase.client
        .from('follow_ups')
        .select('id')
        .eq('patient_id', patientId)
        .filter('patient_reply', 'is', 'null');
    return (response as List).length;
  }

  RealtimeChannel subscribeToDoctorFollowUps({
    required String doctorId,
    required Function(FollowUpModel) onFollowUp,
  }) {
    final channel = _supabase.client.channel('follow-ups-doctor-$doctorId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      table: 'follow_ups',
      schema: 'public',
      callback: (payload) {
        final record = payload.newRecord;
        if (record['doctor_id'] == doctorId) {
          onFollowUp(FollowUpModel.fromMap(record));
        }
      },
    ).subscribe();
    return channel;
  }

  RealtimeChannel subscribeToPatientFollowUps({
    required String patientId,
    required Function(FollowUpModel) onFollowUp,
  }) {
    final channel = _supabase.client.channel('follow-ups-patient-$patientId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      table: 'follow_ups',
      schema: 'public',
      callback: (payload) {
        final record = payload.newRecord;
        if (record['patient_id'] == patientId) {
          onFollowUp(FollowUpModel.fromMap(record));
        }
      },
    ).subscribe();
    return channel;
  }

  RealtimeChannel subscribeToReply({
    required int followUpId,
    required Function(FollowUpModel) onReply,
  }) {
    final channel = _supabase.client.channel('follow-up-reply-$followUpId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      table: 'follow_ups',
      schema: 'public',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: followUpId,
      ),
      callback: (payload) {
        onReply(FollowUpModel.fromMap(payload.newRecord));
      },
    ).subscribe();
    return channel;
  }
}
