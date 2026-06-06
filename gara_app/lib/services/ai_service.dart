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

      final data = response.data as Map<String, dynamic>?;
      return data?['brief'] as String? ??
          'AI brief generation failed. Please review patient input manually.';
    } catch (e) {
      return 'Unable to generate AI brief at this time.';
    }
  }
}
