import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/constants.dart';

class AIService {
  late final GenerativeModel _model;

  AIService() {
    _model = GenerativeModel(
      model: 'models/gemini-1.5-flash',
      apiKey: AppConstants.geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.3,
        topP: 0.8,
        topK: 40,
        maxOutputTokens: 1024,
      ),
    );
  }

  Future<String> generateClinicalBrief({
    required String biologicalSex,
    required String severityLevel,
    required String durationSymptoms,
    required String symptomCategory,
    required String symptomDescription,
    required String patientName,
  }) async {
    final prompt = '''
You are a medical triage AI assistant for the Gara Telemedicine Platform. Generate a concise, objective clinical brief in English based on the following patient-reported information.

Patient: $patientName
Biological Sex: $biologicalSex
Symptom Category: $symptomCategory
Severity Level: $severityLevel
Duration of Symptoms: $durationSymptoms
Patient's Description: $symptomDescription

Format your response as follows:

CLINICAL BRIEF:
- Presenting Complaint: [1-2 sentence summary]
- Duration: [summary]
- Severity Assessment: [assessment]
- Key Symptoms: [bullet points]
- Recommended Action: [recommendation]

Keep the response professional, objective, and under 250 words. Do not provide a diagnosis - only summarize the reported symptoms.
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? 'AI brief generation failed. Please review patient input manually.';
    } catch (e) {
      return 'Unable to generate AI brief at this time.';
    }
  }
}
