import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/consultation_model.dart';
import '../services/consultation_service.dart';
import '../services/ai_service.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';

class ConsultationProvider extends ChangeNotifier {
  final ConsultationService _consultationService = ConsultationService();
  final AIService _aiService = AIService();

  bool _isLoading = false;
  String? _errorMessage;
  ConsultationModel? _currentConsultation;
  List<ConsultationModel> _patientConsultations = [];
  List<ConsultationModel> _pendingPayments = [];
  List<ConsultationModel> _inProcess = [];
  List<ConsultationModel> _completed = [];
  Map<String, dynamic> _doctorStats = {
    'totalPatients': 0,
    'todayIncome': 0.0,
    'monthlyIncome': 0.0,
  };
  RealtimeChannel? _realtimeChannel;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ConsultationModel? get currentConsultation => _currentConsultation;
  List<ConsultationModel> get patientConsultations => _patientConsultations;
  List<ConsultationModel> get pendingPayments => _pendingPayments;
  List<ConsultationModel> get inProcess => _inProcess;
  List<ConsultationModel> get completed => _completed;
  Map<String, dynamic> get doctorStats => _doctorStats;

  Future<ConsultationModel?> submitTriage({
    required String patientId,
    required String biologicalSex,
    required String severityLevel,
    required String durationSymptoms,
    required String symptomCategory,
    required String symptomDescription,
    required String patientName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String? aiBrief;
      try {
        aiBrief = await _aiService.generateClinicalBrief(
          biologicalSex: biologicalSex,
          severityLevel: severityLevel,
          durationSymptoms: durationSymptoms,
          symptomCategory: symptomCategory,
          symptomDescription: symptomDescription,
          patientName: patientName,
        );
      } catch (e) {
        aiBrief = 'AI synthesis unavailable. Manual review required.';
      }

      _currentConsultation = await _consultationService.createConsultation(
        patientId: patientId,
        biologicalSex: biologicalSex,
        severityLevel: severityLevel,
        durationSymptoms: durationSymptoms,
        aiBriefSummary: aiBrief,
      );

      _notifyDoctorOfNewConsultation(patientName, _currentConsultation!.id);

      _isLoading = false;
      notifyListeners();
      return _currentConsultation;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> loadPatientConsultations(String patientId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _patientConsultations = await _consultationService.getPatientConsultations(patientId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadDoctorQueues() async {
    _isLoading = true;
    notifyListeners();

    try {
      _pendingPayments = await _consultationService
          .getDoctorConsultationsByStatus(CareStatus.pendingPayment);
      _inProcess = await _consultationService
          .getDoctorConsultationsByStatus(CareStatus.inProcess);
      _completed = await _consultationService
          .getDoctorConsultationsByStatus(CareStatus.complete);
      _doctorStats = await _consultationService.getDoctorStats();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateConsultationStatus(int consultationId, CareStatus status) async {
    try {
      await _consultationService.updateConsultationStatus(consultationId, status);
      await loadDoctorQueues();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> verifyPayment({
    required int consultationId,
    required String transactionId,
    required double amount,
  }) async {
    try {
      await _consultationService.updatePaymentInfo(
        consultationId: consultationId,
        transactionId: transactionId,
        amount: amount,
      );
      await loadDoctorQueues();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<ConsultationModel?> getConsultationById(int id) async {
    try {
      return await _consultationService.getConsultation(id);
    } catch (e) {
      return null;
    }
  }

  void startRealtimeListener() {
    _realtimeChannel = _consultationService.subscribeToConsultations(
      onUpsert: (data) {
        loadDoctorQueues();
      },
    );
  }

  void disposeRealtime() {
    _realtimeChannel?.unsubscribe();
  }

  Future<void> _notifyDoctorOfNewConsultation(String patientName, int? consultationId) async {
    try {
      final doctorResponse = await SupabaseService().client
          .from('profiles')
          .select('id')
          .eq('is_doctor', true)
          .limit(1)
          .maybeSingle();

      if (doctorResponse != null) {
        final doctorId = doctorResponse['id'] as String;
        final notifService = NotificationService();
        await notifService.createNotification(
          userId: doctorId,
          title: 'New Consultation #$consultationId',
          body: '$patientName submitted a new consultation.',
          type: 'consultation',
        );
      }
    } catch (_) {}
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
