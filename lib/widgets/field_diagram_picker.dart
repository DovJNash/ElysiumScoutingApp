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
            aspectRatio: 0.6,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          'assets/images/FE-2026-_REBUILT_Playing_Field_With_Fuel_With_Background.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Stack(
                            fit: StackFit.expand,
                            children: [
                              CustomPaint(
                                painter: _RebuiltAlliancePainter(
                                  pathMode: pathMode,
                                  selected: value,
                                  dark: dark,
                                ),
                              ),
                              Align(
                                alignment: Alignment.topCenter,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  color: Colors.black54,
                                  child: Text(
                                    LocaleService.instance.text(
                                      'Field photo missing; showing schematic.',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
      'Left trench' => const [0.02, 0.08, 0.46, 0.13],
      'Left bump' => const [0.02, 0.78, 0.46, 0.13],
      'Hub' => const [0.02, 0.43, 0.46, 0.13],
      'Right bump' => const [0.52, 0.78, 0.46, 0.13],
      'Right trench' => const [0.52, 0.08, 0.46, 0.13],
      'None' => const [0.52, 0.43, 0.46, 0.13],
      _ => const [0.27, 0.44, 0.46, 0.13],
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
      final end = switch (selected) {
        'Left trench' => Offset(size.width * 0.12, size.height * 0.18),
        'Left bump' => Offset(size.width * 0.12, size.height * 0.82),
        'Hub' => Offset(size.width * 0.5, size.height * 0.5),
        'Right bump' => Offset(size.width * 0.88, size.height * 0.82),
        'Right trench' => Offset(size.width * 0.88, size.height * 0.18),
        _ => Offset(size.width * 0.5, size.height * 0.5),
      };
      final pathPaint = Paint()
        ..color = const Color(0xFFFFD166)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(size.width / 2, size.height * 0.82),
        end,
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
