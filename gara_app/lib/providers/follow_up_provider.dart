import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/follow_up_model.dart';
import '../services/follow_up_service.dart';
import '../services/notification_service.dart';

class FollowUpProvider extends ChangeNotifier {
  final FollowUpService _service = FollowUpService();
  final NotificationService _notifService = NotificationService();

  List<FollowUpModel> _followUps = [];
  bool _isLoading = false;
  String? _userId;
  bool _isDoctor = false;
  RealtimeChannel? _realtimeChannel;
  RealtimeChannel? _replyChannel;

  List<FollowUpModel> get followUps => _followUps;
  bool get isLoading => _isLoading;

  List<FollowUpModel> get unreplied =>
      _followUps.where((f) => !f.hasReply).toList();

  List<FollowUpModel> get replied =>
      _followUps.where((f) => f.hasReply).toList();

  void initAsDoctor(String doctorId) {
    _userId = doctorId;
    _isDoctor = true;
    _loadDoctorFollowUps(doctorId);
  }

  void initAsPatient(String patientId) {
    _userId = patientId;
    _isDoctor = false;
    _loadPatientFollowUps(patientId);
  }

  Future<void> _loadDoctorFollowUps(String doctorId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _followUps = await _service.getDoctorFollowUps(doctorId);
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = _service.subscribeToDoctorFollowUps(
        doctorId: doctorId,
        onFollowUp: (f) {
          _followUps.insert(0, f);
          notifyListeners();
        },
      );
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadPatientFollowUps(String patientId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _followUps = await _service.getPatientFollowUps(patientId);
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = _service.subscribeToPatientFollowUps(
        patientId: patientId,
        onFollowUp: (f) {
          _followUps.insert(0, f);
          notifyListeners();
        },
      );
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadFollowUps() async {
    if (_userId == null) return;
    if (_isDoctor) {
      await _loadDoctorFollowUps(_userId!);
    } else {
      await _loadPatientFollowUps(_userId!);
    }
  }

  Future<void> createFollowUp({
    required int consultationId,
    required String doctorId,
    required String patientId,
    required String doctorMessage,
    required VoidCallback onNotificationSent,
  }) async {
    final followUp = await _service.createFollowUp(
      consultationId: consultationId,
      doctorId: doctorId,
      patientId: patientId,
      doctorMessage: doctorMessage,
    );
    _followUps.insert(0, followUp);
    notifyListeners();

    await _notifService.createNotification(
      userId: patientId,
      title: 'Follow-up',
      body: 'You have a new follow-up message from your doctor.',
      type: 'follow_up',
    );
    onNotificationSent();
  }

  Future<void> submitReply({
    required int followUpId,
    required String patientReply,
    required String doctorId,
    required VoidCallback onReplied,
  }) async {
    await _service.submitReply(
      followUpId: followUpId,
      patientReply: patientReply,
    );
    final idx = _followUps.indexWhere((f) => f.id == followUpId);
    if (idx != -1) {
      _followUps[idx] = FollowUpModel(
        id: _followUps[idx].id,
        consultationId: _followUps[idx].consultationId,
        doctorId: _followUps[idx].doctorId,
        patientId: _followUps[idx].patientId,
        doctorMessage: _followUps[idx].doctorMessage,
        patientReply: patientReply,
        createdAt: _followUps[idx].createdAt,
        repliedAt: DateTime.now(),
        doctorName: _followUps[idx].doctorName,
        patientName: _followUps[idx].patientName,
      );
      notifyListeners();
    }

    await _notifService.createNotification(
      userId: doctorId,
      title: 'Follow-up Reply',
      body: 'Your patient has replied to the follow-up.',
      type: 'follow_up_reply',
    );
    onReplied();
  }

  void listenForReply(int followUpId) {
    _replyChannel?.unsubscribe();
    _replyChannel = _service.subscribeToReply(
      followUpId: followUpId,
      onReply: (f) {
        final idx = _followUps.indexWhere((fu) => fu.id == f.id);
        if (idx != -1) {
          _followUps[idx] = f;
          notifyListeners();
        }
      },
    );
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _replyChannel?.unsubscribe();
    super.dispose();
  }
}
