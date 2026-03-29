import 'package:flutter/material.dart';

class AppTheme {
  static const Color shell = Color(0xFFF4EEDD);
  static const Color shellDeep = Color(0xFFE3D5BA);
  static const Color panel = Color(0xFFFFFCF4);
  static const Color panelStrong = Color(0xFFECE0C5);
  static const Color ink = Color(0xFF1E3A35);
  static const Color inkMuted = Color(0xFF56716A);
  static const Color accent = Color(0xFF1F8A78);
  static const Color accentSoft = Color(0xFF8ED2C6);
  static const Color cyan = Color(0xFF69B9CE);
  static const Color amber = Color(0xFFD6943D);
  static const Color success = Color(0xFF4C8B5F);
  static const Color danger = Color(0xFFC85A54);
  static const Color borderStrong = Color(0xFF27433D);
  static const Color borderMuted = Color(0xFFCBBE9D);
  static const Color shadow = Color(0x220F1D1A);

  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        surface: shell,
        primary: accent,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: shell,
      textTheme: base.textTheme.copyWith(
        headlineSmall: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: ink,
          letterSpacing: 0.2,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        bodyLarge: const TextStyle(
          fontSize: 15,
          color: ink,
          height: 1.45,
        ),
        bodyMedium: const TextStyle(
          fontSize: 13,
          color: inkMuted,
          height: 1.45,
        ),
        labelLarge: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ink,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        shadowColor: shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: borderMuted),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        hintStyle: const TextStyle(color: Color(0xFF8B948A), fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: borderMuted),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: borderMuted),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: panelStrong,
        selectedColor: accentSoft,
        labelStyle: const TextStyle(
          color: ink,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: borderMuted),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class AppThemeShell extends StatelessWidget {
  const AppThemeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.shell, Color(0xFFFDF8EB), AppTheme.shellDeep],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.24),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: -30,
              top: 120,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: AppTheme.accentSoft.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ModemStatusBar extends StatelessWidget {
  final List<StatusPillData> pills;

  const ModemStatusBar({
    super.key,
    required this.pills,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.ink,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderStrong),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: pills
            .map(
              (pill) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: pill.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: pill.color.withValues(alpha: 0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: pill.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      pill.label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class StatusPillData {
  final String label;
  final Color color;

  const StatusPillData(this.label, this.color);
}
