import 'package:flutter/material.dart';

/// 现代静谧纸感字阶、圆角与间距系统标尺
abstract final class SoftRadius {
  static const double control = 12.0;
  static const double subCard = 18.0;
  static const double card = 24.0;
  static const double sheet = 28.0;
  static const double pill = 9999.0;
}

abstract final class SoftSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 28.0;

  /// 悬浮药丸底栏留白高度（含安全区外净空）
  static const double dockClearance = 104.0;
}

abstract final class SoftTypography {
  static const TextStyle displayTitle = TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    height: 1.25,
  );

  static const TextStyle eyebrow = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    height: 1.2,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 15.5,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    height: 1.3,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 15.0,
    fontWeight: FontWeight.w700,
    height: 1.35,
  );

  static const TextStyle body = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle micro = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );
}
