import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../assistant/domain/screen_context.dart';
import '../../assistant/presentation/assistant_providers.dart';
import '../../assistant/presentation/screen_context_scope.dart';

// Settings: how this phone is signed in, forgetting it, and about the app.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).session;
    final c = context.bank;
    return ScreenContextScope(
      screen: const ScreenContext(page: 'home', label: 'Settings', launcher: 'Ask us anything'),
      child: Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          SectionCard(
            title: 'This phone',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(session?.isSample ?? true ? Icons.visibility_outlined : Icons.link, color: c.brand2),
                title: Text(session?.isSample ?? true ? 'Sample data' : 'Your internet banking link'),
                subtitle: Text(session?.isSample ?? true
                    ? 'Everything works on this phone with sample data. Chat and calls need your link.'
                    : 'Kept in this phone\'s secure storage. Chat and calls are on.'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: c.moneyOut),
                icon: const Icon(Icons.logout),
                label: const Text('Forget this device'),
                onPressed: () async {
                  final sure = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: const Text('Forget this device?'),
                      content: const Text('This phone will forget your internet banking. Any chat or call ends. You\'ll need your link to open it again.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Forget')),
                      ],
                    ),
                  );
                  if (sure != true) return;
                  await ref.read(assistantControllerProvider).hangUp();
                  ref.read(screenContextsProvider).clear();
                  await ref.read(sessionControllerProvider).forget(
                      because: 'This device has forgotten your internet banking. Open it from your link to see it again.');
                },
              ),
            ]),
          ),
          const SizedBox(height: 16),
          const SectionCard(
            title: 'About',
            child: Text(
              'A demo of internet banking with an assistant that knows where you are. Sample data only (James, a fictional '
              'customer). The assistant is an AI, labelled as one; ask at any time to speak to one of our colleagues.\n\n'
              'Notifications here are simulated on this phone: no push service is set up.',
            ),
          ),
        ]),
      ),
    );
  }
}
