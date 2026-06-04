import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return GestureDetector(
      onTap: () => context.read<LanguageProvider>().toggleLanguage(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: lang.isKinyarwanda
              ? const Color(0xFF059669).withValues(alpha: 0.1)
              : const Color(0xFF3B82F6).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: lang.isKinyarwanda
                ? const Color(0xFF059669).withValues(alpha: 0.3)
                : const Color(0xFF3B82F6).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              lang.isKinyarwanda ? 'RW' : 'EN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: lang.isKinyarwanda
                    ? const Color(0xFF059669)
                    : const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.translate_rounded,
              size: 16,
              color: lang.isKinyarwanda
                  ? const Color(0xFF059669)
                  : const Color(0xFF3B82F6),
            ),
          ],
        ),
      ),
    );
  }
}
