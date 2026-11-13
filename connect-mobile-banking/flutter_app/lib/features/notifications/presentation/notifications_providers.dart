import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cards/presentation/cards_providers.dart';
import '../../money_hub/presentation/money_hub_providers.dart';
import '../../transactions/domain/transactions.dart';
import '../../transactions/presentation/transactions_providers.dart';
import '../data/firebase_push_source.dart';
import '../data/local_notification_push_source.dart';
import '../domain/assist_intent.dart';
import '../domain/sample_notifications.dart';
import 'intent_runner.dart';

final localNotificationsProvider = Provider<LocalNotificationPushSource>((ref) => LocalNotificationPushSource());

/// Shows the simulated push.
final localNotifierProvider = Provider<LocalNotifier>((ref) => ref.watch(localNotificationsProvider));

/// Every source of notifications: the simulated push, and a real push service when the app is configured for one.
final pushSourcesProvider = Provider<List<PushSource>>((ref) => [ref.watch(localNotificationsProvider), FirebasePushSource()]);

/// The one handler for notifications, set by the app once its router exists.
class IntentRunnerHolder {
  IntentRunner? runner;
}

final intentRunnerHolderProvider = Provider<IntentRunnerHolder>((ref) => IntentRunnerHolder());

/// The sample notifications, from the customer's own data.
final sampleNotificationsProvider = FutureProvider<List<SampleNotification>>((ref) async {
  final cards = await ref.watch(cardsViewProvider.future);
  final hub = await ref.watch(moneyHubProvider.future);
  final first = await ref.watch(transactionsRepositoryProvider).list(const TransactionFilter());
  return sampleNotifications(cards: cards, hub: hub, firstPage: first.transactions);
});
