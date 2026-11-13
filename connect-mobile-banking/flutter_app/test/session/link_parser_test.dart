import 'package:connect_banking/features/session/domain/session.dart';
import 'package:flutter_test/flutter_test.dart';

// The internet banking link, read once: its origin and its secret (docs/CONTRACT.md section 1).
void main() {
  test('reads the origin and the secret from any path', () {
    final parsed = parseLink(' https://app.example/accounts#k=abcdefghijklmnopQRST_-12 ');
    expect(parsed.ok, isTrue);
    expect(parsed.origin.toString(), 'https://app.example');
    expect(parsed.secret, 'abcdefghijklmnopQRST_-12');
  });

  test('keeps a port', () {
    expect(parseLink('https://app.example:8443/#k=abcdefghijklmnop').origin.toString(), 'https://app.example:8443');
  });

  test('refuses anything but https', () {
    expect(parseLink('http://app.example/#k=abcdefghijklmnop').ok, isFalse);
    expect(parseLink('myapp://open#k=abcdefghijklmnop').ok, isFalse);
  });

  test('refuses a missing, short, long or odd secret', () {
    expect(parseLink('https://app.example/').ok, isFalse);
    expect(parseLink('https://app.example/#k=short').ok, isFalse);
    expect(parseLink('https://app.example/#k=${'a' * 129}').ok, isFalse);
    expect(parseLink('https://app.example/#k=abcdefghijklmnop%20x').ok, isFalse);
    expect(parseLink('https://app.example/?k=abcdefghijklmnop').ok, isFalse);
    expect(parseLink('not a link').ok, isFalse);
  });
}
