class FollowUpModel {
  final int? id;
  final int consultationId;
  final String doctorId;
  final String patientId;
  final String doctorMessage;
  final String? patientReply;
  final DateTime createdAt;
  final DateTime? repliedAt;
  final String? doctorName;
  final String? patientName;

  FollowUpModel({
    this.id,
    required this.consultationId,
    required this.doctorId,
    required this.patientId,
    required this.doctorMessage,
    this.patientReply,
    required this.createdAt,
    this.repliedAt,
    this.doctorName,
    this.patientName,
  });

  factory FollowUpModel.fromMap(Map<String, dynamic> map) {
    return FollowUpModel(
      id: map['id'] as int?,
      consultationId: map['consultation_id'] as int,
      doctorId: map['doctor_id'] as String,
      patientId: map['patient_id'] as String,
      doctorMessage: map['doctor_message'] as String,
      patientReply: map['patient_reply'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      repliedAt: map['replied_at'] != null ? DateTime.parse(map['replied_at'] as String) : null,
      doctorName: map['doctor_name'] as String?,
      patientName: map['patient_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'consultation_id': consultationId,
      'doctor_id': doctorId,
      'patient_id': patientId,
      'doctor_message': doctorMessage,
      'patient_reply': patientReply,
      'created_at': createdAt.toIso8601String(),
      'replied_at': repliedAt?.toIso8601String(),
    };
  }

  bool get hasReply => patientReply != null && patientReply!.isNotEmpty;
}
