import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const sun = Color(0xFFF97316);
  static const sunLight = Color(0xFFFFF0E6);
  static const coral = Color(0xFFFB7185);
  static const coralLight = Color(0xFFFFE4E9);
  static const amber = Color(0xFFFBBF24);
  static const amberLight = Color(0xFFFEF9C3);
  static const teal = Color(0xFF14B8A6);
  static const tealLight = Color(0xFFCCFBF1);
  static const violet = Color(0xFF8B5CF6);
  static const violetLight = Color(0xFFEDE9FE);
  static const sky = Color(0xFF0EA5E9);
  static const skyLight = Color(0xFFE0F2FE);
  static const green = Color(0xFF22C55E);
  static const greenLight = Color(0xFFDCFCE7);
  static const rose = Color(0xFFF43F5E);
  static const bg = Color(0xFFFFF8F3);
  static const card = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A0A00);
  static const text2 = Color(0xFF44260A);
  static const muted = Color(0xFFA8896A);
  static const border = Color(0xFFF0D9C8);
}

/// Use `context.primary` anywhere you need the school's brand color.
/// Never hardcode AppColors.sun for interactive chrome — it won't follow theme changes.
extension BuildContextTheme on BuildContext {
  Color get primary => Theme.of(this).colorScheme.primary;
  Color get primaryLight => Theme.of(this).colorScheme.primary.withOpacity(0.12);
}

/// .copyWith(primary: primary) below is load-bearing: ColorScheme.fromSeed's
/// tonal-palette algorithm does NOT guarantee colorScheme.primary equals the
/// seed you pass in (it derives its own tone/chroma, which can drift hue for
/// saturated seeds). Sixty-plus call sites read Theme.of(context).colorScheme.primary
/// directly expecting the exact school brand color, so pin it to the raw seed.
ColorScheme buildColorScheme(Color primary) =>
    ColorScheme.fromSeed(seedColor: primary, surface: AppColors.bg).copyWith(primary: primary);

ThemeData buildTheme([Color primary = AppColors.sun]) => ThemeData(
      useMaterial3: true,
      colorScheme: buildColorScheme(primary),
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: AppColors.muted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
          // Horizontal padding matters at least as much as vertical here — this
          // shape is a full stadium (radius 40), so text crowds the curved
          // ends badly without generous side padding on any button that
          // doesn't override this itself (e.g. plain ElevatedButton(child:
          // Text('Apply for Leave'))).
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        indicatorColor: primary,
        unselectedLabelColor: AppColors.muted,
      ),
      chipTheme: ChipThemeData(
        selectedColor: primary.withOpacity(0.15),
        checkmarkColor: primary,
      ),
    );
