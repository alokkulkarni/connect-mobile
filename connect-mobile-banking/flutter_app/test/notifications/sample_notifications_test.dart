import 'dart:convert';
import 'dart:io';

import 'package:connect_banking/features/cards/data/cards_repository_impl.dart';
import 'package:connect_banking/features/cards/domain/cards.dart';
import 'package:connect_banking/features/money_hub/data/money_hub_repository_impl.dart';
import 'package:connect_banking/features/notifications/domain/assist_intent.dart';
import 'package:connect_banking/features/notifications/domain/sample_notifications.dart';
import 'package:connect_banking/features/transactions/data/transactions_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

// The five sample notifications, built from the sample customer's own data (the bundled fixtures).
void main() {
  Map<String, dynamic> fixture(String name) => jsonDecode(File('assets/fixtures/$name.json').readAsStringSync()) as Map<String, dynamic>;

  final cardsJson = fixture('app_cards');
  final cards = CardsView(cards: cardsFromJson(cardsJson['cards']), payments: paymentsFromJson(cardsJson['payments']));
  final hub = moneyHubFromJson(fixture('hub'));
  final first = [for (final t in fixture('transactions_p1')['transactions'] as List) transactionFromJson(t as Map<String, dynamic>)];
  final samples = sampleNotifications(cards: cards, hub: hub, firstPage: first);

  test('five samples, in order, with their fixed modes', () {
    expect([for (final s in samples) (s.topic, s.mode)], [
      ('unusual_payment', 'chat'),
      ('low_balance', 'call'),
      ('salary_in', 'chat'),
      ('savings_goal', 'call'),
      ('large_payment', 'chat'),
    ]);
    expect(samples.map((s) => s.id).toSet(), hasLength(5));
  });

  test('worded from the data, ending with what a tap does', () {
    final unusual = samples.first;
    expect(unusual.title, 'Did you make this payment?');
    // The largest credit card payment, not the newest (Netflix, £10.99).
    expect(unusual.body, '£612.00 at Sunshine Villas Booking on your credit card ending 2291. Tap to chat with us.');
    expect(unusual.data['paymentId'], 'TXN-2291-20261004-61200');
    expect(samples[1].body, endsWith('Tap to call us.'));
    expect(samples[3].title, 'Your Holiday in Japan goal');
  });

  test('their IDs are valid and are the customer\'s own', () {
    final paymentId = samples.first.data['paymentId']!;
    expect(paymentIdPattern.hasMatch(paymentId), isTrue);
    expect(cards.payment(paymentId)?.card, 'credit');
    final transactionId = samples.last.data['transactionId']!;
    expect(transactionIdPattern.hasMatch(transactionId), isTrue);
    expect(first.any((t) => t.id == transactionId && t.amount < 0), isTrue);
  });

  test('each is a money notification that starts its own mode', () {
    for (final s in samples) {
      final intent = parseAssistIntent(s.data);
      expect(intent.autoStart, isTrue, reason: s.topic);
      expect(intent.mode.name, s.mode, reason: s.topic);
    }
    expect(parseAssistIntent(samples.first.data).screen, IntentScreen.cards);
    expect(parseAssistIntent(samples.last.data).screen, IntentScreen.transaction);
  });
}
