import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../assistant/domain/screen_context.dart';
import '../../assistant/presentation/assistant_sheet.dart';
import '../../assistant/presentation/screen_context_scope.dart';
import '../../cards/presentation/cards_providers.dart';
import '../../cards/presentation/cards_screen.dart';
import '../domain/faqs.dart';

// Help: how to reach us, the customer's disputes at a glance, and common questions. [pages/help.js]
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputes = ref.watch(disputesProvider).value ?? const [];
    final c = context.bank;
    return ScreenContextScope(
      screen: const ScreenContext(page: 'help', label: 'Help', launcher: 'Ask us anything'),
      child: Scaffold(
        appBar: AppBar(title: const Text('Help and FAQs')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          SectionCard(
            title: 'Ask us anything',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Chat or call with our assistant from the button at the bottom of any screen. It knows which '
                  'screen you\'re on, so it can help with that straight away: your Money Hub, a mortgage or a card payment.'),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: () => showAssistantSheet(context), icon: const Icon(Icons.support_agent), label: const Text('Ask the assistant')),
            ]),
          ),
          if (disputes.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: 'Your disputes',
              trailing: TextButton(onPressed: () => context.go('/cards/disputes'), child: const Text('See them in Cards')),
              child: Column(children: [
                for (final d in disputes.take(4)) Padding(padding: const EdgeInsets.only(bottom: 8), child: DisputeTile(dispute: d, actions: false)),
              ]),
            ),
          ],
          const SizedBox(height: 16),
          Text('Common questions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (final faq in faqs)
                ExpansionTile(
                  title: Text(faq.question, style: const TextStyle(fontWeight: FontWeight.w600)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  shape: const Border(),
                  children: [
                    Text(faq.answer, style: TextStyle(color: c.ink)),
                    if (faq.screen != null) TextButton(onPressed: () => context.go(faq.screen!), child: Text(faq.screenLabel ?? 'Go there')),
                  ],
                ),
            ]),
          ),
          launcherClearance,
        ]),
      ),
    );
  }
}
