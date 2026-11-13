import 'package:intl/intl.dart';

// Amounts and dates written as the web app writes them (connect-banking-app/web/lib.js): pounds with two
// decimals and a real minus sign, dates as "15 Oct".

final _pounds = NumberFormat('#,##0.00', 'en_GB');
final _wholePounds = NumberFormat('#,##0', 'en_GB');

/// £1,234.56, or −£1,234.56 for a negative amount.   [lib.js gbp]
String gbp(num amount) => '${amount < 0 ? '−' : ''}£${_pounds.format(amount.abs())}';

/// £1,235: whole pounds, for headlines.   [lib.js pounds]
String pounds(num amount) => '£${_wholePounds.format(amount.round())}';

/// +£3,150.00 when money comes in, −£32.45 when it goes out.
String signed(num amount, {required bool moneyIn}) => '${moneyIn ? '+' : '−'}£${_pounds.format(amount.abs())}';

// Dates in English, without locale data (the app has no localisation set up, and needs none for this).
const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

DateTime _noon(String iso) => DateTime.parse('${iso}T12:00:00');

/// "15 Oct".   [lib.js day]
String day(String iso) {
  final d = _noon(iso);
  return '${d.day} ${_months[d.month - 1].substring(0, 3)}';
}

/// "15 October": for the words a customer might send.
String dayMonth(String iso) {
  final d = _noon(iso);
  return '${d.day} ${_months[d.month - 1]}';
}

/// "Thursday 15 October".   [lib.js longDay]
String longDay(String iso) {
  final d = _noon(iso);
  return '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
}

/// "October 2026" from "2026-10".   [lib.js monthName]
String monthName(String key) {
  final d = _noon('$key-15');
  return '${_months[d.month - 1]} ${d.year}';
}

/// "Oct" from "2026-10".
String shortMonth(String key) => _months[_noon('$key-15').month - 1].substring(0, 3);

/// "Tesco Stores" from "TESCO STORES".   [lib.js tidyMerchant]
String tidyMerchant(String name) => name.toLowerCase().replaceAllMapped(
      RegExp(r'(^|[\s/-])([a-z])'),
      (m) => '${m[1]}${m[2]!.toUpperCase()}',
    );

/// Up to two initials for a merchant's tile.
String initials(String name) {
  final words = name.split(RegExp(r'[\s/.-]+')).where((w) => w.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(w[0]));
  return words.take(2).map((w) => w[0].toUpperCase()).join();
}
