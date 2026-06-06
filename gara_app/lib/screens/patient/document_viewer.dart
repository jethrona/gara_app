import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
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
  bool _isSharing = false;
  bool _isOpening = false;
  File? _localFile;
  String? _errorMsg;

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _fileName {
    final uri = Uri.parse(widget.document.pdfStorageUrl);
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.last.contains('.')) {
      return uri.pathSegments.last;
    }
    return '${widget.document.documentKind.name}_${widget.document.id}.pdf';
  }

  // Download the file if not already local, then return it
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

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _download() async {
    setState(() { _isDownloading = true; _errorMsg = null; });
    final file = await _ensureLocal();
    setState(() => _isDownloading = false);

    if (file != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Saved to: ${file.path}'),
        backgroundColor: AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _preview() async {
    setState(() { _isOpening = true; _errorMsg = null; });
    final file = await _ensureLocal();
    if (file == null) { setState(() => _isOpening = false); return; }

    try {
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        _showError('Could not open PDF: ${result.message}\n'
            'Make sure a PDF viewer app is installed on this device.');
      }
    } catch (e) {
      _showError('Preview failed: $e');
    }
    if (mounted) setState(() => _isOpening = false);
  }

  Future<void> _share() async {
    setState(() { _isSharing = true; _errorMsg = null; });
    final file = await _ensureLocal();
    if (file == null) { setState(() => _isSharing = false); return; }

    try {
      await _service.sharePdf(file,
          subject: 'GARA - ${widget.document.displayName}');
    } catch (e) {
      _showError('Share failed: $e');
    }
    if (mounted) setState(() => _isSharing = false);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
                'Generated on '
                '${widget.document.createdAt!.day}/'
                '${widget.document.createdAt!.month}/'
                '${widget.document.createdAt!.year}',
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textSecondary),
              ),
            const SizedBox(height: 32),

            // ── Action buttons ─────────────────────────────────────────────

            // Download
            _ActionButton(
              icon: Icons.download_rounded,
              label: lang.t('Download to Device', 'Pakurura'),
              color: AppTheme.primaryGreen,
              isLoading: _isDownloading,
              onTap: _isDownloading ? null : _download,
            ),
            const SizedBox(height: 12),

            // Preview
            _ActionButton(
              icon: Icons.visibility_rounded,
              label: lang.t('Preview Document', 'Reba Inyandiko'),
              color: AppTheme.accentBlue,
              isLoading: _isOpening,
              onTap: _isOpening ? null : _preview,
              outlined: true,
            ),
            const SizedBox(height: 12),

            // Share
            _ActionButton(
              icon: Icons.share_rounded,
              label: lang.t('Share', 'Sangira'),
              color: AppTheme.accentOrange,
              isLoading: _isSharing,
              onTap: _isSharing ? null : _share,
              outlined: true,
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

            // Info note
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

// ── Reusable action button ────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isLoading;
  final VoidCallback? onTap;
  final bool outlined;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isLoading,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: onTap,
              icon: isLoading
                  ? SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: color))
                  : Icon(icon, color: color, size: 20),
              label: Text(label,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            )
          : ElevatedButton.icon(
              onPressed: onTap,
              icon: isLoading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(icon, size: 20),
              label: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
    );
  }
}
