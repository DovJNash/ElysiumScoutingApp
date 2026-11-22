import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/elysium_theme.dart';

/// Two-tier counter: big -1 / +1 on top, batch -50 -10 +10 +50 below.
/// Clamped to 0..9999 with haptic feedback.
class ResponsiveCounterPad extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final Color accentColor;

  const ResponsiveCounterPad({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.accentColor = Elysium.primary,
  });

  void _applyDelta(int delta) {
    HapticFeedback.lightImpact();
    onChanged((value + delta).clamp(0, 9999));
  }

  @override
  Widget build(BuildContext context) {
    return ElysiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Elysium.surface2,
                      foregroundColor: Elysium.danger,
                    ),
                    onPressed: value > 0 ? () => _applyDelta(-1) : null,
                    child: const Text('-1', style: TextStyle(fontSize: 22)),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Elysium.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentColor.fade(0.6)),
                    ),
                    child: Text(
                      '$value',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Elysium.onColor(accentColor),
                    ),
                    onPressed: () => _applyDelta(1),
                    child: const Text('+1', style: TextStyle(fontSize: 22)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _batch('-50', -50, true),
              const SizedBox(width: 8),
              _batch('-10', -10, true),
              const SizedBox(width: 14),
              _batch('+10', 10, false),
              const SizedBox(width: 8),
              _batch('+50', 50, false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _batch(String text, int delta, bool negative) {
    final color = negative ? Elysium.danger : Elysium.success;
    final disabled = negative && value == 0;
    return Expanded(
      child: SizedBox(
        height: 44,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: color,
            side: BorderSide(color: color.fade(0.45)),
          ),
          onPressed: disabled ? null : () => _applyDelta(delta),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ),
      ),
    );
  }
}
