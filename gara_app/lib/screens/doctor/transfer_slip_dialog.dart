import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/clinical_document_model.dart';
import '../../models/consultation_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/document_service.dart';

class TransferSlipDialog extends StatefulWidget {
  final ConsultationModel consultation;
  const TransferSlipDialog({super.key, required this.consultation});

  @override
  State<TransferSlipDialog> createState() => _TransferSlipDialogState();
}

class _TransferSlipDialogState extends State<TransferSlipDialog> {
  final DocumentService _documentService = DocumentService();
  final _notesController = TextEditingController();
  bool _isGenerating = false;

  @override
  void dispose() {
    _notesController.dispose();
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
                      color: AppTheme.accentOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.transfer_within_a_station_rounded, color: AppTheme.accentOrange, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lang.t('Transfer Slip', 'Inyandiko y\'Ihererekanyo'),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        Text('${lang.t("Patient:", "Umurwayi:")} ${widget.consultation.patientName ?? "Unknown"}',
                            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningYellow.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.warningYellow.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.warningYellow, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lang.t('This will generate an official medical referral document for hospital transfer.',
                            'Iki kintu kizakora inyandiko y\'ihererekanyo ya kuvuriro.'),
                        style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(lang.t('Patient Summary', 'Ibisobanuro by\'Umurwayi'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _infoRow(lang.t('Name', 'Izina'), widget.consultation.patientName ?? ''),
              _infoRow(lang.t('Phone', 'Telefone'), widget.consultation.patientPhone ?? ''),
              _infoRow(lang.t('Sex', 'Igitsina'), widget.consultation.biologicalSex),
              _infoRow(lang.t('Severity', 'Uburemere'), widget.consultation.severityLevel.split('–')[0].trim()),
              if (widget.consultation.aiBriefSummary != null) ...[
                const SizedBox(height: 12),
                Text(lang.t('AI Assessment', 'Isuzuma rya AI'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(widget.consultation.aiBriefSummary!,
                      style: const TextStyle(fontSize: 12, height: 1.4)),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: lang.t("Doctor's Referral Notes", 'Ibisobanuro by\'Umuganga'),
                  hintText: lang.t('Reason for referral, clinical findings...',
                      'Impamvu y\'ihererekanyo, ibyasanzwe...'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderLight),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_notesController.text.trim().isNotEmpty && !_isGenerating)
                      ? _generateTransferSlip
                      : null,
                  icon: _isGenerating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.transfer_within_a_station_rounded),
                  label: Text(_isGenerating
                      ? ''
                      : lang.t('Generate Transfer Slip', 'Kora Inyandiko y\'Ihererekanyo')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentOrange,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Future<void> _generateTransferSlip() async {
    setState(() => _isGenerating = true);

    try {
      final auth = context.read<AuthProvider>();
      final date = DateTime.now();
      final dateStr = '${date.day}/${date.month}/${date.year}';

      final pdfBytes = await _documentService.generateTransferSlipPdf(
        doctorName: auth.profile?.fullName ?? 'Doctor',
        patientName: widget.consultation.patientName ?? 'Patient',
        patientPhone: widget.consultation.patientPhone ?? '',
        aiBrief: widget.consultation.aiBriefSummary ?? 'No AI brief available.',
        doctorNotes: _notesController.text.trim(),
        severity: widget.consultation.severityLevel,
        date: dateStr,
      );

      final fileName = 'transfer_slip_${widget.consultation.id}_${date.millisecondsSinceEpoch}.pdf';
      final url = await _documentService.savePdfToStorage(
        pdfBytes: pdfBytes,
        patientId: widget.consultation.patientId!,
        fileName: fileName,
      );

      await _documentService.saveDocumentRecord(
        consultationId: widget.consultation.id!,
        patientId: widget.consultation.patientId!,
        documentKind: DocumentType.transferSlip,
        pdfStorageUrl: url,
      );

      await _documentService.savePdfLocally(pdfBytes, fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transfer slip generated and saved!'),
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
