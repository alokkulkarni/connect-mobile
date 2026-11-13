import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../assistant/domain/screen_context.dart';
import '../../assistant/presentation/screen_context_scope.dart';
import '../domain/assist_intent.dart';
import '../domain/sample_notifications.dart';
import 'notifications_providers.dart';

// Notifications: sample alerts built from the customer's own data. "Send notification" shows a real notification
// from this phone 5 seconds later (lock the phone or leave the app to see it arrive); tapping it, or the row itself,
// goes through the same handler as a real push. docs/CONTRACT.md section 7.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final Map<int, String> _status = {};

  Future<void> _send(SampleNotification n) async {
    final notifier = ref.read(localNotifierProvider);
    if (await notifier.ensurePermission() == NotifyPermission.refused) {
      setState(() => _status[n.id] = 'Allow notifications for this app in Settings to try this.');
      return;
    }
    try {
      await notifier.showLater(id: n.id, title: n.title, body: n.body, data: n.data, after: const Duration(seconds: 5));
      setState(() => _status[n.id] = 'Sending in 5 seconds… lock your phone or leave the app to see it arrive.');
    } catch (_) {
      setState(() => _status[n.id] = "The notification couldn't be sent on this phone.");
    }
  }

  void _open(SampleNotification n) => ref.read(intentRunnerHolderProvider).runner?.handleData(n.data);

  @override
  Widget build(BuildContext context) {
    final samples = ref.watch(sampleNotificationsProvider);
    final c = context.bank;
    return ScreenContextScope(
      screen: const ScreenContext(page: 'home', label: 'Notifications', launcher: 'Ask us anything'),
      child: Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: samples.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(sampleNotificationsProvider)),
          data: (list) => ListView(padding: const EdgeInsets.all(16), children: [
            Text(
              'Alerts about your money can open the right screen and start a chat or a call there, so our assistant '
              'already knows what it\'s about. Try them: send one to this phone, or tap one to open it now.',
              style: TextStyle(color: c.muted),
            ),
            const SizedBox(height: 16),
            for (final n in list) ...[
              _SampleTile(notification: n, status: _status[n.id], onSend: () => _send(n), onOpen: () => _open(n)),
              const SizedBox(height: 12),
            ],
            launcherClearance,
          ]),
        ),
      ),
    );
  }
}

class _SampleTile extends StatelessWidget {
  const _SampleTile({required this.notification, required this.status, required this.onSend, required this.onOpen});

  final SampleNotification notification;
  final String? status;
  final VoidCallback onSend, onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.bank;
    final call = notification.mode == 'call';
    final (icon, colour) = switch (notification.topic) {
      'unusual_payment' => (Icons.gpp_maybe_outlined, c.moneyOut),
      'low_balance' => (Icons.account_balance_wallet_outlined, c.flexible),
      'salary_in' => (Icons.payments_outlined, c.moneyIn),
      'savings_goal' => (Icons.savings_outlined, c.savings),
      _ => (Icons.north_east, c.brand2),
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(backgroundColor: colour.withValues(alpha: 0.12), child: Icon(icon, color: colour)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(notification.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(notification.body),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Chip(
                avatar: Icon(call ? Icons.call_outlined : Icons.chat_bubble_outline, size: 16),
                label: Text(call ? 'Opens a call' : 'Opens a chat'),
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: c.line),
              ),
              const Spacer(),
              FilledButton.tonalIcon(onPressed: onSend, icon: const Icon(Icons.send_to_mobile), label: const Text('Send notification')),
            ]),
            if (status != null) ...[
              const SizedBox(height: 8),
              Semantics(liveRegion: true, child: Text(status!, style: TextStyle(color: c.muted, fontSize: 13))),
            ],
          ]),
        ),
      ),
    );
  }
}
