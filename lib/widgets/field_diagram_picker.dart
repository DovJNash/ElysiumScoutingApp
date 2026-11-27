import 'package:flutter/material.dart';

import '../theme/elysium_theme.dart';
import '../services/locale_service.dart';

class FieldDiagramPicker extends StatelessWidget {
  final String title;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final bool pathMode;

  const FieldDiagramPicker({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.pathMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ElysiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            LocaleService.instance.text(title),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 2,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _RebuiltAlliancePainter(
                            pathMode: pathMode,
                            selected: value,
                            dark: dark,
                          ),
                        ),
                      ),
                      for (final option in options) _zoneButton(option, size),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            LocaleService.instance.text(
              pathMode
                  ? 'Tap where the robot exited the blue alliance zone.'
                  : 'Tap the robot starting location in the blue alliance zone.',
            ),
            style: TextStyle(
              color: dark ? const Color(0xFFB4C4D9) : Elysium.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty
                ? LocaleService.instance.text('No selection')
                : LocaleService.instance.text(value),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Elysium.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoneButton(String option, Size size) {
    final selected = value == option;
    final position = switch (option) {
      'Left trench' => const [0.12, 0.17, 0.34, 0.2],
      'Left bumper' => const [0.12, 0.63, 0.34, 0.2],
      'Hub' => const [0.4, 0.38, 0.2, 0.24],
      'Right bumper' => const [0.54, 0.63, 0.34, 0.2],
      'Right trench' => const [0.54, 0.17, 0.34, 0.2],
      'None' => const [0.42, 0.03, 0.16, 0.16],
      _ => const [0.42, 0.42, 0.16, 0.16],
    };
    return Positioned(
      left: size.width * position[0],
      top: size.height * position[1],
      width: size.width * position[2],
      height: size.height * position[3],
      child: LayoutBuilder(
        builder: (context, constraints) => Material(
          color:
              selected ? Elysium.primary.fade(0.82) : Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => onChanged(option),
            child: Center(
              child: Text(
                LocaleService.instance.text(option),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontSize: constraints.maxWidth < 55 ? 7 : 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RebuiltAlliancePainter extends CustomPainter {
  final bool pathMode;
  final String selected;
  final bool dark;

  const _RebuiltAlliancePainter({
    required this.pathMode,
    required this.selected,
    required this.dark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final field = Offset.zero & size;
    canvas.drawRect(
      field,
      Paint()..color = dark ? const Color(0xFF1F3858) : const Color(0xFF3977AD),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.48, size.width, size.height * 0.52),
      Paint()..color = const Color(0xFF1766A9),
    );
    final line = Paint()
      ..color = Colors.white.withAlpha(150)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(0, size.height * 0.48),
      Offset(size.width, size.height * 0.48),
      line,
    );
    final hub = Offset(size.width / 2, size.height * 0.5);
    canvas.drawCircle(hub, size.height * 0.15, Paint()..color = Colors.white);
    canvas.drawCircle(hub, size.height * 0.1, Paint()..color = Elysium.primary);

    final trenchPaint = Paint()..color = const Color(0xFF132D49);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.21,
        size.height * 0.12,
        size.width * 0.12,
        size.height * 0.76,
      ),
      trenchPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.67,
        size.height * 0.12,
        size.width * 0.12,
        size.height * 0.76,
      ),
      trenchPaint,
    );

    final goalPaint = Paint()..color = const Color(0xFFFFD166);
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      size.height * 0.035,
      goalPaint,
    );

    if (pathMode && selected.isNotEmpty && selected != 'None') {
      final endX =
          selected.startsWith('Left') ? size.width * 0.12 : size.width * 0.88;
      final endY =
          selected.endsWith('trench') ? size.height * 0.18 : size.height * 0.82;
      final pathPaint = Paint()
        ..color = const Color(0xFFFFD166)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(size.width / 2, size.height * 0.82),
        Offset(endX, endY),
        pathPaint,
      );
    }

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(field.deflate(1.5), border);
  }

  @override
  bool shouldRepaint(covariant _RebuiltAlliancePainter oldDelegate) =>
      pathMode != oldDelegate.pathMode ||
      selected != oldDelegate.selected ||
      dark != oldDelegate.dark;
}
