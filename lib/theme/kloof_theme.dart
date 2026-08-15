import 'package:flutter/material.dart';

abstract final class KloofColors {
  static const deepBlack = Color(0xFF080808);
  static const primaryBlack = Color(0xFF111111);
  static const cardBackground = Color(0xFFFFFFFF);
  static const secondarySurface = Color(0xFFF2F0EB);
  static const luxuryGold = Color(0xFFC89A5B);
  static const softGold = Color(0xFFD9B57A);
  static const mutedGold = Color(0xFFA77B4C);
  static const primaryText = Color(0xFF111111);
  static const secondaryText = Color(0xFF6F6F6F);
  static const mutedText = Color(0xFFA0A0A0);
  static const border = Color(0xFFE8E4DD);
  static const success = Color(0xFF2F7D4A);
  static const warning = Color(0xFFC58A22);
  static const error = Color(0xFFB64A44);
  static const warmOffWhite = Color(0xFFF8F7F4);
}

abstract final class KloofTheme {
  static const _radius = 14.0;

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: KloofColors.primaryBlack,
      onPrimary: Colors.white,
      secondary: KloofColors.luxuryGold,
      onSecondary: KloofColors.primaryBlack,
      surface: KloofColors.cardBackground,
      onSurface: KloofColors.primaryText,
      error: KloofColors.error,
      onError: Colors.white,
      outline: KloofColors.border,
      outlineVariant: KloofColors.border,
    );

    final baseTextTheme = ThemeData.light(useMaterial3: true).textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: KloofColors.warmOffWhite,
      canvasColor: KloofColors.warmOffWhite,
      dividerColor: KloofColors.border,
      textTheme: baseTextTheme.copyWith(
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          color: KloofColors.primaryText,
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: KloofColors.primaryText,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: KloofColors.primaryText,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: KloofColors.primaryText,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: KloofColors.primaryText,
          height: 1.45,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: KloofColors.primaryText,
          height: 1.4,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          color: KloofColors.secondaryText,
          height: 1.35,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: KloofColors.warmOffWhite,
        foregroundColor: KloofColors.primaryText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: KloofColors.primaryText),
        titleTextStyle: TextStyle(
          color: KloofColors.primaryText,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: KloofColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: const BorderSide(color: KloofColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: KloofColors.cardBackground,
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: const TextStyle(color: KloofColors.secondaryText),
        labelStyle: const TextStyle(color: KloofColors.secondaryText),
        prefixIconColor: KloofColors.secondaryText,
        suffixIconColor: KloofColors.secondaryText,
        helperStyle: const TextStyle(color: KloofColors.mutedText),
        errorStyle: const TextStyle(color: KloofColors.error),
        border: _inputBorder(),
        enabledBorder: _inputBorder(),
        focusedBorder: _inputBorder(KloofColors.luxuryGold, 1.5),
        errorBorder: _inputBorder(KloofColors.error),
        focusedErrorBorder: _inputBorder(KloofColors.error, 1.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: KloofColors.primaryBlack,
          foregroundColor: Colors.white,
          disabledBackgroundColor: KloofColors.primaryBlack.withValues(
            alpha: 0.35,
          ),
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 22,
            vertical: 14,
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: KloofColors.primaryBlack,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: KloofColors.primaryBlack,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: KloofColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: KloofColors.primaryBlack,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: KloofColors.cardBackground,
        selectedColor: KloofColors.primaryBlack,
        disabledColor: KloofColors.border,
        side: const BorderSide(color: KloofColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(color: KloofColors.primaryText),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        checkmarkColor: KloofColors.luxuryGold,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: KloofColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: KloofColors.primaryBlack,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: KloofColors.luxuryGold,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? KloofColors.luxuryGold
              : KloofColors.secondaryText,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? KloofColors.softGold.withValues(alpha: 0.45)
              : KloofColors.border,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: KloofColors.border,
        thickness: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: KloofColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: KloofColors.cardBackground,
        modalBarrierColor: Colors.black54,
        showDragHandle: true,
        dragHandleColor: KloofColors.mutedGold,
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: const WidgetStatePropertyAll(
          KloofColors.cardBackground,
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(color: KloofColors.primaryText),
        ),
        hintStyle: const WidgetStatePropertyAll(
          TextStyle(color: KloofColors.mutedText),
        ),
        side: const WidgetStatePropertyAll(
          BorderSide(color: KloofColors.border),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder([
    Color color = KloofColors.border,
    double width = 1,
  ]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(_radius),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
