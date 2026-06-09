import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/appointment_model.dart';
import '../services/appointment_service.dart';
import '../services/notification_service.dart';

class AppointmentProvider extends ChangeNotifier {
  final AppointmentService _service = AppointmentService();
  final NotificationService _notifService = NotificationService();

  List<AppointmentModel> _appointments = [];
  bool _isLoading = false;
  String? _userId;
  bool _isDoctor = false;
  RealtimeChannel? _realtimeChannel;

  List<AppointmentModel> get appointments => _appointments;
  bool get isLoading => _isLoading;

  List<AppointmentModel> get pending =>
      _appointments.where((a) => a.status == AppointmentStatus.pending).toList();

  List<AppointmentModel> get confirmed =>
      _appointments.where((a) => a.status == AppointmentStatus.confirmed).toList();

  void initAsDoctor(String doctorId) {
    _userId = doctorId;
    _isDoctor = true;
    _loadDoctorAppointments(doctorId);
  }

  void initAsPatient(String patientId) {
    _userId = patientId;
    _isDoctor = false;
    _loadPatientAppointments(patientId);
  }

  Future<void> _loadDoctorAppointments(String doctorId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _appointments = await _service.getDoctorAppointments(doctorId);
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = _service.subscribeToDoctorAppointments(
        doctorId: doctorId,
        onAppointment: (a) {
          _appointments.insert(0, a);
          notifyListeners();
        },
      );
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadPatientAppointments(String patientId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _appointments = await _service.getPatientAppointments(patientId);
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = _service.subscribeToPatientAppointments(
        patientId: patientId,
        onAppointment: (a) {
          final idx = _appointments.indexWhere((ap) => ap.id == a.id);
          if (idx != -1) {
            _appointments[idx] = a;
          } else {
            _appointments.insert(0, a);
          }
          notifyListeners();
        },
      );
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> requestAppointment({
    required String patientId,
    required String doctorId,
    required DateTime requestedDate,
    String? notes,
    required VoidCallback onSuccess,
  }) async {
    final appointment = await _service.createAppointment(
      patientId: patientId,
      doctorId: doctorId,
      requestedDate: requestedDate,
      notes: notes,
    );
    _appointments.insert(0, appointment);
    notifyListeners();

    await _notifService.createNotification(
      userId: doctorId,
      title: 'Appointment Request',
      body: 'A new appointment has been requested.',
      type: 'appointment',
    );
    onSuccess();
  }

  Future<void> confirmAppointment({
    required int appointmentId,
    required String patientId,
    required VoidCallback onSuccess,
  }) async {
    await _service.updateAppointmentStatus(
      appointmentId: appointmentId,
      status: 'confirmed',
    );
    final idx = _appointments.indexWhere((a) => a.id == appointmentId);
    if (idx != -1) {
      _appointments[idx] = AppointmentModel(
        id: _appointments[idx].id,
        patientId: _appointments[idx].patientId,
        doctorId: _appointments[idx].doctorId,
        requestedDate: _appointments[idx].requestedDate,
        status: AppointmentStatus.confirmed,
        createdAt: _appointments[idx].createdAt,
        respondedAt: DateTime.now(),
        patientName: _appointments[idx].patientName,
        doctorName: _appointments[idx].doctorName,
      );
      notifyListeners();
    }

    await _notifService.createNotification(
      userId: patientId,
      title: 'Appointment Confirmed',
      body: 'Your appointment has been confirmed.',
      type: 'appointment',
    );
    onSuccess();
  }

  Future<void> cancelAppointment({
    required int appointmentId,
    required String patientId,
    required VoidCallback onSuccess,
  }) async {
    await _service.updateAppointmentStatus(
      appointmentId: appointmentId,
      status: 'cancelled',
    );
    final idx = _appointments.indexWhere((a) => a.id == appointmentId);
    if (idx != -1) {
      _appointments[idx] = AppointmentModel(
        id: _appointments[idx].id,
        patientId: _appointments[idx].patientId,
        doctorId: _appointments[idx].doctorId,
        requestedDate: _appointments[idx].requestedDate,
        status: AppointmentStatus.cancelled,
        createdAt: _appointments[idx].createdAt,
        respondedAt: DateTime.now(),
        patientName: _appointments[idx].patientName,
        doctorName: _appointments[idx].doctorName,
      );
      notifyListeners();
    }

    await _notifService.createNotification(
      userId: patientId,
      title: 'Appointment Cancelled',
      body: 'Your appointment has been cancelled.',
      type: 'appointment',
    );
    onSuccess();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}
