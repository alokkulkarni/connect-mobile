import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../assistant/domain/screen_context.dart';
import '../../assistant/presentation/screen_context_scope.dart';
import '../../home/presentation/home_providers.dart';

// More: everything that isn't a tab.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeSummaryProvider).value;
    final c = context.bank;
    Widget item(IconData icon, Color colour, String title, String subtitle, String path) => Card(
          child: ListTile(
            leading: CircleAvatar(backgroundColor: colour.withValues(alpha: 0.12), child: Icon(icon, color: colour)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(path),
          ),
        );
    return ScreenContextScope(
      screen: const ScreenContext(page: 'home', label: 'More', launcher: 'Ask us anything'),
      child: Scaffold(
        appBar: AppBar(title: const Text('More')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: c.brand,
                child: Text((home?.firstName.isNotEmpty ?? false) ? home!.firstName[0] : '·', style: const TextStyle(color: Colors.white)),
              ),
              title: Text(home?.firstName ?? 'You', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(home == null ? '' : home.verified ? 'Signed in' : 'Not signed in: the assistant checks who you are first'),
            ),
          ),
          const SizedBox(height: 12),
          item(Icons.house_outlined, c.flexible, 'Mortgages', 'Products and your application', '/more/mortgages'),
          const SizedBox(height: 8),
          item(Icons.help_outline, c.moneyIn, 'Help and FAQs', 'Common questions and your disputes', '/more/help'),
          const SizedBox(height: 8),
          item(Icons.notifications_outlined, c.moneyOut, 'Notifications', 'Try alerts that open a chat or a call', '/more/notifications'),
          const SizedBox(height: 8),
          item(Icons.settings_outlined, c.brand2, 'Settings', 'This device, and about the app', '/more/settings'),
        ]),
      ),
    );
  }
}
