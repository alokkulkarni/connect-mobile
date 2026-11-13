import 'package:flutter/material.dart';

// The internet banking web app's colours (connect-banking-app/web/styles.css), light and dark, so the app and the
// web app look like one bank. docs/CONTRACT.md section 11.
@immutable
class BankColors extends ThemeExtension<BankColors> {
  const BankColors({
    required this.brand,
    required this.brand2,
    required this.ink,
    required this.muted,
    required this.line,
    required this.background,
    required this.card,
    required this.moneyIn,
    required this.moneyInSoft,
    required this.moneyOut,
    required this.moneyOutSoft,
    required this.flexible,
    required this.essential,
    required this.savings,
  });

  final Color brand, brand2, ink, muted, line, background, card;
  final Color moneyIn, moneyInSoft, moneyOut, moneyOutSoft, flexible, essential, savings;

  static const light = BankColors(
    brand: Color(0xFF1A2B5F),
    brand2: Color(0xFF2A3F86),
    ink: Color(0xFF101631),
    muted: Color(0xFF5D6482),
    line: Color(0xFFE5E8F2),
    background: Color(0xFFF3F5FB),
    card: Color(0xFFFFFFFF),
    moneyIn: Color(0xFF0F8A66),
    moneyInSoft: Color(0xFFE5F5EF),
    moneyOut: Color(0xFFC63D3D),
    moneyOutSoft: Color(0xFFFBEAEA),
    flexible: Color(0xFFE08A1E),
    essential: Color(0xFF4864E6),
    savings: Color(0xFF7B5CFF),
  );

  static const dark = BankColors(
    brand: Color(0xFF2A3F86),
    brand2: Color(0xFF3A52A8),
    ink: Color(0xFFE8EBF7),
    muted: Color(0xFF9AA1BD),
    line: Color(0xFF2A3150),
    background: Color(0xFF0D1226),
    card: Color(0xFF151B34),
    moneyIn: Color(0xFF34C294),
    moneyInSoft: Color(0xFF12352C),
    moneyOut: Color(0xFFF07A7A),
    moneyOutSoft: Color(0xFF3A1C22),
    flexible: Color(0xFFF2A64A),
    essential: Color(0xFF7D93FF),
    savings: Color(0xFFA48CFF),
  );

  static const radius = 16.0;

  @override
  BankColors copyWith() => this;

  @override
  BankColors lerp(ThemeExtension<BankColors>? other, double t) => t < 0.5 ? this : (other as BankColors? ?? this);
}

extension BankColorsOf on BuildContext {
  BankColors get bank => Theme.of(this).extension<BankColors>() ?? BankColors.light;
}
