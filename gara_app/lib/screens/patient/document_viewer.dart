import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../../config/theme.dart';
import '../../models/clinical_document_model.dart';

class DocumentViewer extends StatefulWidget {
  final ClinicalDocumentModel document;
  const DocumentViewer({super.key, required this.document});

  @override
  State<DocumentViewer> createState() => _DocumentViewerState();
}

class _DocumentViewerState extends State<DocumentViewer> {
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: Text(widget.document.displayName),
        actions: [
          IconButton(
            icon: _isDownloading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_rounded),
            onPressed: _isDownloading ? null : _downloadPdf,
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded, size: 60, color: AppTheme.primaryGreen),
            ),
            const SizedBox(height: 24),
            Text(widget.document.displayName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              widget.document.createdAt != null
                  ? 'Generated on ${widget.document.createdAt!.day}/${widget.document.createdAt!.month}/${widget.document.createdAt!.year}'
                  : '',
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isDownloading ? null : _downloadPdf,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download to Device'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.visibility_rounded),
              label: const Text('Preview Document'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadPdf() async {
    setState(() => _isDownloading = true);
    try {
      final url = Uri.parse(widget.document.pdfStorageUrl);
      final response = await HttpClient().getUrl(url);
      final result = await response.close();
      final bytes = await result.fold(<int>[], (prev, chunk) => prev + chunk);

      if (kIsWeb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Opening PDF in browser\u2026'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        // Trigger browser download via printing share
        await Printing.sharePdf(
          bytes: Uint8List.fromList(bytes),
          filename: widget.document.displayName.replaceAll(' ', '_'),
        );
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final fileName = '${widget.document.displayName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloaded to: ${file.path}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
    if (mounted) setState(() => _isDownloading = false);
  }
}
