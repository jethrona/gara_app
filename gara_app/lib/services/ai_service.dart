import 'package:supabase_flutter/supabase_flutter.dart';

class AIService {
  Future<String> generateClinicalBrief({
    required String biologicalSex,
    required String severityLevel,
    required String durationSymptoms,
    required String symptomCategory,
    required String symptomDescription,
    required String patientName,
  }) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'generate-ai-brief',
        body: {
          'biologicalSex': biologicalSex,
          'severityLevel': severityLevel,
          'durationSymptoms': durationSymptoms,
          'symptomCategory': symptomCategory,
          'symptomDescription': symptomDescription,
          'patientName': patientName,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data['brief'] != null) return data['brief'] as String;
        final err = data['details'] ?? data['error'] ?? 'unknown error';
        return 'AI brief generation failed ($err).';
      }
      return 'AI brief generation failed.';
    } catch (e) {
      return 'Unable to generate AI brief at this time';
    }
  }
}
