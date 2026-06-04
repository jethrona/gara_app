import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/constants.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  Future<void> init() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  }

  RealtimeChannel getConsultationChannel(int consultationId) {
    return client
        .channel('consultation-$consultationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          table: 'messages',
          schema: 'public',
          callback: (payload) {},
        )
        .subscribe();
  }

  RealtimeChannel getDoctorDashboardChannel() {
    return client
        .channel('doctor-dashboard')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          table: 'consultations',
          schema: 'public',
          callback: (payload) {},
        )
        .subscribe();
  }
}
