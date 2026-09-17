import 'package:flutter/material.dart';

/// Kipt design system.
///
/// One UI-style: cool neutral surfaces, white rounded cards with hairline
/// borders, generous whitespace, pill-shaped primary actions, and the brand
/// teal (#39A099) as the single accent. Both light and dark palettes are
/// derived from the same hue family so the whole app — and the exported PDFs
/// that read from these colors — stays consistent.
class AppTheme {
  // Brand accent (sampled from the Kipt logo / poster).
  static const Color brandTeal = Color(0xFF39A099);
  static const Color brandTealDeep = Color(0xFF0C5450);

  // Light palette.
  static const Color lightSurface = Color(0xFFF5F8F8);
  static const Color lightSurfaceCard = Color(0xFFFFFFFF);
  static const Color lightOnSurface = Color(0xFF1B2221);
  static const Color lightOnSurfaceVariant = Color(0xFF5E6B69);
  static const Color lightOutline = Color(0xFFB7C6C3);
  static const Color lightOutlineVariant = Color(0xFFDCE7E5);
  static const Color lightSurfaceContainerHigh = Color(0xFFE4EFEE);

  // Dark palette.
  static const Color darkSurface = Color(0xFF101416);
  static const Color darkSurfaceCard = Color(0xFF181D1F);
  static const Color darkOnSurface = Color(0xFFE9EEEF);
  static const Color darkOnSurfaceVariant = Color(0xFFAAB5B7);
  static const Color darkOutline = Color(0xFF566367);
  static const Color darkOutlineVariant = Color(0xFF394347);
  static const Color darkSurfaceContainerHigh = Color(0xFF293135);

  static ColorScheme get lightColorScheme => const ColorScheme.light(
    primary: brandTeal,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFD2EFEC),
    onPrimaryContainer: Color(0xFF0C5450),
    secondary: Color(0xFF4F7A76),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFD6EAE7),
    onSecondaryContainer: Color(0xFF0E4B47),
    tertiary: Color(0xFFB67D1E),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFFAF0DC),
    onTertiaryContainer: Color(0xFF5F4506),
    error: Color(0xFFD04A41),
    onError: Colors.white,
    errorContainer: Color(0xFFFAE1DE),
    onErrorContainer: Color(0xFF772D26),
    surface: lightSurface,
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: lightSurfaceCard,
    surfaceContainer: Color(0xFFEDF4F3),
    surfaceContainerHigh: lightSurfaceContainerHigh,
    surfaceContainerHighest: Color(0xFFD9E7E5),
    onSurface: lightOnSurface,
    onSurfaceVariant: lightOnSurfaceVariant,
    outline: lightOutline,
    outlineVariant: lightOutlineVariant,
    inverseSurface: lightOnSurface,
    onInverseSurface: Color(0xFFF2F7F6),
    shadow: Color(0xFF24424A),
  );

  static ColorScheme get darkColorScheme => const ColorScheme.dark(
    primary: Color(0xFF68CEC3),
    onPrimary: Color(0xFF073A36),
    primaryContainer: Color(0xFF1C514C),
    onPrimaryContainer: Color(0xFFB9ECE5),
    secondary: Color(0xFFA5B8B6),
    onSecondary: Color(0xFF263332),
    secondaryContainer: Color(0xFF3A4847),
    onSecondaryContainer: Color(0xFFD5E5E2),
    tertiary: Color(0xFFE5B866),
    onTertiary: Color(0xFF3D2E0D),
    tertiaryContainer: Color(0xFF59461F),
    onTertiaryContainer: Color(0xFFFFE1A8),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF541A16),
    errorContainer: Color(0xFF642D29),
    onErrorContainer: Color(0xFFFFDAD5),
    surface: darkSurface,
    surfaceContainerLowest: Color(0xFF0A0D0E),
    surfaceContainerLow: darkSurfaceCard,
    surfaceContainer: Color(0xFF202629),
    surfaceContainerHigh: darkSurfaceContainerHigh,
    surfaceContainerHighest: Color(0xFF343D41),
    onSurface: darkOnSurface,
    onSurfaceVariant: darkOnSurfaceVariant,
    outline: darkOutline,
    outlineVariant: darkOutlineVariant,
    inverseSurface: darkOnSurface,
    onInverseSurface: Color(0xFF161B1D),
    shadow: Color(0xFF000000),
  );

  static ThemeData get lightTheme => _buildTheme(lightColorScheme);

  static ThemeData get darkTheme => _buildTheme(darkColorScheme);

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final isLight = colorScheme.brightness == Brightness.light;
    final background = colorScheme.surface;

    final baseText = ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      fontFamily: 'Inter',
    ).textTheme;

    final textTheme = baseText.copyWith(
      displayLarge: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: colorScheme.onSurface,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: colorScheme.onSurface,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: colorScheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: colorScheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: colorScheme.onSurfaceVariant,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.4,
        color: colorScheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.4,
        color: colorScheme.onSurface,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    );

    BorderRadius cardRadius = BorderRadius.circular(16);
    BorderRadius fieldRadius = BorderRadius.circular(12);
    BorderRadius buttonRadius = BorderRadius.circular(12);

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      fontFamily: 'Inter',
      textTheme: textTheme,
      scaffoldBackgroundColor: background,
      shadowColor: isLight ? colorScheme.shadow.withValues(alpha: 0.05) : null,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 24),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: cardRadius),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: colorScheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: buttonRadius),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: buttonRadius),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          height: 1.4,
          color: colorScheme.onSurfaceVariant,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: buttonRadius),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: colorScheme.onInverseSurface,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 3,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        selectedColor: colorScheme.primary,
        disabledColor: colorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
        secondaryLabelStyle: TextStyle(
          color: colorScheme.onPrimary,
          fontSize: 13,
        ),
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: TextStyle(color: colorScheme.onSurface, fontSize: 14),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return colorScheme.surfaceContainerHighest;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
        circularTrackColor: colorScheme.surfaceContainerHighest,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(color: colorScheme.onInverseSurface, fontSize: 12),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
