import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/clinical_document_model.dart';
import '../../models/consultation_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/consultation_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/document_service.dart';

class PrescriptionDialog extends StatefulWidget {
  final ConsultationModel consultation;
  const PrescriptionDialog({super.key, required this.consultation});

  @override
  State<PrescriptionDialog> createState() => _PrescriptionDialogState();
}

class _PrescriptionDialogState extends State<PrescriptionDialog> {
  final DocumentService _documentService = DocumentService();
  final _diagnosisController = TextEditingController();
  final List<_MedicationEntry> _medications = [];
  bool _isGenerating = false;

  @override
  void dispose() {
    _diagnosisController.dispose();
    for (final med in _medications) {
      med.nameController.dispose();
      med.dosageController.dispose();
      med.durationController.dispose();
      med.instructionsController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.description_rounded, color: AppTheme.primaryGreen, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lang.t('New Prescription', 'Imyandikire Nshya'),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        Text('${lang.t("Patient:", "Umurwayi:")} ${widget.consultation.patientName ?? "Unknown"}',
                            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _diagnosisController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: lang.t('Diagnosis / Clinical Notes', 'Isuzuma / Ibisobanuro'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderLight),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(lang.t('Medications', 'Imiti'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  TextButton.icon(
                    onPressed: _addMedication,
                    icon: const Icon(Icons.add_circle_rounded, size: 20),
                    label: Text(lang.t('Add', 'Ongera')),
                  ),
                ],
              ),
              ..._medications.asMap().entries.map((entry) => _buildMedicationCard(entry.key, lang)),
              if (_medications.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderLight, style: BorderStyle.solid),
                  ),
                  child: Center(
                    child: Text(lang.t('Tap "Add" to add medications', 'Kanda "Ongera" Kongeramo imiti'),
                        style: const TextStyle(color: AppTheme.textMuted)),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_diagnosisController.text.trim().isNotEmpty && _medications.isNotEmpty && !_isGenerating)
                      ? _generatePrescription
                      : null,
                  child: _isGenerating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(lang.t('Generate & Save Prescription', 'Kora & Bika Icyo Kwandika')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationCard(int index, LanguageProvider lang) {
    final med = _medications[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('${lang.t("Medication", "Imiti")} #${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_rounded, color: AppTheme.errorRed, size: 20),
                onPressed: () => setState(() => _medications.removeAt(index)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: med.nameController,
            decoration: InputDecoration(
              hintText: lang.t('Medication name', 'Izina ry\'imiti'),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: med.dosageController,
                  decoration: InputDecoration(
                    hintText: lang.t('Dosage', 'Igihe'),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: med.durationController,
                  decoration: InputDecoration(
                    hintText: lang.t('Duration', 'Igihe cyo gukoresha'),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: med.instructionsController,
            decoration: InputDecoration(
              hintText: lang.t('Instructions', 'Uko bayikoresha'),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  void _addMedication() {
    setState(() {
      _medications.add(_MedicationEntry());
    });
  }

  Future<void> _generatePrescription() async {
    setState(() => _isGenerating = true);

    try {
      final auth = context.read<AuthProvider>();
      final date = DateTime.now();
      final dateStr = '${date.day}/${date.month}/${date.year}';

      final pdfBytes = await _documentService.generatePrescriptionPdf(
        doctorName: auth.profile?.fullName ?? 'Doctor',
        clinicName: auth.profile?.clinicName,
        patientName: widget.consultation.patientName ?? 'Patient',
        patientPhone: widget.consultation.patientPhone ?? '',
        diagnosis: _diagnosisController.text.trim(),
        medications: _medications.map((m) => {
          'name': m.nameController.text.trim(),
          'dosage': m.dosageController.text.trim(),
          'duration': m.durationController.text.trim(),
          'instructions': m.instructionsController.text.trim(),
        }).toList(),
        date: dateStr,
      );

      final fileName = 'prescription_${widget.consultation.id}_${date.millisecondsSinceEpoch}.pdf';
      final url = await _documentService.savePdfToStorage(
        pdfBytes: pdfBytes,
        patientId: widget.consultation.patientId!,
        fileName: fileName,
      );

      await _documentService.saveDocumentRecord(
        consultationId: widget.consultation.id!,
        patientId: widget.consultation.patientId!,
        documentKind: DocumentType.prescription,
        pdfStorageUrl: url,
      );

      await _documentService.savePdfLocally(pdfBytes, fileName);

      if (context.mounted) {
        await context.read<ConsultationProvider>().updateConsultationStatus(
          widget.consultation.id!,
          CareStatus.complete,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription generated and saved!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    if (mounted) setState(() => _isGenerating = false);
  }
}

class _MedicationEntry {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController dosageController = TextEditingController();
  final TextEditingController durationController = TextEditingController();
  final TextEditingController instructionsController = TextEditingController();
}
