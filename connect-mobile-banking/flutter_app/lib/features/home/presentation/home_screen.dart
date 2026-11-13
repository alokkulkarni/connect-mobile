import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../accounts/domain/accounts.dart';
import '../../accounts/presentation/account_card.dart';
import '../../assistant/domain/screen_context.dart';
import '../../assistant/presentation/screen_context_scope.dart';
import '../../transactions/domain/transactions.dart';
import '../../transactions/presentation/transactions_providers.dart';
import '../domain/home.dart';
import 'home_providers.dart';

/// The six latest current account transactions (with their IDs, so each opens its details).
final latestTransactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  ref.watch(homeSummaryProvider); // reload with Home
  final page = await ref.watch(transactionsRepositoryProvider).list(const TransactionFilter());
  return page.transactions.take(6).toList();
});

// Home: a greeting, the customer's accounts, shortcuts, and the latest payments. [pages/home.js]
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const screen = ScreenContext(page: 'home', label: 'Home', launcher: 'Ask us anything');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeSummaryProvider);
    return ScreenContextScope(
      screen: screen,
      child: Scaffold(
        body: home.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(homeSummaryProvider)),
          data: (h) => RefreshIndicator(
            onRefresh: () => ref.refresh(homeSummaryProvider.future),
            child: CustomScrollView(slivers: [
              SliverToBoxAdapter(child: _Header(home: h)),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.list(children: [
                  for (final a in h.accounts) ...[
                    AccountCard(
                      account: a,
                      onTap: () => context.go(a.kind == AccountKind.mortgage ? '/more/mortgages' : '/accounts/${a.id}'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  const _Shortcuts(),
                  const SizedBox(height: 20),
                  _Latest(fallback: h),
                  launcherClearance,
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.home});

  final HomeSummary home;

  @override
  Widget build(BuildContext context) {
    final c = context.bank;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.brand, c.brand2], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 20, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_balance, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text('Nationwide', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          const Spacer(),
          if (!home.verified)
            Tooltip(
              message: 'The assistant will check who you are first',
              child: Chip(
                label: const Text('Not signed in'),
                visualDensity: VisualDensity.compact,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                side: BorderSide.none,
              ),
            ),
        ]),
        const SizedBox(height: 20),
        Text(greeting(DateTime.now(), home.firstName),
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Balances up to ${day(home.asOf)}', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
      ]),
    );
  }
}

class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context) {
    final c = context.bank;
    final items = [
      (Icons.insights_outlined, 'Money Hub', '/money-hub/out', c.savings),
      (Icons.receipt_long_outlined, 'Transactions', '/home/transactions', c.brand2),
      (Icons.credit_card, 'Cards', '/cards', c.essential),
      (Icons.house_outlined, 'Mortgages', '/more/mortgages', c.flexible),
      (Icons.notifications_outlined, 'Alerts', '/more/notifications', c.moneyOut),
      (Icons.help_outline, 'Help', '/more/help', c.moneyIn),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.25,
      children: [
        for (final (icon, label, path, colour) in items)
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.go(path),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: colour.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(icon, color: colour),
                ),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            ),
          ),
      ],
    );
  }
}

class _Latest extends ConsumerWidget {
  const _Latest({required this.fallback});

  final HomeSummary fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestTransactionsProvider);
    return SectionCard(
      title: 'Latest payments',
      trailing: TextButton(onPressed: () => context.go('/home/transactions'), child: const Text('See all')),
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: latest.when(
        loading: () => const LoadingView(),
        // Without IDs the rows can't open their details, but still show.
        error: (_, _) => Column(children: [
          for (final m in fallback.recent)
            PaymentRow(merchantName: m.merchantName, category: m.category, date: m.date, amount: m.amount, moneyIn: m.moneyIn),
        ]),
        data: (rows) => Column(children: [
          for (final t in rows)
            PaymentRow(
              merchantName: t.merchantName,
              category: t.categoryWords,
              date: t.date,
              amount: t.amount,
              moneyIn: t.moneyIn,
              onTap: () => context.go('/home/transactions/${t.id}'),
            ),
        ]),
      ),
    );
  }
}
