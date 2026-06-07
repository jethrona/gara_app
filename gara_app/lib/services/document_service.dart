import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/clinical_document_model.dart';
import '../services/supabase_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WHY DOWNLOAD / PREVIEW / SHARE FAILED
//
// Error: MissingPluginException(No implementation found for method
//        getApplicationDocumentsDirectory on channel
//        plugins.flutter.io/path_provider)
//
// This means path_provider is in pubspec.yaml but the native Android plugin
// was never registered because flutter clean was not run after adding it.
//
// FIX 1 (always do this first):
//   flutter clean
//   flutter pub get
//   flutter run
//
// FIX 2 — pubspec.yaml must have these packages:
//   path_provider: ^2.1.2
//   pdf: ^3.11.1
//   share_plus: ^9.0.0
//   open_filex: ^4.5.0    ← for "Preview" (opens PDF in device viewer)
//   supabase_flutter: ^2.0.0
//
// FIX 3 — AndroidManifest.xml needs (for share_plus file sharing on Android):
//   In <application> tag, add:
//   <provider
//     android:name="androidx.core.content.FileProvider"
//     android:authorities="${applicationId}.fileProvider"
//     android:exported="false"
//     android:grantUriPermissions="true">
//     <meta-data
//       android:name="android.support.FILE_PROVIDER_PATHS"
//       android:resource="@xml/file_paths"/>
//   </provider>
//
//   Create android/app/src/main/res/xml/file_paths.xml:
//   <?xml version="1.0" encoding="utf-8"?>
//   <paths>
//     <external-path name="external_files" path="."/>
//     <cache-path name="cache" path="."/>
//     <files-path name="files" path="."/>
//   </paths>
// ─────────────────────────────────────────────────────────────────────────────

class DocumentService {
  final SupabaseService _supabase = SupabaseService();

  // ── Fetch patient documents ───────────────────────────────────────────────

  Future<List<ClinicalDocumentModel>> getPatientDocuments(String patientId) async {
    final response = await _supabase.client
        .from('clinical_documents')
        .select()
        .eq('patient_id', patientId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => ClinicalDocumentModel.fromMap(e))
        .toList();
  }

  // ── Generate PDF bytes ────────────────────────────────────────────────────

