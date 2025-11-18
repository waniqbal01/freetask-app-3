import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2D6CE0);
  static const Color secondary = Color(0xFF6C63FF);

  static const Color neutral50 = Color(0xFFF7F8FA);
  static const Color neutral100 = Color(0xFFE4E7EC);
  static const Color neutral200 = Color(0xFFCFD4DC);
  static const Color neutral300 = Color(0xFF98A2B3);
  static const Color neutral400 = Color(0xFF667085);
  static const Color neutral500 = Color(0xFF344054);
  static const Color neutral900 = Color(0xFF101828);

  static const Color success = Color(0xFF27AE60);
  static const Color error = Color(0xFFEB5757);
}

class AppSpacing {
  AppSpacing._();

  static const double s8 = 8;
  static const double s16 = 16;
  static const double s24 = 24;

  static const SizedBox vertical8 = SizedBox(height: s8);
  static const SizedBox vertical16 = SizedBox(height: s16);
  static const SizedBox vertical24 = SizedBox(height: s24);

  static const EdgeInsets padding8 = EdgeInsets.all(s8);
  static const EdgeInsets padding16 = EdgeInsets.all(s16);
  static const EdgeInsets padding24 = EdgeInsets.all(s24);
}

class AppRadius {
  AppRadius._();

  static const double medium = 12;
  static const double large = 16;

  static const BorderRadius mediumRadius = BorderRadius.all(Radius.circular(medium));
  static const BorderRadius largeRadius = BorderRadius.all(Radius.circular(large));
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> get card => [
        BoxShadow(
          color: AppColors.neutral900.withOpacity(0.08),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ];
}

class ButtonStateColors {
  ButtonStateColors._();

  static const Color normal = AppColors.primary;
  static Color get loading => AppColors.primary.withOpacity(0.7);
  static const Color disabled = AppColors.neutral200;
}

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.neutral900,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.neutral900,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.neutral900,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral500,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral500,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.neutral500,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.neutral400,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: Colors.white,
      background: AppColors.neutral50,
      error: AppColors.error,
      brightness: Brightness.light,
    );

    final TextTheme textTheme = const TextTheme(
      headlineLarge: AppTextStyles.headlineLarge,
      headlineMedium: AppTextStyles.headlineMedium,
      headlineSmall: AppTextStyles.headlineSmall,
      bodyLarge: AppTextStyles.bodyLarge,
      bodyMedium: AppTextStyles.bodyMedium,
      bodySmall: AppTextStyles.bodySmall,
      labelSmall: AppTextStyles.labelSmall,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.neutral50,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.neutral900,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTextStyles.headlineSmall,
        surfaceTintColor: Colors.white,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        margin: const EdgeInsets.all(AppSpacing.s16),
        color: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.largeRadius,
        ),
        shadowColor: AppColors.neutral900.withOpacity(0.08),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.disabled)) return ButtonStateColors.disabled;
            if (states.contains(MaterialState.pressed) || states.contains(MaterialState.hovered)) {
              return ButtonStateColors.loading;
            }
            return ButtonStateColors.normal;
          }),
          foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
          padding: MaterialStateProperty.all<EdgeInsets>(
            const EdgeInsets.symmetric(
              vertical: AppSpacing.s16,
              horizontal: AppSpacing.s16,
            ),
          ),
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            const RoundedRectangleBorder(
              borderRadius: AppRadius.mediumRadius,
            ),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s16,
        ),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumRadius,
          borderSide: const BorderSide(color: AppColors.neutral200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumRadius,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumRadius,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumRadius,
          borderSide: const BorderSide(color: AppColors.error, width: 1.4),
        ),
        hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.neutral300),
        labelStyle: AppTextStyles.bodySmall,
      ),
      dividerColor: AppColors.neutral100,
      shadowColor: AppColors.neutral900.withOpacity(0.08),
    );
  }
}
