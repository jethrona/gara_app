enum DocumentType { prescription, transferSlip }

class ClinicalDocumentModel {
  final int? id;
  final int consultationId;
  final String patientId;
  final DocumentType documentKind;
  final String pdfStorageUrl;
  final DateTime? createdAt;

  ClinicalDocumentModel({
    this.id,
    required this.consultationId,
    required this.patientId,
    required this.documentKind,
    required this.pdfStorageUrl,
    this.createdAt,
  });

  factory ClinicalDocumentModel.fromMap(Map<String, dynamic> map) {
    return ClinicalDocumentModel(
      id: map['id'] as int?,
      consultationId: map['consultation_id'] as int,
      patientId: map['patient_id'] as String,
      documentKind: _parseType(map['document_kind'] as String),
      pdfStorageUrl: map['pdf_storage_url'] as String,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'consultation_id': consultationId,
      'patient_id': patientId,
      'document_kind': typeToString(documentKind),
      'pdf_storage_url': pdfStorageUrl,
    };
  }

  static DocumentType _parseType(String type) {
    switch (type) {
      case 'prescription':
        return DocumentType.prescription;
      case 'transfer_slip':
        return DocumentType.transferSlip;
      default:
        return DocumentType.prescription;
    }
  }

  static String typeToString(DocumentType type) {
    switch (type) {
      case DocumentType.prescription:
        return 'prescription';
      case DocumentType.transferSlip:
        return 'transfer_slip';
    }
  }

  String get displayName {
    switch (documentKind) {
      case DocumentType.prescription:
        return 'Prescription';
      case DocumentType.transferSlip:
        return 'Transfer Document';
    }
  }
}
