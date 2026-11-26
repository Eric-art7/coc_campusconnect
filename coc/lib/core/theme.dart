import 'package:material_ui/material_ui.dart';

/// App palette (light + dark), taken from the React app and Figma screens.
class Pal extends ThemeExtension<Pal> {
  const Pal({
    required this.bg,
    required this.card,
    required this.tint,
    required this.line,
    required this.ink,
    required this.muted,
    required this.primary,
    required this.deep,
    required this.danger,
    required this.success,
  });
  final Color bg, card, tint, line, ink, muted, primary, deep, danger, success;

  @override
  Pal copyWith() => this;

  @override
  Pal lerp(ThemeExtension<Pal>? other, double t) =>
      other is Pal ? (t < 0.5 ? this : other) : this;
}

extension PalX on BuildContext {
  Pal get pal => Theme.of(this).extension<Pal>()!;
}

class Txt {
  static TextStyle h1(BuildContext c) => TextStyle(
      fontSize: 25, fontWeight: FontWeight.w800, color: c.pal.ink, height: 1.15, letterSpacing: -0.4);
  static TextStyle brandLarge(BuildContext c) =>
      TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.pal.primary);
  static TextStyle h2(BuildContext c) =>
      TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: c.pal.ink);
  static TextStyle body(BuildContext c) =>
      TextStyle(fontSize: 14, color: c.pal.ink, height: 1.4);
  static TextStyle caption(BuildContext c) =>
      TextStyle(fontSize: 12, color: c.pal.muted, height: 1.3);
  static TextStyle label(BuildContext c) => TextStyle(
      fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: c.pal.primary);
}

ThemeData buildTheme(Brightness b, bool highContrast) {
  final dark = b == Brightness.dark;
  final pal = dark
      ? Pal(
          bg: const Color(0xFF121120),
          card: const Color(0xFF1C1B2E),
          tint: const Color(0xFF2A2650),
          line: const Color(0xFF2D2C44),
          ink: const Color(0xFFEDEBFF),
          muted: highContrast ? const Color(0xFFC9C9DC) : const Color(0xFFA3A3BA),
          primary: const Color(0xFF8E80FF),
          deep: const Color(0xFF2B1F6E),
          danger: const Color(0xFFFF6B6B),
          success: const Color(0xFF4ADE80),
        )
      : Pal(
          bg: const Color(0xFFF7F8FB),
          card: Colors.white,
          tint: const Color(0xFFF0EDFF),
          line: const Color(0xFFECECF2),
          ink: const Color(0xFF24204F),
          muted: highContrast ? const Color(0xFF5F6075) : const Color(0xFF8A8B9B),
          primary: const Color(0xFF5B49DF),
          deep: const Color(0xFF2B1F6E),
          danger: const Color(0xFFD64545),
          success: const Color(0xFF15803D),
        );

  final scheme = ColorScheme.fromSeed(seedColor: pal.primary, brightness: b).copyWith(
    primary: pal.primary,
    onPrimary: Colors.white,
    surface: pal.card,
    onSurface: pal.ink,
    error: pal.danger,
  );

  OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c));

  return ThemeData(
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: pal.bg,
    extensions: [pal],
    dividerColor: pal.line,
    appBarTheme: AppBarTheme(
      backgroundColor: pal.bg,
      foregroundColor: pal.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle:
          TextStyle(color: pal.ink, fontSize: 17, fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: pal.card,
      hintStyle: TextStyle(color: pal.muted, fontSize: 13.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(pal.line),
      enabledBorder: border(pal.line),
      focusedBorder: border(pal.primary),
      errorBorder: border(pal.danger),
      focusedErrorBorder: border(pal.danger),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: pal.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: pal.ink,
        minimumSize: const Size(0, 44),
        side: BorderSide(color: pal.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: pal.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
