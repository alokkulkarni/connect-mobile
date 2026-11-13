import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../assistant/domain/screen_context.dart';
import '../../assistant/presentation/screen_context_scope.dart';
import '../domain/accounts.dart';
import 'account_card.dart';
import 'accounts_providers.dart';

// Accounts: every account, and the chosen account's latest movements (/accounts/current, /accounts/savings). The
// saver shows only money moved to and from the current account. [pages/accounts.js]
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key, required this.account});

  final String account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(accountsViewProvider(account));
    final c = context.bank;
    final chosen = view.value?.accounts.where((a) => a.id == view.value?.selected).firstOrNull;
    return ScreenContextScope(
      screen: ScreenContext(page: 'accounts', label: chosen?.name ?? 'Accounts', launcher: 'Ask us anything'),
      child: Scaffold(
        appBar: AppBar(title: const Text('Accounts')),
        body: view.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(accountsViewProvider(account))),
          data: (v) => RefreshIndicator(
            onRefresh: () => ref.refresh(accountsViewProvider(account).future),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'current', label: Text('Current'), icon: Icon(Icons.account_balance_wallet_outlined)),
                  ButtonSegment(value: 'savings', label: Text('Savings'), icon: Icon(Icons.savings_outlined)),
                ],
                selected: {v.selected},
                onSelectionChanged: (s) => context.go('/accounts/${s.first}'),
              ),
              const SizedBox(height: 16),
              for (final a in v.accounts) ...[
                AccountCard(
                  account: a,
                  selected: a.id == v.selected,
                  onTap: () => context.go(a.kind == AccountKind.mortgage ? '/more/mortgages' : '/accounts/${a.id}'),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              SectionCard(
                title: chosen == null ? 'Latest movements' : '${chosen.name}, ending ${chosen.ending}',
                trailing: Text('up to ${day(v.asOf)}', style: TextStyle(color: c.muted, fontSize: 13)),
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (v.selected == 'savings')
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text('Money only moves between your savings and your current account.', style: TextStyle(color: c.muted)),
                    ),
                  if (v.recent.isEmpty)
                    const Padding(padding: EdgeInsets.all(16), child: Text('Nothing has moved in or out yet.')),
                  for (final m in v.recent)
                    PaymentRow(merchantName: m.merchantName, category: m.category, date: m.date, amount: m.amount, moneyIn: m.moneyIn),
                  if (v.selected == 'current')
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: TextButton.icon(
                        onPressed: () => context.go('/home/transactions'),
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('See all transactions'),
                      ),
                    ),
                ]),
              ),
              launcherClearance,
            ]),
          ),
        ),
      ),
    );
  }
}
