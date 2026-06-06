import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/clinical_document_model.dart';
import '../../providers/language_provider.dart';
import '../../services/document_service.dart';

class DocumentViewer extends StatefulWidget {
  final ClinicalDocumentModel document;
  const DocumentViewer({super.key, required this.document});

  @override
  State<DocumentViewer> createState() => _DocumentViewerState();
}

class _DocumentViewerState extends State<DocumentViewer> {
  final DocumentService _service = DocumentService();

  bool _isDownloading = false;
  File? _localFile;
  String? _errorMsg;

  String get _fileName {
    final uri = Uri.parse(widget.document.pdfStorageUrl);
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.last.contains('.')) {
      return uri.pathSegments.last;
    }
    return '${widget.document.documentKind.name}_${widget.document.id}.pdf';
  }

  Future<File?> _ensureLocal() async {
    if (_localFile != null && _localFile!.existsSync()) return _localFile;

    final url = widget.document.pdfStorageUrl;
    if (url.isEmpty) {
      _showError('No PDF URL available for this document.');
      return null;
    }

    try {
      final file = await _service.downloadPdfFromUrl(url, _fileName);
      setState(() => _localFile = file);
      return file;
    } catch (e) {
      _showError('Download failed: $e');
      return null;
    }
  }

  void _showError(String msg) {
    setState(() => _errorMsg = msg);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ));
    }
  }

  Future<void> _download() async {
    setState(() { _isDownloading = true; _errorMsg = null; });
    final file = await _ensureLocal();
    setState(() => _isDownloading = false);

    if (file != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Saved to device'),
        backgroundColor: AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isPrescription =
        widget.document.documentKind == DocumentType.prescription;
    final color =
        isPrescription ? AppTheme.primaryGreen : AppTheme.accentOrange;

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: Text(widget.document.displayName),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),

            // Document icon
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                isPrescription
                    ? Icons.description_rounded
                    : Icons.transfer_within_a_station_rounded,
                size: 52,
                color: color,
              ),
            ),
            const SizedBox(height: 20),

            // Document name
            Text(widget.document.displayName,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),

            // Date
            if (widget.document.createdAt != null)
              Text(
                '${lang.t("Generated on", "Yakozwe")} '
                '${widget.document.createdAt!.day}/'
                '${widget.document.createdAt!.month}/'
                '${widget.document.createdAt!.year}',
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textSecondary),
              ),
            const SizedBox(height: 32),

            // Download button only
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isDownloading ? null : _download,
                icon: _isDownloading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_rounded, size: 20),
                label: Text(lang.t('Download to Device', 'Pakurura'),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            // Error message
            if (_errorMsg != null) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.errorRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppTheme.errorRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_errorMsg!,
                          style: const TextStyle(
                              color: AppTheme.errorRed,
                              fontSize: 13,
                              height: 1.5)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Storage info note
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppTheme.textMuted, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lang.t(
                        'This document is also stored securely in your GARA account.',
                        "Inyandiko ifunzwe mu konti yawe ya GARA.",
                      ),
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
