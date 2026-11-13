import '../../assistant/domain/conversation.dart';
import '../../assistant/domain/screen_context.dart';
import '../../money_hub/domain/money_hub.dart';

// A notification about money opens the right screen and starts a chat or call there, so the right assistant has
// the right context from the first word. docs/CONTRACT.md section 7. The notification's `data` carries no secret, no
// customer ID and no amount the app trusts: it is validated here and only ever picks a screen.

enum IntentScreen { home, accounts, cards, cardsDisputes, moneyHub, transaction, mortgages }

class AssistIntent {
  const AssistIntent({
    required this.topic,
    required this.mode,
    required this.screen,
    required this.autoStart,
    this.view,
    this.paymentId,
    this.transactionId,
    this.fallbackScreen = IntentScreen.home,
    this.fallbackView,
  });

  final String topic;
  final ConversationKind mode;
  final IntentScreen screen;
  final MoneyHubView? view;
  final String? paymentId;
  final String? transactionId;

  /// assist + a money topic: start the conversation once the screen is showing.
  final bool autoStart;

  /// Where to go when the payment or transaction isn't found.
  final IntentScreen fallbackScreen;
  final MoneyHubView? fallbackView;

  static const openHome = AssistIntent(topic: '', mode: ConversationKind.chat, screen: IntentScreen.home, autoStart: false);
}

final paymentIdPattern = RegExp(r'^TXN-\d{4}-\d{8}-\d{1,9}$');
final transactionIdPattern = RegExp(r'^MH-\d{3}-\d{8}-\d{4}$');

/// The money topics: those that may start a conversation by themselves.
const moneyTopics = {
  'unusual_payment', 'large_payment', 'money_out', 'money_in', 'salary_in', 'low_balance', 'bill_due',
  'savings_goal', 'transfer', 'spending_insight', 'dispute_update',
};

String? _string(Object? value) => value is String && value.isNotEmpty ? value : null;

/// The notification's `data` → what the app will do. Unknown fields are ignored; IDs that don't match their
/// pattern are dropped; an unknown `view` is dropped; anything but version "1" just opens Home.
AssistIntent parseAssistIntent(Map<String, Object?> data) {
  if (data['v'] != '1') return AssistIntent.openHome;
  final topic = _string(data['topic']) ?? '';
  final mode = data['mode'] == 'call' ? ConversationKind.call : ConversationKind.chat;
  final paymentId = _string(data['paymentId']);
  final transactionId = _string(data['transactionId']);
  final validPayment = paymentId != null && paymentIdPattern.hasMatch(paymentId) ? paymentId : null;
  final validTransaction = transactionId != null && transactionIdPattern.hasMatch(transactionId) ? transactionId : null;
  final view = MoneyHubView.fromKey(_string(data['view']));
  final autoStart = data['intent'] == 'assist' && moneyTopics.contains(topic);

  AssistIntent build(IntentScreen screen, {MoneyHubView? tab, IntentScreen? fallback, MoneyHubView? fallbackView}) => AssistIntent(
        topic: topic,
        mode: mode,
        screen: screen,
        autoStart: autoStart,
        view: screen == IntentScreen.moneyHub ? (view ?? tab) : null,
        paymentId: screen == IntentScreen.cards ? validPayment : null,
        transactionId: screen == IntentScreen.transaction ? validTransaction : null,
        fallbackScreen: fallback ?? screen,
        fallbackView: fallbackView ?? (screen == IntentScreen.moneyHub ? (view ?? tab) : null),
      );

  return switch (topic) {
    'unusual_payment' => build(IntentScreen.cards, fallback: IntentScreen.cards),
    'large_payment' => validTransaction == null
        ? build(IntentScreen.moneyHub, tab: MoneyHubView.transactions)
        : build(IntentScreen.transaction, fallback: IntentScreen.moneyHub, fallbackView: MoneyHubView.transactions),
    'money_out' || 'spending_insight' => build(IntentScreen.moneyHub, tab: MoneyHubView.out),
    'money_in' || 'salary_in' => build(IntentScreen.moneyHub, tab: MoneyHubView.moneyIn),
    'low_balance' || 'bill_due' => build(IntentScreen.moneyHub, tab: MoneyHubView.expected),
    'savings_goal' => build(IntentScreen.moneyHub, tab: MoneyHubView.goals),
    'transfer' => build(IntentScreen.accounts),
    'dispute_update' => build(IntentScreen.cardsDisputes),
    'mortgage' => build(IntentScreen.mortgages),
    _ => build(IntentScreen.home),
  };
}

/// The context a screen must have published before a notification starts the conversation there: the same page,
/// and the tab or payment when the intent names one. Without it, a screen that was already open could start the
/// conversation with its old tab. docs/CONTRACT.md section 7, step 4.
class ContextExpectation {
  const ContextExpectation({required this.page, this.view, this.paymentId});

  final String page;
  final String? view;
  final String? paymentId;

  bool matches(ScreenContext context) =>
      context.page == page && (view == null || context.view == view) && (paymentId == null || context.paymentId == paymentId);
}

/// What the screen the app went to will say, once it has caught up. [paymentId]: the payment chosen on Cards.
ContextExpectation expectedContext(IntentScreen screen, {MoneyHubView? view, String? paymentId}) => switch (screen) {
      IntentScreen.home => const ContextExpectation(page: 'home'),
      IntentScreen.accounts => const ContextExpectation(page: 'accounts'),
      IntentScreen.cards => paymentId == null
          ? const ContextExpectation(page: 'cards')
          : ContextExpectation(page: 'card_dispute', paymentId: paymentId),
      IntentScreen.cardsDisputes => const ContextExpectation(page: 'cards'),
      IntentScreen.moneyHub => ContextExpectation(page: 'money_hub', view: (view ?? MoneyHubView.out).key),
      IntentScreen.transaction => const ContextExpectation(page: 'money_hub', view: 'transactions'),
      IntentScreen.mortgages => const ContextExpectation(page: 'mortgages'),
    };

/// How long a notification waits for its screen to say where the customer is, before starting anyway.
const intentContextWait = Duration(seconds: 6);

/// Where real and simulated notifications come from. Each tap gives the notification's `data`.
abstract interface class PushSource {
  /// Set up; does nothing (and never throws) when this source isn't configured.
  Future<void> start();

  /// The data of the notification that launched the app, if one did (read once).
  Future<Map<String, Object?>?> launchData();

  /// The data of each notification tapped while the app is running.
  Stream<Map<String, Object?>> get taps;

  /// Notifications that arrive while the app is open and aren't shown by the system: the app shows a banner.
  Stream<({String title, String body, Map<String, Object?> data})> get foreground;
}

enum NotifyPermission { granted, refused }

/// Shows a notification from the phone itself, a little later (the simulated push).
abstract interface class LocalNotifier {
  Future<NotifyPermission> ensurePermission();
  Future<void> showLater({required int id, required String title, required String body, required Map<String, String> data, required Duration after});

  /// Shows a notification at once (a push that arrived while the app was open, shown again so its tap goes to the
  /// same handler).
  Future<void> showNow({required int id, required String title, required String body, required Map<String, Object?> data});
}
