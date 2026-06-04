import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/clinical_document_model.dart';
import 'supabase_service.dart';

class DocumentService {
  final SupabaseService _supabase = SupabaseService();

  Future<Uint8List> generatePrescriptionPdf({
    required String doctorName,
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
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('GARA CLINICAL PRESCRIPTION',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
          ),
          pw.SizedBox(height: 8),
          pw.Divider(color: PdfColors.green700),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Doctor: $doctorName', style: pw.TextStyle(fontSize: 12)),
                  pw.Text('Date: $date', style: pw.TextStyle(fontSize: 12)),
                ],
              ),
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
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Diagnosis / Clinical Notes:',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(diagnosis, style: pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 20),
          pw.Text('Prescribed Medications:',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            cellStyle: pw.TextStyle(fontSize: 11),
            headers: ['#', 'Medication', 'Dosage', 'Duration', 'Instructions'],
            data: List<List<String>>.generate(medications.length, (i) => [
              '${i + 1}',
              medications[i]['name'] ?? '',
              medications[i]['dosage'] ?? '',
              medications[i]['duration'] ?? '',
              medications[i]['instructions'] ?? '',
            ]),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green50),
            headerAlignment: pw.Alignment.centerLeft,
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 32),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Doctor Signature', style: pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 20),
                pw.Text('_________________________', style: pw.TextStyle(fontSize: 12)),
                pw.Text(doctorName, style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Divider(color: PdfColors.grey300),
          pw.Text('Gara Telemedicine Platform - Generated Document',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ],
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> generateTransferSlipPdf({
    required String doctorName,
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
              pw.Text('Referring Doctor: $doctorName',
                  style: pw.TextStyle(fontSize: 12)),
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

  Future<String> savePdfToStorage({
    required Uint8List pdfBytes,
    required String patientId,
    required String fileName,
  }) async {
    final path = 'documents/$patientId/$fileName';
    await _supabase.client.storage.from('clinical_documents').uploadBinary(
      path,
      pdfBytes,
      fileOptions: const FileOptions(contentType: 'application/pdf'),
    );
    final url = _supabase.client.storage.from('clinical_documents').getPublicUrl(path);
    return url;
  }

  Future<ClinicalDocumentModel> saveDocumentRecord({
    required int consultationId,
    required String patientId,
    required DocumentType documentKind,
    required String pdfStorageUrl,
  }) async {
    final doc = ClinicalDocumentModel(
      consultationId: consultationId,
      patientId: patientId,
      documentKind: documentKind,
      pdfStorageUrl: pdfStorageUrl,
    );

    final response = await _supabase.client
        .from('clinical_documents')
        .insert(doc.toMap())
        .select()
        .single();

    return ClinicalDocumentModel.fromMap(response);
  }

  Future<List<ClinicalDocumentModel>> getPatientDocuments(String patientId) async {
    final response = await _supabase.client
        .from('clinical_documents')
        .select()
        .eq('patient_id', patientId)
        .order('created_at', ascending: false);

    return (response as List).map((e) => ClinicalDocumentModel.fromMap(e)).toList();
  }

  Future<File> savePdfLocally(Uint8List bytes, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> printPdf(Uint8List bytes) async {
    await Printing.layoutPdf(
      onLayout: (_) => bytes,
    );
  }
}
