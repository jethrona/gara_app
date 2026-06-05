import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/clinical_document_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/document_service.dart';
import 'document_viewer.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final DocumentService _documentService = DocumentService();
  List<ClinicalDocumentModel> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final auth = context.read<AuthProvider>();
    if (auth.profile == null) return;

    setState(() => _isLoading = true);
    try {
      _documents = await _documentService.getPatientDocuments(auth.userId);
    } catch (e) {
      // ignore
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: Text(lang.t('My Documents', 'Inyandiko Zanjye')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? _buildEmptyState(lang)
              : RefreshIndicator(
                  onRefresh: _loadDocuments,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _documents.length,
                    itemBuilder: (context, index) {
                      final doc = _documents[index];
                      return _buildDocumentCard(doc, lang);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(LanguageProvider lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.folder_open_rounded, size: 40, color: AppTheme.primaryGreen),
          ),
          const SizedBox(height: 16),
          Text(lang.t('No documents yet', 'Nta nyandiko zikiri'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(lang.t('Your prescriptions and referrals will appear here',
              'Ibyo kwandika n\'inyandiko z\'ihererekanyo bizaboneka hano'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(ClinicalDocumentModel doc, LanguageProvider lang) {
    final isPrescription = doc.documentKind == DocumentType.prescription;
    final color = isPrescription ? AppTheme.primaryGreen : AppTheme.accentOrange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DocumentViewer(document: doc)),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isPrescription ? Icons.description_rounded : Icons.transfer_within_a_station_rounded,
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc.displayName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    if (doc.createdAt != null)
                      Text('${doc.createdAt!.day}/${doc.createdAt!.month}/${doc.createdAt!.year}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
