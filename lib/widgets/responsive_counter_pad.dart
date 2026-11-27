import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import '../theme/elysium_theme.dart';
import 'localized_text.dart';

/// Counter with ±1 controls and optional extra deltas, clamped to 0..9999.
class ResponsiveCounterPad extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final Color accentColor;
  final List<int> extraDeltas;

  const ResponsiveCounterPad({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.accentColor = Elysium.primary,
    this.extraDeltas = const [],
  });

  void _applyDelta(int delta) {
    HapticFeedback.lightImpact();
    onChanged((value + delta).clamp(0, 9999));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final controlSurface =
        dark ? const Color(0xFF243A56) : Elysium.surface2;
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
                      backgroundColor: controlSurface,
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
                      color: controlSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentColor.fade(0.6)),
                    ),
                    child: Text(
                      '$value',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: dark
                            ? theme.colorScheme.onSurface
                            : accentColor,
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
          if (extraDeltas.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < extraDeltas.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _extra(extraDeltas[i]),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _extra(int delta) {
    final negative = delta < 0;
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
            child: Text(
              '${delta > 0 ? '+' : ''}$delta',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}
