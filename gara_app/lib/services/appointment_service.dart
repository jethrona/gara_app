import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/appointment_model.dart';
import 'supabase_service.dart';

class AppointmentService {
  final SupabaseService _supabase = SupabaseService();

  Future<AppointmentModel> createAppointment({
    required String patientId,
    required String doctorId,
    required DateTime requestedDate,
    String? notes,
  }) async {
    final response = await _supabase.client
        .from('appointments')
        .insert({
          'patient_id': patientId,
          'doctor_id': doctorId,
          'requested_date': requestedDate.toUtc().toIso8601String(),
          if (notes != null) 'notes': notes,
        })
        .select()
        .single();
    return AppointmentModel.fromMap(response);
  }

  Future<List<AppointmentModel>> getDoctorAppointments(String doctorId) async {
    final response = await _supabase.client
        .from('appointments')
        .select('''
          *,
          patient:patient_id(full_name)
        ''')
        .eq('doctor_id', doctorId)
        .order('requested_date', ascending: false);
    return (response as List).map((e) {
      final map = Map<String, dynamic>.from(e);
      if (e['patient'] != null) map['patient_name'] = e['patient']['full_name'];
      return AppointmentModel.fromMap(map);
    }).toList();
  }

  Future<List<AppointmentModel>> getPatientAppointments(String patientId) async {
    final response = await _supabase.client
        .from('appointments')
        .select('''
          *,
          doctor:doctor_id(full_name)
        ''')
        .eq('patient_id', patientId)
        .order('requested_date', ascending: false);
    return (response as List).map((e) {
      final map = Map<String, dynamic>.from(e);
      if (e['doctor'] != null) map['doctor_name'] = e['doctor']['full_name'];
      return AppointmentModel.fromMap(map);
    }).toList();
  }

  Future<void> updateAppointmentStatus({
    required int appointmentId,
    required String status,
  }) async {
    await _supabase.client
        .from('appointments')
        .update({
          'status': status,
          'responded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', appointmentId);
  }

  RealtimeChannel subscribeToDoctorAppointments({
    required String doctorId,
    required Function(AppointmentModel) onAppointment,
  }) {
    final channel = _supabase.client.channel('appointments-doctor-$doctorId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      table: 'appointments',
      schema: 'public',
      callback: (payload) {
        final record = payload.newRecord;
        if (record['doctor_id'] == doctorId) {
          onAppointment(AppointmentModel.fromMap(record));
        }
      },
    ).subscribe();
    return channel;
  }

  RealtimeChannel subscribeToPatientAppointments({
    required String patientId,
    required Function(AppointmentModel) onAppointment,
  }) {
    final channel = _supabase.client.channel('appointments-patient-$patientId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      table: 'appointments',
      schema: 'public',
      callback: (payload) {
        final record = payload.newRecord;
        if (record['patient_id'] == patientId) {
          onAppointment(AppointmentModel.fromMap(record));
        }
      },
    ).subscribe();
    return channel;
  }
}
