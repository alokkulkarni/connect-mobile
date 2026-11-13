import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/form_opener.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../assistant/domain/screen_context.dart';
import '../../assistant/presentation/screen_context_scope.dart';
import '../domain/mortgages.dart';
import 'mortgages_providers.dart';

// Mortgages: what the application involves, the products, and a way in. The application form is the web app's own
// page in a WebView, where the mortgage assistant fills it in through Live Sync (docs/CONTRACT.md section 9). Here,
// the assistant is ARIA, told the customer is looking at mortgages (`mortgages`). [pages/mortgages.js]
class MortgagesScreen extends ConsumerWidget {
  const MortgagesScreen({super.key});

  static const screen = ScreenContext(page: 'mortgages', label: 'Mortgages', launcher: 'Help with a mortgage');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(mortgageProductsProvider);
    final c = context.bank;
    return ScreenContextScope(
      screen: screen,
      child: Scaffold(
        appBar: AppBar(title: const Text('Mortgages')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c.brand, c.brand2]),
              borderRadius: BorderRadius.circular(BankColors.radius),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.house_outlined, color: Colors.white, size: 32),
              const SizedBox(height: 8),
              const Text('Apply for a mortgage', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('Fill it in yourself, or with our assistant: it fills in the application with you as you talk. '
                  'Choosing a product is up to you.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: c.brand),
                onPressed: () => openMortgageApplication(context, ref),
                icon: const Icon(Icons.edit_document),
                label: const Text('Start your application'),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'What it involves',
            child: Column(children: [
              for (final (i, stage) in mortgageStages.values.indexed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: CircleAvatar(radius: 14, backgroundColor: c.brand2.withValues(alpha: 0.12), child: Text('${i + 1}', style: TextStyle(color: c.brand2, fontSize: 13))),
                  title: Text(stage),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Our mortgages',
            child: products.when(
              loading: () => const LoadingView(),
              error: (e, _) => const Text("Products aren't available just now."),
              data: (list) => Column(children: [
                for (final p in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Fee £${p.fee.toStringAsFixed(0)} · up to ${p.maxLtv}% of the property\'s value'),
                    trailing: Text('${p.rate.toStringAsFixed(2)}%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.brand2)),
                  ),
                const SizedBox(height: 8),
                Text('Rates are examples, not offers.', style: TextStyle(color: c.muted, fontSize: 12)),
              ]),
            ),
          ),
          launcherClearance,
        ]),
      ),
    );
  }
}
