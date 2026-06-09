import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/consultation_model.dart';
import 'supabase_service.dart';

class ConsultationService {
  final SupabaseService _supabase = SupabaseService();

  Future<ConsultationModel> createConsultation({
    required String patientId,
    required String biologicalSex,
    required String severityLevel,
    required String durationSymptoms,
    String? symptomCategory,
    String? symptomDescription,
    String? aiBriefSummary,
  }) async {
    final consultation = ConsultationModel(
      patientId: patientId,
      biologicalSex: biologicalSex,
      severityLevel: severityLevel,
      durationSymptoms: durationSymptoms,
      symptomCategory: symptomCategory,
      symptomDescription: symptomDescription,
      aiBriefSummary: aiBriefSummary,
    );

    final response = await _supabase.client
        .from('consultations')
        .insert(consultation.toMap())
        .select()
        .single();

    return ConsultationModel.fromMap(response);
  }

  Future<List<ConsultationModel>> getPatientConsultations(String patientId) async {
    final response = await _supabase.client
        .from('consultations')
        .select()
        .eq('patient_id', patientId)
        .order('created_at', ascending: false);

    return (response as List).map((e) => ConsultationModel.fromMap(e)).toList();
  }

  Future<List<ConsultationModel>> getDoctorConsultationsByStatus(CareStatus status) async {
    final statusStr = _statusToDbString(status);
    final response = await _supabase.client
        .from('consultations')
        .select('''
          *,
          patient:patient_id(
            full_name,
            phone_number
          )
        ''')
        .eq('status', statusStr)
        .order('created_at', ascending: false);

    return (response as List).map((e) {
      final map = Map<String, dynamic>.from(e);
      if (map['patient'] != null) {
        map['patient_name'] = map['patient']['full_name'];
        map['patient_phone'] = map['patient']['phone_number'];
      }
      map.remove('patient');
      return ConsultationModel.fromMap(map);
    }).toList();
  }

  Future<void> updateConsultationStatus(int consultationId, CareStatus status) async {
    await _supabase.client
        .from('consultations')
        .update({
          'status': _statusToDbString(status),
          if (status == CareStatus.complete) 'closed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', consultationId);
  }

  Future<bool> verifyPayment({
    required int consultationId,
    required String transactionId,
    required double amount,
  }) async {
    final existing = await _supabase.client
        .from('consultations')
        .select('status, momo_transaction_id')
        .eq('id', consultationId)
        .maybeSingle();

    if (existing == null) return false;

    if (existing['status'] == 'in_process' ||
        existing['status'] == 'complete') {
      return false;
    }

    final res = await _supabase.client
        .from('consultations')
        .update({
          'momo_transaction_id': transactionId.isEmpty ? 'MANUAL-${DateTime.now().millisecondsSinceEpoch}' : transactionId,
          'payment_amount': amount,
          'status': 'in_process',
          'paid_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', consultationId)
        .eq('status', 'pending_payment')
        .select();

    return (res as List).isNotEmpty;
  }

  Future<void> updateAiBrief(int consultationId, String brief) async {
    await _supabase.client
        .from('consultations')
        .update({'ai_brief_summary': brief})
        .eq('id', consultationId);
  }

  Future<ConsultationModel?> getConsultation(int id) async {
    try {
      final response = await _supabase.client
          .from('consultations')
          .select()
          .eq('id', id)
          .single();
      return ConsultationModel.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getDoctorStats() async {
    try {
      final response = await _supabase.client
          .from('consultations')
          .select('status, payment_amount, paid_at')
          .inFilter('status', ['in_process', 'complete']);

      final list = response as List;
      final now = DateTime.now().toUtc();

      double incomeForDate(DateTime date) {
        return list
            .where((c) {
              final paidAt = c['paid_at'] != null
                  ? DateTime.tryParse(c['paid_at'] as String)?.toUtc()
                  : null;
              if (paidAt == null || c['payment_amount'] == null) return false;
              return paidAt.year == date.year &&
                  paidAt.month == date.month &&
                  paidAt.day == date.day;
            })
            .fold<double>(0.0, (sum, c) => sum + ((c['payment_amount'] as num?)?.toDouble() ?? 0.0));
      }

      double incomeForMonth(int year, int month) {
        return list
            .where((c) {
              final paidAt = c['paid_at'] != null
                  ? DateTime.tryParse(c['paid_at'] as String)?.toUtc()
                  : null;
              if (paidAt == null || c['payment_amount'] == null) return false;
              return paidAt.year == year && paidAt.month == month;
            })
            .fold<double>(0.0, (sum, c) => sum + ((c['payment_amount'] as num?)?.toDouble() ?? 0.0));
      }

      final activePatients = list.where((c) => c['status'] == 'in_process').length;

      return {
        'totalPatients': list.length,
        'activePatients': activePatients,
        'todayIncome': incomeForDate(now),
        'monthlyIncome': incomeForMonth(now.year, now.month),
      };
    } catch (e) {
      return {
        'totalPatients': 0,
        'activePatients': 0,
        'todayIncome': 0.0,
        'monthlyIncome': 0.0,
      };
    }
  }

  RealtimeChannel subscribeToConsultations({
    required Function(Map<String, dynamic>) onUpsert,
    String? filterStatus,
  }) {
    final channelName = 'consultations-${DateTime.now().millisecondsSinceEpoch}';
    final channel = _supabase.client.channel(channelName);

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      table: 'consultations',
      schema: 'public',
      callback: (payload) {
        onUpsert(Map<String, dynamic>.from(payload.newRecord));
      },
    ).subscribe();

    return channel;
  }

  String _statusToDbString(CareStatus status) {
    switch (status) {
      case CareStatus.pendingPayment:
        return 'pending_payment';
      case CareStatus.inProcess:
        return 'in_process';
      case CareStatus.complete:
        return 'complete';
    }
  }
}
