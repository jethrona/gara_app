enum CareStatus { pendingPayment, inProcess, complete }

class ConsultationModel {
  final int? id;
  final String? patientId;
  final CareStatus status;
  final String biologicalSex;
  final String severityLevel;
  final String durationSymptoms;
  final String? symptomCategory;
  final String? symptomDescription;
  final String? aiBriefSummary;
  final String? momoTransactionId;
  final double paymentAmount;
  final DateTime? createdAt;
  final DateTime? paidAt;
  final DateTime? closedAt;
  final String? patientName;
  final String? patientPhone;

  ConsultationModel({
    this.id,
    this.patientId,
    this.status = CareStatus.pendingPayment,
    required this.biologicalSex,
    required this.severityLevel,
    required this.durationSymptoms,
    this.symptomCategory,
    this.symptomDescription,
    this.aiBriefSummary,
    this.momoTransactionId,
    this.paymentAmount = 0.0,
    this.createdAt,
    this.paidAt,
    this.closedAt,
    this.patientName,
    this.patientPhone,
  });

  factory ConsultationModel.fromMap(Map<String, dynamic> map) {
    return ConsultationModel(
      id: map['id'] as int?,
      patientId: map['patient_id'] as String?,
      status: _parseStatus(map['status'] as String?),
      biologicalSex: map['biological_sex'] as String? ?? '',
      severityLevel: map['severity_level'] as String? ?? '',
      durationSymptoms: map['duration_symptoms'] as String? ?? '',
      symptomCategory: map['symptom_category'] as String?,
      symptomDescription: map['symptom_description'] as String?,
      aiBriefSummary: map['ai_brief_summary'] as String?,
      momoTransactionId: map['momo_transaction_id'] as String?,
      paymentAmount: (map['payment_amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
      paidAt: map['paid_at'] != null ? DateTime.parse(map['paid_at'] as String) : null,
      closedAt: map['closed_at'] != null ? DateTime.parse(map['closed_at'] as String) : null,
      patientName: map['patient_name'] as String?,
      patientPhone: map['patient_phone'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'patient_id': patientId,
      'status': _statusToString(status),
      'biological_sex': biologicalSex,
      'severity_level': severityLevel,
      'duration_symptoms': durationSymptoms,
      'symptom_category': symptomCategory,
      'symptom_description': symptomDescription,
      'ai_brief_summary': aiBriefSummary,
      'momo_transaction_id': momoTransactionId,
      'payment_amount': paymentAmount,
      if (paidAt != null) 'paid_at': paidAt!.toIso8601String(),
      if (closedAt != null) 'closed_at': closedAt!.toIso8601String(),
    };
  }

  static CareStatus _parseStatus(String? status) {
    switch (status) {
      case 'pending_payment':
        return CareStatus.pendingPayment;
      case 'in_process':
        return CareStatus.inProcess;
      case 'complete':
        return CareStatus.complete;
      default:
        return CareStatus.pendingPayment;
    }
  }

  static String _statusToString(CareStatus status) {
    switch (status) {
      case CareStatus.pendingPayment:
        return 'pending_payment';
      case CareStatus.inProcess:
        return 'in_process';
      case CareStatus.complete:
        return 'complete';
    }
  }

  ConsultationModel copyWith({
    int? id,
    String? patientId,
    CareStatus? status,
    String? biologicalSex,
    String? severityLevel,
    String? durationSymptoms,
    String? symptomCategory,
    String? symptomDescription,
    String? aiBriefSummary,
    String? momoTransactionId,
    double? paymentAmount,
    DateTime? createdAt,
    DateTime? paidAt,
    DateTime? closedAt,
    String? patientName,
    String? patientPhone,
  }) {
    return ConsultationModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      status: status ?? this.status,
      biologicalSex: biologicalSex ?? this.biologicalSex,
      severityLevel: severityLevel ?? this.severityLevel,
      durationSymptoms: durationSymptoms ?? this.durationSymptoms,
      symptomCategory: symptomCategory ?? this.symptomCategory,
      symptomDescription: symptomDescription ?? this.symptomDescription,
      aiBriefSummary: aiBriefSummary ?? this.aiBriefSummary,
      momoTransactionId: momoTransactionId ?? this.momoTransactionId,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      createdAt: createdAt ?? this.createdAt,
      paidAt: paidAt ?? this.paidAt,
      closedAt: closedAt ?? this.closedAt,
      patientName: patientName ?? this.patientName,
      patientPhone: patientPhone ?? this.patientPhone,
    );
  }

  String get statusLabel {
    switch (status) {
      case CareStatus.pendingPayment:
        return 'Pending Payment';
      case CareStatus.inProcess:
        return 'In Process';
      case CareStatus.complete:
        return 'Complete';
    }
  }
}
