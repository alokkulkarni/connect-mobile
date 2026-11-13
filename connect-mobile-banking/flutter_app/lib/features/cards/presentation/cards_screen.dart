import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/money.dart';
import '../../../core/network/api_transport.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../assistant/domain/screen_context.dart';
import '../../assistant/presentation/assistant_sheet.dart';
import '../../assistant/presentation/screen_context_scope.dart';
import '../domain/cards.dart';
import 'cards_providers.dart';

// Cards: the customer's cards, their payments, and their disputes. [pages/cards.js]
//   Payments       the card dispute service's own list, so the payment chosen is the one the dispute assistant
//                  finds. "Dispute" chooses it and opens the assistant: the conversation goes to the dispute
//                  assistant through ARIA, starting from that payment (card_dispute).
//   Your disputes  every dispute and where it's up to. Refreshes while shown, to follow one being filled in.
class CardsScreen extends ConsumerWidget {
  const CardsScreen({super.key, required this.disputesTab});

  final bool disputesTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(cardsSelectionProvider).chosen;
    final screen = chosen != null && !disputesTab
        ? ScreenContext(
            page: 'card_dispute',
            paymentId: chosen.id,
            label: 'Disputing ${tidyMerchant(chosen.merchant)} ${gbp(chosen.amount)}',
            launcher: 'Help with a payment',
          )
        : const ScreenContext(page: 'cards', label: 'Cards', launcher: 'Help with a payment');
    return ScreenContextScope(
      screen: screen,
      child: DefaultTabController(
        length: 2,
        initialIndex: disputesTab ? 1 : 0,
        key: ValueKey(disputesTab),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Cards'),
            bottom: TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              onTap: (i) => context.go(i == 1 ? '/cards/disputes' : '/cards'),
              tabs: const [Tab(text: 'Payments'), Tab(text: 'Your disputes')],
            ),
          ),
          body: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            children: [const _PaymentsTab(), _DisputesTab(active: disputesTab)],
          ),
        ),
      ),
    );
  }
}

class _PaymentsTab extends ConsumerStatefulWidget {
  const _PaymentsTab();

  @override
  ConsumerState<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends ConsumerState<_PaymentsTab> {
  String _filter = 'all';
  final _pages = PageController(viewportFraction: 0.86);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(cardsViewProvider);
    final selection = ref.watch(cardsSelectionProvider);
    final c = context.bank;
    return view.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(cardsViewProvider)),
      data: (v) {
        final payments = v.payments.where((p) => _filter == 'all' || p.card == _filter).toList();
        return ListView(padding: const EdgeInsets.only(bottom: 96), children: [
          SizedBox(
            height: 224,
            child: PageView(
              controller: _pages,
              children: [for (final card in v.cards) Padding(padding: const EdgeInsets.fromLTRB(6, 16, 6, 8), child: CardFace(card: card))],
            ),
          ),
          if (selection.chosen != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Card(
                color: c.flexible.withValues(alpha: 0.12),
                child: ListTile(
                  leading: Icon(Icons.report_outlined, color: c.flexible),
                  title: Text('Disputing ${tidyMerchant(selection.chosen!.merchant)} ${gbp(selection.chosen!.amount)}'),
                  subtitle: const Text('The assistant starts from this payment.'),
                  trailing: TextButton(onPressed: () => selection.choose(null), child: const Text('Clear')),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(spacing: 8, children: [
              for (final (key, label) in [
                ('all', 'All cards'),
                for (final card in v.cards) (card.type, '${card.isDebit ? 'Debit' : 'Credit'} ••${card.ending}'),
              ])
                ChoiceChip(label: Text(label), selected: _filter == key, onSelected: (_) => setState(() => _filter = key)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Column(children: [
                for (final p in payments)
                  Container(
                    color: selection.chosen?.id == p.id ? c.flexible.withValues(alpha: 0.08) : null,
                    child: PaymentRow(
                      merchantName: tidyMerchant(p.merchant),
                      category: '${p.card == 'debit' ? 'Debit' : 'Credit'} card ••${p.ending}',
                      date: p.date,
                      amount: -p.amount,
                      moneyIn: false,
                      trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        AmountText(p.amount, moneyIn: false),
                        Semantics(
                          label: 'Dispute ${tidyMerchant(p.merchant)}, ${gbp(p.amount)} on ${day(p.date)}',
                          excludeSemantics: true,
                          child: TextButton(
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, minimumSize: const Size(48, 28)),
                            onPressed: () {
                              selection.choose(p);
                              Future<void>.delayed(const Duration(milliseconds: 250), () {
                                if (context.mounted) showAssistantSheet(context);
                              });
                            },
                            child: const Text('Dispute'),
                          ),
                        ),
                      ]),
                    ),
                  ),
              ]),
            ),
          ),
        ]);
      },
    );
  }
}

