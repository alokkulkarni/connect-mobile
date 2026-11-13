import 'dart:convert';

import 'package:connect_banking/features/assistant/domain/conversation.dart';
import 'package:connect_banking/features/money_hub/domain/money_hub.dart';
import 'package:connect_banking/features/notifications/data/local_notification_push_source.dart';
import 'package:connect_banking/features/notifications/domain/assist_intent.dart';
import 'package:flutter_test/flutter_test.dart';

// A notification's data → what the app does (docs/CONTRACT.md section 7).
void main() {
  Map<String, Object?> data(String topic, {String intent = 'assist', String mode = 'chat', Map<String, Object?> more = const {}}) =>
      {'v': '1', 'intent': intent, 'topic': topic, 'mode': mode, ...more};

  test('each topic picks its screen and tab', () {
    final cases = <String, (IntentScreen, MoneyHubView?)>{
      'money_out': (IntentScreen.moneyHub, MoneyHubView.out),
      'spending_insight': (IntentScreen.moneyHub, MoneyHubView.out),
      'money_in': (IntentScreen.moneyHub, MoneyHubView.moneyIn),
      'salary_in': (IntentScreen.moneyHub, MoneyHubView.moneyIn),
      'low_balance': (IntentScreen.moneyHub, MoneyHubView.expected),
      'bill_due': (IntentScreen.moneyHub, MoneyHubView.expected),
      'savings_goal': (IntentScreen.moneyHub, MoneyHubView.goals),
      'transfer': (IntentScreen.accounts, null),
      'dispute_update': (IntentScreen.cardsDisputes, null),
      'mortgage': (IntentScreen.mortgages, null),
      'anything_else': (IntentScreen.home, null),
    };
    cases.forEach((topic, expected) {
      final intent = parseAssistIntent(data(topic));
      expect((intent.screen, intent.view), expected, reason: topic);
    });
  });

  test('only assist + a money topic starts a conversation by itself', () {
    expect(parseAssistIntent(data('low_balance')).autoStart, isTrue);
    expect(parseAssistIntent(data('low_balance', intent: 'open')).autoStart, isFalse);
    expect(parseAssistIntent(data('mortgage')).autoStart, isFalse);
    expect(parseAssistIntent(data('promotion')).autoStart, isFalse);
  });

  test('mode: chat unless it says call', () {
    expect(parseAssistIntent(data('low_balance', mode: 'call')).mode, ConversationKind.call);
    expect(parseAssistIntent(data('low_balance', mode: 'video')).mode, ConversationKind.chat);
  });

  test('IDs must match their pattern, or the topic falls back', () {
    final payment = parseAssistIntent(data('unusual_payment', more: {'paymentId': 'TXN-2291-20261006-34900'}));
    expect((payment.screen, payment.paymentId), (IntentScreen.cards, 'TXN-2291-20261006-34900'));
    final badPayment = parseAssistIntent(data('unusual_payment', more: {'paymentId': 'TXN-<script>'}));
    expect((badPayment.screen, badPayment.paymentId), (IntentScreen.cards, null));

    final large = parseAssistIntent(data('large_payment', more: {'transactionId': 'MH-001-20261015-0332'}));
    expect((large.screen, large.transactionId), (IntentScreen.transaction, 'MH-001-20261015-0332'));
    expect((large.fallbackScreen, large.fallbackView), (IntentScreen.moneyHub, MoneyHubView.transactions));
    final noId = parseAssistIntent(data('large_payment', more: {'transactionId': 'MH-1'}));
    expect((noId.screen, noId.view), (IntentScreen.moneyHub, MoneyHubView.transactions));
  });

  test('a known view overrides the tab; an unknown one is dropped; unknown fields are ignored', () {
    expect(parseAssistIntent(data('money_out', more: {'view': 'goals'})).view, MoneyHubView.goals);
    expect(parseAssistIntent(data('money_out', more: {'view': 'admin'})).view, MoneyHubView.out);
    expect(parseAssistIntent(data('money_out', more: {'customerId': 'CUST-002', 'amount': '9999'})).screen, IntentScreen.moneyHub);
  });

  test('any other version just opens Home', () {
    final intent = parseAssistIntent({'v': '2', 'intent': 'assist', 'topic': 'low_balance'});
    expect((intent.screen, intent.autoStart), (IntentScreen.home, false));
    expect(parseAssistIntent(const {}).screen, IntentScreen.home);
  });

  test('a local notification\'s payload is the push data, and parses the same', () {
    final push = {'v': '1', 'intent': 'assist', 'topic': 'savings_goal', 'mode': 'call'};
    final tapped = decodePayload(jsonEncode(push))!;
    final a = parseAssistIntent(push), b = parseAssistIntent(tapped);
    expect((b.screen, b.view, b.mode, b.autoStart), (a.screen, a.view, a.mode, a.autoStart));
    expect(decodePayload('not json'), isNull);
    expect(decodePayload(null), isNull);
  });
}
