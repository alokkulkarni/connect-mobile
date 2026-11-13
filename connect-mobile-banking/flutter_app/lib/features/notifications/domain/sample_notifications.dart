import '../../../core/format/money.dart';
import '../../cards/domain/cards.dart';
import '../../money_hub/domain/money_hub.dart';
import '../../transactions/domain/transactions.dart';

// The sample notifications on the Notifications screen, built from the customer's own data, each with a fixed
// mode so both chat and call can be shown. docs/CONTRACT.md section 7, "Simulated push: real local notifications".

class SampleNotification {
  const SampleNotification({required this.id, required this.title, required this.body, required this.data});

  final int id; // the local notification's ID
  final String title;
  final String body;
  final Map<String, String> data; // exactly what a push's `data` would carry

  String get topic => data['topic'] ?? '';
  String get mode => data['mode'] ?? 'chat';
}

Map<String, String> _data(String topic, String mode, {String paymentId = '', String transactionId = ''}) => {
      'v': '1',
      'intent': 'assist',
      'topic': topic,
      'mode': mode,
      if (paymentId.isNotEmpty) 'paymentId': paymentId,
      if (transactionId.isNotEmpty) 'transactionId': transactionId,
    };

String _tap(String mode) => mode == 'call' ? 'Tap to call us.' : 'Tap to chat with us.';

/// The five samples (fewer when the data has nothing for one).
List<SampleNotification> sampleNotifications({
  required CardsView cards,
  required MoneyHub hub,
  required List<Transaction> firstPage,
}) {
  final out = <SampleNotification>[];

  // The largest credit card payment (the newest, if two are the same), as "unusual".
  final credit = cards.payments.where((p) => p.card == 'credit').toList()
    ..sort((a, b) => a.amount != b.amount ? b.amount.compareTo(a.amount) : b.date.compareTo(a.date));
  if (credit.isNotEmpty) {
    final p = credit.first;
    out.add(SampleNotification(
      id: 101,
      title: 'Did you make this payment?',
      body: '${gbp(p.amount)} at ${tidyMerchant(p.merchant)} on your credit card ending ${p.ending}. ${_tap('chat')}',
      data: _data('unusual_payment', 'chat', paymentId: p.id),
    ));
  }

  // The next bills in the forecast, against the balance.
  final bills = [for (final m in hub.forecast.months) ...m.regularOut]..sort((a, b) => a.date.compareTo(b.date));
  if (bills.isNotEmpty) {
    final next = bills.first;
    out.add(SampleNotification(
      id: 102,
      title: 'Your balance is getting low',
      body: '${gbp(hub.overview.balance)} left, and ${next.merchantName} (${gbp(next.amount)}) is due on ${day(next.date)}. ${_tap('call')}',
      data: _data('low_balance', 'call'),
    ));
  }

  // The salary.
  final salary = hub.recurring.where((r) => r.category == 'salary').firstOrNull;
  if (salary != null) {
    out.add(SampleNotification(
      id: 103,
      title: 'Your salary has arrived',
      body: '${gbp(salary.amount)} from ${salary.merchantName} is in your current account. ${_tap('chat')}',
      data: _data('salary_in', 'chat'),
    ));
  }

  // The first savings goal.
  final goal = hub.goals.firstOrNull;
  if (goal != null) {
    out.add(SampleNotification(
      id: 104,
      title: 'Your ${goal.name} goal',
      body: '${gbp(goal.saved)} of ${gbp(goal.target)} saved. Put aside ${gbp(goal.neededPerMonth)} a month to get there. ${_tap('call')}',
      data: _data('savings_goal', 'call'),
    ));
  }

  // The largest money-out transaction on the first page.
  final outgoing = firstPage.where((t) => t.amount < 0).toList()..sort((a, b) => a.amount.compareTo(b.amount));
  if (outgoing.isNotEmpty) {
    final t = outgoing.first;
    out.add(SampleNotification(
      id: 105,
      title: 'A large payment left your account',
      body: '${gbp(t.amount.abs())} to ${t.merchantName} on ${day(t.date)}. ${_tap('chat')}',
      data: _data('large_payment', 'chat', transactionId: t.id),
    ));
  }
  return out;
}