/// A bank card drawn as a card: navy for debit, a deeper shade for credit, only the last four digits.
class CardFace extends StatelessWidget {
  const CardFace({super.key, required this.card});

  final BankCard card;

  @override
  Widget build(BuildContext context) {
    final c = context.bank;
    final colours = card.isDebit ? [c.brand, c.brand2] : [const Color(0xFF3B1F5C), c.savings];
    return Semantics(
      label: '${card.name} ending ${card.ending}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colours, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Nationwide', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            const Spacer(),
            Icon(Icons.contactless_outlined, color: Colors.white.withValues(alpha: 0.85)),
          ]),
          const Spacer(),
          Container(
            width: 40,
            height: 28,
            decoration: BoxDecoration(color: const Color(0xFFE6C77A), borderRadius: BorderRadius.circular(6)),
          ),
          const SizedBox(height: 14),
          Text('•••• •••• •••• ${card.ending}',
              style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2, fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(height: 6),
          Text(card.name, style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
        ]),
      ),
    );
  }
}

class _DisputesTab extends ConsumerStatefulWidget {
  const _DisputesTab({required this.active});

  final bool active;

  @override
  ConsumerState<_DisputesTab> createState() => _DisputesTabState();
}

class _DisputesTabState extends ConsumerState<_DisputesTab> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.active) _timer = Timer.periodic(const Duration(seconds: 5), (_) => ref.invalidate(disputesProvider));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disputes = ref.watch(disputesProvider);
    return disputes.when(
      loading: () => const LoadingView(),
      error: (e, _) => const Center(child: Padding(padding: EdgeInsets.all(32), child: Text("Disputes aren't available just now."))),
      data: (list) => list.isEmpty
          ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('You have no disputes.')))
          : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
              for (final d in list) ...[DisputeTile(dispute: d), const SizedBox(height: 12)],
            ]),
    );
  }
}

/// One dispute: what, where it's up to, what's missing, and what the customer can do.   [dispute/list.js]
class DisputeTile extends ConsumerWidget {
  const DisputeTile({super.key, required this.dispute, this.actions = true});

  final Dispute dispute;
  final bool actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bank;
    final d = dispute;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(tidyMerchant(d.merchant), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
            Text(gbp(d.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          Text('${d.cardType == 'debit' ? 'Debit' : 'Credit'} card ••${d.cardLastFour} · ${day(d.transactionDate)} · ${d.disputeId}',
              style: TextStyle(color: c.muted, fontSize: 13)),
          const SizedBox(height: 10),
          Chip(
            label: Text(d.statusWords),
            visualDensity: VisualDensity.compact,
            backgroundColor: d.open ? c.flexible.withValues(alpha: 0.14) : c.moneyInSoft,
            side: BorderSide.none,
          ),
          if (d.missing.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Still needed: ${d.missing.join(', ')}', style: TextStyle(color: c.muted, fontSize: 13)),
          ],
          if (actions && d.open) ...[
            const SizedBox(height: 8),
            Row(children: [
              if (d.canSubmit)
                FilledButton(
                  onPressed: () async {
                    try {
                      await ref.read(cardsRepositoryProvider).submitDispute(d.disputeId);
                      ref.invalidate(disputesProvider);
                    } on ApiException catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                    }
                  },
                  child: const Text('Submit'),
                ),
              if (d.status == 'draft')
                TextButton(
                  // An unfinished draft: back to the dispute assistant with that payment, which carries on with it.
                  onPressed: () async {
                    final cards = await ref.read(cardsViewProvider.future);
                    final payment = cards.payment(d.transactionId);
                    if (payment == null || !context.mounted) return;
                    ref.read(cardsSelectionProvider).choose(payment);
                    context.go('/cards');
                    final navigator = Navigator.of(context, rootNavigator: true).context;
                    await Future<void>.delayed(const Duration(milliseconds: 400));
                    if (navigator.mounted) showAssistantSheet(navigator);
                  },
                  child: const Text('Finish with the assistant'),
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}
