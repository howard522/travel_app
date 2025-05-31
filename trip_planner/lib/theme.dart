import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animations/animations.dart';   // ← 新增

/// 全域顏色種子
const _seed = Color(0xFF4CA7A4);

final _lightScheme = ColorScheme.fromSeed(
  seedColor: _seed,
  brightness: Brightness.light,
);
final _darkScheme = ColorScheme.fromSeed(
  seedColor: _seed,
  brightness: Brightness.dark,
);

class AppTheme {
  static ThemeData light() => _theme(_lightScheme);
  static ThemeData dark()  => _theme(_darkScheme);

  static ThemeData _theme(ColorScheme scheme) {
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: GoogleFonts.notoSans().fontFamily,
    );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.background,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        elevation: 0,
        titleTextStyle: GoogleFonts.notoSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onPrimaryContainer,
        ),
      ),
      cardTheme: CardTheme(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      // ❌ 不能加 const，因為 builder 不是 const 物件
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
          TargetPlatform.iOS: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
        },
      ),
      inputDecorationTheme:
          const InputDecorationTheme(border: OutlineInputBorder()),
      visualDensity: VisualDensity.standard,
    );
  }
}
