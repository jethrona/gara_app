enum AppointmentStatus { pending, confirmed, cancelled, completed }

class AppointmentModel {
  final int? id;
  final String patientId;
  final String doctorId;
  final int? consultationId;
  final DateTime requestedDate;
  final AppointmentStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? patientName;
  final String? doctorName;

  AppointmentModel({
    this.id,
    required this.patientId,
    required this.doctorId,
    this.consultationId,
    required this.requestedDate,
    this.status = AppointmentStatus.pending,
    this.notes,
    required this.createdAt,
    this.respondedAt,
    this.patientName,
    this.doctorName,
  });

  factory AppointmentModel.fromMap(Map<String, dynamic> map) {
    return AppointmentModel(
      id: map['id'] as int?,
      patientId: map['patient_id'] as String,
      doctorId: map['doctor_id'] as String,
      consultationId: map['consultation_id'] as int?,
      requestedDate: DateTime.parse(map['requested_date'] as String),
      status: _parseStatus(map['status'] as String? ?? 'pending'),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      respondedAt: map['responded_at'] != null ? DateTime.parse(map['responded_at'] as String) : null,
      patientName: map['patient_name'] as String?,
      doctorName: map['doctor_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'patient_id': patientId,
      'doctor_id': doctorId,
      if (consultationId != null) 'consultation_id': consultationId,
      'requested_date': requestedDate.toIso8601String(),
      'status': _statusToString(status),
      if (notes != null) 'notes': notes,
    };
  }

  static AppointmentStatus _parseStatus(String s) {
    switch (s) {
      case 'confirmed': return AppointmentStatus.confirmed;
      case 'cancelled': return AppointmentStatus.cancelled;
      case 'completed': return AppointmentStatus.completed;
      default: return AppointmentStatus.pending;
    }
  }

  static String _statusToString(AppointmentStatus s) {
    switch (s) {
      case AppointmentStatus.confirmed: return 'confirmed';
      case AppointmentStatus.cancelled: return 'cancelled';
      case AppointmentStatus.completed: return 'completed';
      default: return 'pending';
    }
  }

  String get statusLabel {
    switch (status) {
      case AppointmentStatus.confirmed: return 'Confirmed';
      case AppointmentStatus.cancelled: return 'Cancelled';
      case AppointmentStatus.completed: return 'Completed';
      default: return 'Pending';
    }
  }
}
