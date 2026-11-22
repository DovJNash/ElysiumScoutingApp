import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

extension ColorAlpha on Color {
  /// Opacity helper that works on every Flutter version (no deprecations).
  Color fade(double opacity) =>
      withAlpha((opacity.clamp(0.0, 1.0) * 255).round());
}

/// ONE place for the whole look & feel.
///
/// Elysium 1937 brand: the logo's electric blue (#0164CC) on clean white, with
/// deep navy for text. To tweak the brand colors change only this class.
class Elysium {
  // Brand
  static const Color primary = Color(0xFF0164CC); // logo blue
  static const Color primaryDark = Color(0xFF0A3D82);
  static const Color accent = Color(0xFF0891D1); // sky blue (2nd series)
  static const Color navy = Color(0xFF0B1F3F);

  // Surfaces
  static const Color bg = Color(0xFFF2F6FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surface2 = Color(0xFFE6EEFA);
  static const Color border = Color(0xFFD2DEF0);

  // Text
  static const Color text = navy;
  static const Color muted = Color(0xFF5C6E8A);

  // Status
  static const Color success = Color(0xFF15803D);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF0284C7);

  static const String iconAsset = 'assets/images/elysium_icon.png';
  static const String iconWhiteAsset = 'assets/images/elysium_icon_white.png';
  static const String fullAsset = 'assets/images/elysium_full.png';
  static const String fullWhiteAsset = 'assets/images/elysium_full_white.png';

  /// Readable text/icon color on top of [c].
  static Color onColor(Color c) =>
      c.computeLuminance() > 0.55 ? navy : Colors.white;

  static Color roleColor(String role) {
    switch (role) {
      case 'Leader':
        return navy;
      case 'Strategy':
        return accent;
      default:
        return primary;
    }
  }

  static ThemeData theme() {
    const scheme = ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: text,
      error: danger,
      onError: Colors.white,
      outline: border,
    );

    OutlineInputBorder outline(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      dividerColor: border,
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: Colors.white,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: const TextStyle(color: muted),
        hintStyle: TextStyle(color: muted.fade(0.65)),
        border: outline(border),
        enabledBorder: outline(border),
        focusedBorder: outline(primary, 1.8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: surface2,
          disabledForegroundColor: muted,
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: navy,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: border,
        thumbColor: primary,
        overlayColor: primary.fade(0.15),
        valueIndicatorColor: primaryDark,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: border,
      ),
    );
  }
}

/// Elysium mark. [wordmark] adds "ELYSIUM 1937 / SCOUTING SYSTEM" beside it.
/// Use [onDark] = true on blue/dark backgrounds (white logo).
class ElysiumLogo extends StatelessWidget {
  final double size;
  final bool wordmark;
  final bool onDark;

  const ElysiumLogo({
    super.key,
    this.size = 34,
    this.wordmark = true,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white : Elysium.primary;
    final icon = Image.asset(
      onDark ? Elysium.iconWhiteAsset : Elysium.iconAsset,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.shield_rounded, size: size, color: fg),
    );
    if (!wordmark) return icon;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        SizedBox(width: size * 0.3),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ELYSIUM 1937',
              style: TextStyle(
                fontSize: size * 0.46,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: onDark ? Colors.white : Elysium.navy,
              ),
            ),
            Text(
              'SCOUTING SYSTEM',
              style: TextStyle(
                fontSize: size * 0.26,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.4,
                color: onDark ? Colors.white70 : Elysium.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Big logo: rabbit + "1937 ELYSIUM" wordmark (as designed by the team).
class ElysiumFullLogo extends StatelessWidget {
  final double height;
  final bool onDark;

  const ElysiumFullLogo({super.key, this.height = 120, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      onDark ? Elysium.fullWhiteAsset : Elysium.fullAsset,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => ElysiumLogo(size: height * 0.4, onDark: onDark),
    );
  }
}

/// AppBar title: white rabbit + title text.
class ElysiumAppBarTitle extends StatelessWidget {
  final String title;
  const ElysiumAppBarTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const ElysiumLogo(size: 30, wordmark: false, onDark: true),
      const SizedBox(width: 12),
      Expanded(child: Text(title, overflow: TextOverflow.ellipsis)),
    ]);
  }
}

/// Standard Elysium card (a real Material Card so ListTile splashes work).
class ElysiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry margin;
  final Color? borderColor;
  final Color? color;

  const ElysiumCard({
    super.key,
    required this.child,
    this.padding,
    this.margin = EdgeInsets.zero,
    this.borderColor,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin,
      elevation: 0,
      color: color ?? Elysium.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor ?? Elysium.border),
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SectionTitle(this.title, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: Elysium.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: Elysium.navy,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              subtitle!,
              style: const TextStyle(fontSize: 12, color: Elysium.muted),
            ),
          ),
        ],
      ],
    );
  }
}
