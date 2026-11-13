import 'package:connect_banking/core/format/money.dart';
import 'package:connect_banking/features/assistant/domain/chat_rules.dart';
import 'package:flutter_test/flutter_test.dart';

// Amounts, dates and message text written as the web app writes them.
void main() {
  test('pounds', () {
    expect(gbp(1234.5), '£1,234.50');
    expect(gbp(-32.45), '−£32.45'); // a real minus sign
    expect(gbp(0), '£0.00');
    expect(pounds(3579.31), '£3,579');
    expect(signed(3150, moneyIn: true), '+£3,150.00');
    expect(signed(-32.45, moneyIn: false), '−£32.45');
  });

  test('dates', () {
    expect(day('2026-10-15'), '15 Oct');
    expect(dayMonth('2026-10-05'), '5 October');
    expect(longDay('2026-10-15'), 'Thursday 15 October');
    expect(monthName('2026-07'), 'July 2026');
  });

  test('merchants', () {
    expect(tidyMerchant('ELECTROWORLD ONLINE'), 'Electroworld Online');
    expect(initials('Nationwide Mortgage'), 'NM');
    expect(initials('Amazon'), 'A');
  });

  test('message text', () {
    expect(plain('You spent **£32.45** at __Amazon__'), 'You spent £32.45 at Amazon');
    expect(isReturnNote('  Back from card dispute: done'), isTrue);
    expect(isReturnNote('Back from holiday'), isFalse);
    expect([for (final p in amountParts('£1,050.00 then −£3.20.')) if (p.amount) p.text], ['£1,050.00', '−£3.20']);
  });
}
