class AppConstants {
  static const String appName = 'Gara';
  static const String supabaseUrl = 'https://fwlfokriptbrpwxmgshu.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ3bGZva3JpcHRicnB3eG1nc2h1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1NTM1OTEsImV4cCI6MjA5NjEyOTU5MX0.zYL-CxpxtX1OUmMpL38go1jW1qV9zcRSm7EPifNxeJg';
  static const String doctorRegistrationToken =
      String.fromEnvironment('DOCTOR_REGISTRATION_TOKEN', defaultValue: 'GARA_DOCTOR_2024');

  static const String momoNumber = '0784405943';
  static const double consultationFee = 2000.0;
  static const String currency = 'RWF';

  static const String smsSenderId = 'MOMO';

  static const List<String> biologicalSexOptions = ['Male', 'Female'];

  static const Map<String, String> biologicalSexRw = {
    'Male': 'Gabo',
    'Female': 'Gore',
  };

  static const List<String> severityOptions = [
    'Mild – No immediate concern',
    'Moderate – Needs attention soon',
    'Severe – Urgent',
  ];

  static const Map<String, String> severityRw = {
    'Mild': 'Cyoroheje',
    'Moderate': 'Giciriritse',
    'Severe': 'Gikomeye',
  };

  static const List<String> durationOptions = [
    'Just started (Today)',
    'Few days (1-3 days)',
    'About a week (4-7 days)',
    'More than a week (1-2 weeks)',
    'Long-term (2+ weeks)',
  ];

  static const Map<String, String> durationRw = {
    'Just started (Today)': 'Byatangiye (Uyu munsi)',
    'Few days (1-3 days)': 'Iminsi mike (1-3)',
    'About a week (4-7 days)': 'Hafi yicyumweru (4-7)',
    'More than a week (1-2 weeks)': 'Icyumweru kirusha (1-2)',
    'Long-term (2+ weeks)': 'Igihe kirekire (2+)',
  };

  static const List<String> symptomCategories = [
    'Fever',
    'Flu',
    'Headache',
    'Migraine',
    'Stomach & Digestive',
    'Chest & Breathing',
    'Skin',
    'Allergies',
    'Muscle & Joint',
    'Urinary',
    'Kidney',
    'Eye',
    'Ear',
    'Dental',
    'Mouth',
    'Mental Health',
    'Injury & Trauma',
    'Other',
  ];

  static const Map<String, String> symptomCategoryRw = {
    'Fever': 'Umusanzu',
    'Flu': 'Ibicurane',
    'Headache': 'Umutwe',
    'Migraine': 'Migraine',
    'Stomach & Digestive': 'Igifu n\'Igogoka',
    'Chest & Breathing': 'Igituza n\'Umuherero',
    'Skin': 'Uruhu',
    'Allergies': 'Allergies',
    'Muscle & Joint': 'Imitsi n\'Ingingo',
    'Urinary': 'Inkari',
    'Kidney': 'Impyiko',
    'Eye': 'Amaso',
    'Ear': 'Ugatugu',
    'Dental': 'Amenyo',
    'Mouth': 'Umunwa',
    'Mental Health': 'Ubuzima bwo mu mutwe',
    'Injury & Trauma': 'Gukomereka',
    'Other': 'Ibindi',
  };
}
