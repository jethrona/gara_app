import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/consultation_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/language_toggle.dart';
import 'patient_dashboard.dart';

class TriageForm extends StatefulWidget {
  const TriageForm({super.key});

  @override
  State<TriageForm> createState() => _TriageFormState();
}

class _TriageFormState extends State<TriageForm> {
  final _pageController = PageController();
  int _currentStep = 0;

  String? _selectedSex;
  String? _selectedSeverity;
  String? _selectedDuration;
  String? _selectedCategory;
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();
  List<String> _filteredCategories = AppConstants.symptomCategories;
  bool _aiProcessing = false;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(() {
      setState(() {});
      _saveDraft();
    });
    _searchController.addListener(() => setState(() {}));
    _restoreDraft();
  }

  @override
  void dispose() {
    _descriptionController.removeListener(() {});
    _descriptionController.dispose();
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('triage_step', _currentStep);
    if (_selectedSex != null) await prefs.setString('triage_sex', _selectedSex!);
    if (_selectedSeverity != null) await prefs.setString('triage_severity', _selectedSeverity!);
    if (_selectedDuration != null) await prefs.setString('triage_duration', _selectedDuration!);
    if (_selectedCategory != null) await prefs.setString('triage_category', _selectedCategory!);
    if (_descriptionController.text.isNotEmpty) await prefs.setString('triage_description', _descriptionController.text);
  }

  Future<void> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final step = prefs.getInt('triage_step');
    if (step == null) return;
    _currentStep = step.clamp(0, 5);
    _selectedSex = prefs.getString('triage_sex');
    _selectedSeverity = prefs.getString('triage_severity');
    _selectedDuration = prefs.getString('triage_duration');
    _selectedCategory = prefs.getString('triage_category');
    final desc = prefs.getString('triage_description');
    if (desc != null) _descriptionController.text = desc;
    if (_currentStep > 0) {
      _pageController.jumpToPage(_currentStep);
    }
    setState(() {});
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('triage_step');
    await prefs.remove('triage_sex');
    await prefs.remove('triage_severity');
    await prefs.remove('triage_duration');
    await prefs.remove('triage_category');
    await prefs.remove('triage_description');
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(lang.t('Medical Triage', 'Isuzuma ry\'Indwara')),
        actions: const [Padding(padding: EdgeInsets.only(right: 4), child: LanguageToggle())],
      ),
      body: Column(
        children: [
          _buildStepIndicator(lang),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) {
                setState(() => _currentStep = i);
                _saveDraft();
              },
              children: [
                SingleChildScrollView(child: _buildSexStep(lang)),
                SingleChildScrollView(child: _buildSeverityStep(lang)),
                SingleChildScrollView(child: _buildDurationStep(lang)),
                _buildCategoryStep(lang),
                SingleChildScrollView(child: _buildDescriptionStep(lang)),
                SingleChildScrollView(child: _buildReviewStep(lang)),
              ],
            ),
          ),
          _buildNavigation(lang),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(LanguageProvider lang) {
    final steps = [
      lang.t('Sex', 'Igitsina'),
      lang.t('Severity', 'Uburemere'),
      lang.t('Duration', 'Igihe'),
      lang.t('Category', 'Icyiciro'),
      lang.t('Describe', 'Sobanura'),
      lang.t('Review', 'Reba'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i == _currentStep;
          final isDone = i < _currentStep;
          return Expanded(
            child: GestureDetector(
              onTap: i <= _currentStep ? () {
                _pageController.jumpToPage(i);
                setState(() => _currentStep = i);
                _saveDraft();
              } : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: isDone ? AppTheme.primaryGreen : isActive ? Colors.white : AppTheme.borderLight,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive ? AppTheme.primaryGreen : AppTheme.borderLight,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : Text('${i + 1}', style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isActive ? AppTheme.primaryGreen : AppTheme.textMuted,
                            )),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(steps[i], style: TextStyle(fontSize: 9, color: isActive ? AppTheme.primaryGreen : AppTheme.textMuted)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSexStep(LanguageProvider lang) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lang.t('What is your biological sex?', 'Igitsina cyawe ni ikihe?'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          ...AppConstants.biologicalSexOptions.map((sex) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ChoiceChip(
              label: Text(sex),
              selected: _selectedSex == sex,
              onSelected: (v) {
                setState(() => _selectedSex = v ? sex : null);
                _saveDraft();
              },
              showCheckmark: true,
              selectedColor: AppTheme.primaryGreenLight,
              avatar: Icon(
                sex == 'Male' ? Icons.male : Icons.female,
                color: _selectedSex == sex ? AppTheme.primaryGreen : AppTheme.textSecondary,
                size: 20,
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildSeverityStep(LanguageProvider lang) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lang.t('How severe are your symptoms?', 'Ibimenyetso byawe bikomeye gute?'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          ...AppConstants.severityOptions.map((s) {
            final isSevere = s.startsWith('Severe');
            final isModerate = s.startsWith('Moderate');
            Color chipColor = AppTheme.successGreen;
            IconData chipIcon = Icons.sentiment_satisfied_rounded;
            if (isModerate) { chipColor = AppTheme.accentOrange; chipIcon = Icons.sentiment_neutral_rounded; }
            if (isSevere) { chipColor = AppTheme.errorRed; chipIcon = Icons.sentiment_very_dissatisfied_rounded; }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ChoiceChip(
                label: Text(s.split('–')[0].trim()),
                selected: _selectedSeverity == s,
                onSelected: (v) {
                  setState(() => _selectedSeverity = v ? s : null);
                  _saveDraft();
                },
                showCheckmark: true,
                selectedColor: chipColor.withValues(alpha: 0.15),
                avatar: Icon(chipIcon, color: _selectedSeverity == s ? chipColor : AppTheme.textSecondary, size: 20),
                labelStyle: TextStyle(color: _selectedSeverity == s ? chipColor : AppTheme.textPrimary),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDurationStep(LanguageProvider lang) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lang.t('How long have you had symptoms?', 'Ibimenyetso byawe bimaze igihe kingana iki?'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          ...AppConstants.durationOptions.map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ChoiceChip(
              label: SizedBox(
                width: MediaQuery.of(context).size.width - 80,
                child: Text(d),
              ),
              selected: _selectedDuration == d,
              onSelected: (v) {
                setState(() => _selectedDuration = v ? d : null);
                _saveDraft();
              },
              showCheckmark: true,
              selectedColor: AppTheme.primaryGreenLight,
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildCategoryStep(LanguageProvider lang) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lang.t('Select symptom category', 'Hitamo icyiciro cy\'ibimenyetso'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: lang.t('Search categories...', 'Shakisha...'),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppTheme.surfaceBg,
            ),
            onChanged: (v) {
              setState(() {
                _filteredCategories = AppConstants.symptomCategories
                    .where((c) => c.toLowerCase().contains(v.toLowerCase()))
                    .toList();
              });
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: _filteredCategories.map((cat) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ChoiceChip(
                  label: SizedBox(width: MediaQuery.of(context).size.width - 80, child: Text(cat)),
                  selected: _selectedCategory == cat,
                  onSelected: (v) {
                    setState(() => _selectedCategory = v ? cat : null);
                    _saveDraft();
                  },
                  showCheckmark: true,
                  selectedColor: AppTheme.primaryGreenLight,
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionStep(LanguageProvider lang) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lang.t('Describe your symptoms', 'Sobanura ibimenyetso byawe'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(lang.t('Be as detailed as possible about what you\'re feeling.',
              'Sobanura neza uko ubana n\'ibimenyetso byawe.'),
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          const SizedBox(height: 20),
          TextField(
            controller: _descriptionController,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: lang.t(
                'e.g. I have had a headache for 3 days, pain is on the left side...',
                'Urugero: Ndagira umutwe ushushwe iminsi 3, ububabare buri mu ruhande...',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.borderLight),
              ),
              filled: true,
              fillColor: AppTheme.surfaceBg,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${_descriptionController.text.length}/500',
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep(LanguageProvider lang) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lang.t('Review Your Information', 'Reba amakuru yawe'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            _reviewItem(lang.t('Biological Sex', 'Igitsina'), _selectedSex ?? ''),
            _reviewItem(lang.t('Severity', 'Uburemere'), _selectedSeverity?.split('–')[0].trim() ?? ''),
            _reviewItem(lang.t('Duration', 'Igihe'), _selectedDuration ?? ''),
            _reviewItem(lang.t('Category', 'Icyiciro'), _selectedCategory ?? ''),
            _reviewItem(lang.t('Description', 'Ibisobanuro'), _descriptionController.text.length > 80
                ? '${_descriptionController.text.substring(0, 80)}...'
                : _descriptionController.text),
            if (_aiProcessing) ...[
              const SizedBox(height: 20),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: AppTheme.primaryGreen),
                    SizedBox(height: 12),
                    Text('AI is analyzing your symptoms...', style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _reviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildNavigation(LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.borderLight)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300), curve: Curves.easeIn,
                ),
                child: Text(lang.t('Back', 'Inyuma')),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _canProceed() ? () => _handleNext(lang) : null,
              child: Text(_currentStep < 5
                  ? lang.t('Next', 'Ibikurikira')
                  : (_aiProcessing ? '' : lang.t('Submit', 'Ohereza'))),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0: return _selectedSex != null;
      case 1: return _selectedSeverity != null;
      case 2: return _selectedDuration != null;
      case 3: return _selectedCategory != null;
      case 4: return _descriptionController.text.trim().length >= 10;
      case 5: return !_aiProcessing;
      default: return false;
    }
  }

  Future<void> _handleNext(LanguageProvider lang) async {
    if (_currentStep < 5) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
    } else {
      setState(() => _aiProcessing = true);

      final consultationProvider = context.read<ConsultationProvider>();
      final auth = context.read<AuthProvider>();

      final result = await consultationProvider.submitTriage(
        patientId: auth.userId,
        biologicalSex: _selectedSex!,
        severityLevel: _selectedSeverity!,
        durationSymptoms: _selectedDuration!,
        symptomCategory: _selectedCategory!,
        symptomDescription: _descriptionController.text.trim(),
        patientName: auth.profile?.fullName ?? '',
      );

      setState(() => _aiProcessing = false);

      if (result != null && mounted) {
        await _clearDraft();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const PatientDashboard(),
          ),
        );
      }
    }
  }
}
