import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/format/money.dart';
import '../../../core/network/api_transport.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../assistant/domain/screen_context.dart';
import '../../assistant/presentation/assistant_sheet.dart';
import '../../assistant/presentation/screen_context_scope.dart';
import '../../cards/presentation/cards_providers.dart';
import '../../money_hub/domain/money_hub.dart';
import '../../money_hub/presentation/money_hub_providers.dart';
import '../domain/transactions.dart';
import 'transactions_providers.dart';

// One transaction: who, how much, when, its category (which the customer can change), and where it happened, on a
// map. "Dispute this payment" when it's a debit card payment the Cards list holds. docs/CONTRACT.md section 8.
class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.id, this.initial});

  final String id;
  final Transaction? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loaded = ref.watch(transactionByIdProvider(id));
    // The list's copy shows at once; the loaded one follows (with any change of category).
    final t = loaded.value ?? (loaded.isLoading ? initial : null);
    if (t == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment')),
        body: loaded.isLoading
            ? const LoadingView()
            : loaded.hasError
                ? ErrorView(loaded.error!, onRetry: () => ref.invalidate(transactionByIdProvider(id)))
                : const Center(child: Text("We couldn't find that payment.")),
      );
    }
    final what = t.moneyIn ? 'from' : 'to';
    final screen = ScreenContext(
      page: 'money_hub',
      view: 'transactions',
      label: 'Payment $what ${t.merchantName}',
      launcher: 'Ask about this payment',
      draft: 'About my ${gbp(t.amount.abs())} payment $what ${t.merchantName} on ${dayMonth(t.date)}: ',
    );
    return ScreenContextScope(
      screen: screen,
      child: Scaffold(
        appBar: AppBar(title: const Text('Payment')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          _Summary(t: t),
          const SizedBox(height: 16),
          _Facts(t: t),
          const SizedBox(height: 16),
          _Where(merchant: t.merchant, direction: t.direction),
          const SizedBox(height: 16),
          _Actions(t: t),
          launcherClearance,
        ]),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.t});

  final Transaction t;

  @override
  Widget build(BuildContext context) {
    final c = context.bank;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          MerchantTile(t.merchantName, moneyIn: t.moneyIn, size: 64),
          const SizedBox(height: 12),
          Text(t.merchantName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          AmountText(t.amount.abs(), moneyIn: t.moneyIn, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(longDay(t.date), style: TextStyle(color: c.muted)),
        ]),
      ),
    );
  }
}

class _Facts extends ConsumerWidget {
  const _Facts({required this.t});

  final Transaction t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bank;
    Widget row(String label, Widget value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 120, child: Text(label, style: TextStyle(color: c.muted))),
            Expanded(child: value),
          ]),
        );
    return SectionCard(
      title: 'Details',
      child: Column(children: [
        row(
          'Category',
          Row(children: [
            Expanded(child: Text(t.categoryWords + (t.recategorised ? ' (changed by you)' : ''), style: const TextStyle(fontWeight: FontWeight.w600))),
            TextButton(onPressed: () => _changeCategory(context, ref, t), child: const Text('Change')),
          ]),
        ),
        row('Paid on', Text(longDay(t.date))),
        if (t.balanceAfter != null) row('Balance after', Text(gbp(t.balanceAfter!))),
        row('Description', Text(t.merchant)),
        row('Reference', SelectableText(t.id, style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]))),
      ]),
    );
  }
}

Future<void> _changeCategory(BuildContext context, WidgetRef ref, Transaction t) async {
  MoneyHub hub;
  try {
    hub = await ref.read(moneyHubProvider.future);
  } catch (_) {
    return;
  }
  if (!context.mounted) return;
  final choices = hub.choicesFor(moneyIn: t.moneyIn);
  final chosen = await showModalBottomSheet<CategoryChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.7),
        child: ListView(shrinkWrap: true, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(t.moneyIn ? 'Money in can only go in a money-in category.' : 'Money out can only go in a money-out category.'),
          ),
          for (final choice in choices)
            ListTile(
              title: Text(choice.words),
              trailing: choice.category == t.category ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(sheet).pop(choice),
            ),
        ]),
      ),
    ),
  );
  if (chosen == null || chosen.category == t.category) return;
  try {
    await ref.read(transactionsRepositoryProvider).recategorise(t.id, chosen.category);
    ref.read(dataVersionProvider.notifier).bump();
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Moved to ${chosen.words}.')));
  } on ApiException catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
  }
}

class _Where extends ConsumerWidget {
  const _Where({required this.merchant, required this.direction});

  final String merchant, direction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bank;
    final rules = ref.watch(merchantPlacesProvider).value ?? const [];
    final place = placeFor(merchant, rules);
    if (place == null || place.online) {
      final words = place == null
          ? (direction == 'in' ? 'Money paid in to your account.' : 'A direct debit or transfer: no shop involved.')
          : 'An online payment: there\'s no shop to show on a map.';
      return SectionCard(
        title: 'Where',
        child: Row(children: [
          Icon(place == null ? Icons.sync_alt : Icons.language, color: c.brand2),
          const SizedBox(width: 12),
          Expanded(child: Text(words)),
        ]),
      );
    }
    final point = LatLng(place.lat!, place.lng!);
    return SectionCard(
      title: 'Where',
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${place.name}, ${place.area}', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 200,
            child: Semantics(
              label: 'Map showing ${place.name}, ${place.area}',
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
                ),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: mapUserAgentPackage),
                  MarkerLayer(markers: [
                    Marker(point: point, width: 44, height: 44, alignment: Alignment.topCenter, child: Icon(Icons.location_on, size: 44, color: c.moneyOut)),
                  ]),
                  const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Places are made up for this demo: the sample data has no locations.', style: TextStyle(color: c.muted, fontSize: 12)),
      ]),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.t});

  final Transaction t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(cardsViewProvider).value;
    final debit = cards?.cards.where((c) => c.isDebit).firstOrNull;
    final paymentId = cards == null || debit == null ? null : disputablePaymentId(t, debit.ending, cards.payments.map((p) => p.id));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FilledButton.icon(
        onPressed: () => showAssistantSheet(context),
        icon: const Icon(Icons.support_agent),
        label: const Text('Ask about this payment'),
      ),
      if (paymentId != null) ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            ref.read(cardsSelectionProvider).choose(cards!.payment(paymentId));
            context.go('/cards');
            final navigatorContext = Navigator.of(context, rootNavigator: true).context;
            await Future<void>.delayed(const Duration(milliseconds: 400)); // let Cards say what's chosen
            if (navigatorContext.mounted) showAssistantSheet(navigatorContext);
          },
          icon: const Icon(Icons.report_outlined),
          label: const Text('Dispute this payment'),
        ),
      ],
    ]);
  }
}