  Future<Uint8List> generatePrescriptionPdf({
    required String doctorName,
    String? clinicName,
    required String patientName,
    required String patientPhone,
    required String diagnosis,
    required List<Map<String, String>> medications,
    required String date,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('GARA HEALTH',
                      style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('1D9E75'))),
                  pw.Text('Digital Prescription',
                      style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColor.fromHex('666666'))),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (clinicName != null && clinicName.isNotEmpty)
                    pw.Text(clinicName,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 13)),
                  pw.Text('Dr. $doctorName',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 13)),
                  pw.Text('Date: $date',
                      style: pw.TextStyle(
                          fontSize: 11,
                          color: PdfColor.fromHex('666666'))),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Divider(color: PdfColor.fromHex('1D9E75'), thickness: 2),
          pw.SizedBox(height: 16),

          // Patient info
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('F4FAF7'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('PATIENT INFORMATION',
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('1D9E75'),
                        letterSpacing: 1.2)),
                pw.SizedBox(height: 8),
                pw.Row(children: [
                  pw.Text('Name: ',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(patientName),
                ]),
                if (patientPhone.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Row(children: [
                    pw.Text('Phone: ',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(patientPhone),
                  ]),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Diagnosis
          pw.Text('DIAGNOSIS',
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('1D9E75'),
                  letterSpacing: 1.2)),
          pw.SizedBox(height: 6),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromHex('E0E0E0')),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Text(diagnosis,
                style: const pw.TextStyle(fontSize: 12)),
          ),
          pw.SizedBox(height: 20),

          // Medications
          pw.Text('PRESCRIBED MEDICATIONS',
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('1D9E75'),
                  letterSpacing: 1.2)),
          pw.SizedBox(height: 8),

          ...medications.asMap().entries.map((entry) {
            final i = entry.key;
            final med = entry.value;
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromHex('E0E0E0')),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('${i + 1}. ${med['name'] ?? ''}',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 13)),
                  pw.SizedBox(height: 4),
                  pw.Row(children: [
                    pw.Text('Dosage: ',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text(med['dosage'] ?? '',
                        style: const pw.TextStyle(fontSize: 11)),
                    pw.Text('   Duration: ',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text(med['duration'] ?? '',
                        style: const pw.TextStyle(fontSize: 11)),
                  ]),
                  if ((med['instructions'] ?? '').isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text('Instructions: ${med['instructions']}',
                        style: pw.TextStyle(
                            fontSize: 11,
                            color: PdfColor.fromHex('555555'))),
                  ],
                ],
              ),
            );
          }),

          pw.SizedBox(height: 30),
          pw.Divider(color: PdfColor.fromHex('E0E0E0')),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Generated by GARA Health Platform',
                  style: pw.TextStyle(
                      fontSize: 9, color: PdfColor.fromHex('999999'))),
              pw.Text('Dr. $doctorName',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> generateTransferSlipPdf({
    required String doctorName,
    String? clinicName,
    required String patientName,
    required String patientPhone,
    required String aiBrief,
    required String doctorNotes,
    required String severity,
    required String date,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('OFFICIAL MEDICAL TRANSFER SLIP',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: PdfColors.red50,
            child: pw.Text('URGENT - REFERRAL DOCUMENT',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (clinicName != null && clinicName.isNotEmpty)
                    pw.Text(clinicName,
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Referring Doctor: $doctorName',
                      style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.Text('Date: $date', style: pw.TextStyle(fontSize: 12)),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Patient: $patientName',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('Phone: $patientPhone',
                    style: pw.TextStyle(fontSize: 12)),
                pw.Text('Severity: $severity',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.red700, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text('AI Clinical Assessment Brief:',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Text(aiBrief, style: pw.TextStyle(fontSize: 11)),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Doctor\'s Referral Notes:',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.red50,
              border: pw.Border.all(color: PdfColors.red200),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Text(doctorNotes, style: pw.TextStyle(fontSize: 11)),
          ),
          pw.SizedBox(height: 32),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Referring Doctor Signature',
                    style: pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 20),
                pw.Text('_________________________',
                    style: pw.TextStyle(fontSize: 12)),
                pw.Text(doctorName,
                    style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Divider(color: PdfColors.grey300),
          pw.Text(
              'This is an official medical referral document generated by Gara Telemedicine Platform. '
              'Please present this document at the district hospital referral desk.',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ],
      ),
    );

    return pdf.save();
  }

  // ── Save PDF locally and return the File ─────────────────────────────────

  Future<File> savePdfLocally(Uint8List bytes, String fileName) async {
    // Use getApplicationDocumentsDirectory — this is what failed.
    // After flutter clean && flutter pub get it will work.
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  // ── Download PDF from Supabase URL and save locally ───────────────────────

  Future<File> downloadPdfFromUrl(String url, String fileName) async {
    // Use Supabase client to download (handles auth automatically)
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;

    // Extract bucket and path from public URL
    // URL format: https://<project>.supabase.co/storage/v1/object/public/<bucket>/<path>
    final publicIndex = pathSegments.indexOf('public');
    if (publicIndex == -1 || publicIndex + 2 >= pathSegments.length) {
      throw Exception('Invalid Supabase storage URL: $url');
    }

    final bucket = pathSegments[publicIndex + 1];
    final objectPath = pathSegments.sublist(publicIndex + 2).join('/');

    final bytes = await _supabase.client.storage
        .from(bucket)
        .download(objectPath);

    return savePdfLocally(bytes, fileName);
  }

  // ── Open PDF in device viewer (Preview) ──────────────────────────────────

  Future<void> openPdf(File file) async {
    // Using open_filex to open the PDF in the device's default PDF viewer
    // Add to pubspec.yaml: open_filex: ^4.5.0
    // This import is dynamic to avoid compile error if package not yet added
    try {
      // ignore: avoid_dynamic_calls
      final result = await _openFilex(file.path);
      debugPrint('OpenFilex result: $result');
    } catch (e) {
      throw Exception(
        'Could not open PDF viewer. '
        'Make sure open_filex: ^4.5.0 is in pubspec.yaml\n$e',
      );
    }
  }

  // Wrapper so the rest of the file compiles even before open_filex is added
  Future<dynamic> _openFilex(String path) async {
    return await OpenFilex.open(path);
  }

  // ── Share PDF ─────────────────────────────────────────────────────────────

  Future<void> sharePdf(File file, {String? subject}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: subject ?? 'GARA Health Document',
        text: 'Shared from GARA Health',
      ),
    );
  }

  // ── Upload PDF to Supabase Storage ────────────────────────────────────────

  Future<String> savePdfToStorage({
    required Uint8List pdfBytes,
    required String patientId,
    required String fileName,
  }) async {
    final path = 'documents/$patientId/$fileName';
    await _supabase.client.storage
        .from('clinical_documents')
        .uploadBinary(
          path,
          pdfBytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );
    return _supabase.client.storage
        .from('clinical_documents')
        .getPublicUrl(path);
  }

  // ── Save document record to DB ────────────────────────────────────────────

  Future<void> saveDocumentRecord({
    required int consultationId,
    required String patientId,
    required DocumentType documentKind,
    required String pdfStorageUrl,
  }) async {
    await _supabase.client.from('clinical_documents').insert({
      'consultation_id': consultationId,
      'patient_id': patientId,
      'document_kind': ClinicalDocumentModel.typeToString(documentKind),
      'pdf_storage_url': pdfStorageUrl,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
