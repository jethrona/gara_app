import 'package:flutter/foundation.dart';
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

      debugPrint('[AIService] response.status=${response.status}');
      debugPrint('[AIService] response.data=${response.data}');

      final data = response.data;

      if (data is Map<String, dynamic>) {
        if (data['brief'] != null) {
          return data['brief'] as String;
        }
        final errDetail = data['details'] ?? data['error'] ?? 'unknown error';
        debugPrint('[AIService] Edge Function error: $errDetail');
        return 'AI brief generation failed: $errDetail';
      }

      debugPrint('[AIService] Unexpected response type: ${data.runtimeType}');
      return 'AI brief generation failed (unexpected response format).';

    } on FunctionException catch (e) {
      debugPrint('[AIService] FunctionException: status=${e.status} details=${e.details}');
      final detail = e.details?.toString() ?? e.toString();
      return 'AI brief generation failed: $detail';
    } catch (e) {
      debugPrint('[AIService] Unexpected error: $e');
      return 'Unable to generate AI brief at this time ($e).';
    }
  }
}
