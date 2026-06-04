import 'package:flutter/material.dart';
import '../config/theme.dart';

class FinancialTicker extends StatefulWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  const FinancialTicker({
    super.key,
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  State<FinancialTicker> createState() => _FinancialTickerState();
}

class _FinancialTickerState extends State<FinancialTicker> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _triggerAnimation();
  }

  @override
  void didUpdateWidget(FinancialTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amount != widget.amount) {
      _triggerAnimation();
    }
  }

  void _triggerAnimation() {
    _animController.forward().then((_) {
      _animController.reverse();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnim.value,
        child: child,
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 16),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    'RWF',
                    key: ValueKey('rwf_${widget.amount.toStringAsFixed(0)}'),
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                '${widget.amount.toStringAsFixed(0)}',
                key: ValueKey(widget.amount.toStringAsFixed(0)),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: widget.color,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
