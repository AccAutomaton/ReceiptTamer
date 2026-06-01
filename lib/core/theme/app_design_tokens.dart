import 'package:flutter/material.dart';

class AppPalette {
  const AppPalette._();

  static const coldBackground = Color(0xFFF6F9FA);
  static const mistBlue = Color(0xFFDFE9ED);
  static const primaryMuted = Color(0xFF78939D);
  static const amountMuted = Color(0xFF486A74);
  static const textPrimary = Color(0xFF19232B);
  static const textSecondary = Color(0xFF697781);
  static const outlineMuted = Color(0xFFCAD7DD);
  static const cardFill = Color(0xF7FFFFFF);
  static const elevatedFill = Color(0xFFEAF2F5);
  static const selectedFill = Color(0xFFE2EDF1);
  static const successMuted = Color(0xFF6F8E7A);
  static const warningMuted = Color(0xFF9A8667);
  static const errorMuted = Color(0xFFA76F72);
  static const shadowMuted = Color(0x2419232B);
  static const shadowDeep = Color(0x3019232B);
  static const frostHighlight = Color(0xBFFFFFFF);
  static const frostLine = Color(0x66B9C9D0);
  static const darkSurface = Color(0xFF131B22);
}

class AppRadii {
  const AppRadii._();

  static const card = 22.0;
  static const control = 18.0;
  static const chip = 999.0;
  static const glassLarge = 28.0;
  static const nav = 999.0;
  static const sheet = 30.0;
}

class AppGlassTokens {
  const AppGlassTokens._();

  static const blurSigma = 22.0;
  static const lightFill = Color(0xAAFFFFFF);
  static const darkFill = Color(0x9E232F39);
  static const lightBorder = Color(0xD8FFFFFF);
  static const darkBorder = Color(0x1FFFFFFF);
  static const sheetFill = Color(0xF4FFFFFF);
  static const contentFill = Color(0xF7FFFFFF);
  static const refractionTint = Color(0x2B8BA5AE);
  static const innerHairline = Color(0x8FFFFFFF);
  static const navHeight = 62.0;
  static const navCenterSlotWidth = 74.0;
  static const navCenterButtonSize = 68.0;
}

class AppShadows {
  const AppShadows._();

  static const card = [
    BoxShadow(
      color: AppPalette.shadowMuted,
      blurRadius: 22,
      offset: Offset(0, 10),
    ),
  ];

  static const glass = [
    BoxShadow(
      color: AppPalette.shadowDeep,
      blurRadius: 34,
      spreadRadius: -8,
      offset: Offset(0, 18),
    ),
    BoxShadow(color: Color(0x52FFFFFF), blurRadius: 1, offset: Offset(0, -1)),
  ];
}
