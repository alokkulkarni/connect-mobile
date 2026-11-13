import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/format/money.dart';
import '../../../core/network/api_transport.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../assistant/domain/screen_context.dart';
import '../../assistant/presentation/screen_context_scope.dart';
import '../../transactions/presentation/transactions_list.dart';
import '../domain/money_hub.dart';
import 'charts.dart';
import 'money_hub_providers.dart';

// The Money Hub, one tab per view the assistant is told (out, in, expected, transactions, goals): the tab the
// customer is on goes with a chat or call, and a tab they stay on is told to the assistant. [pages/money-hub.js]
class MoneyHubScreen extends ConsumerWidget {
  const MoneyHubScreen({super.key, required this.view});

  final MoneyHubView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(moneyHubProvider);
    return ScreenContextScope(
      screen: ScreenContext(page: 'money_hub', view: view.key, label: 'Money Hub · ${view.label}', launcher: 'Ask about your money'),
      child: DefaultTabController(
        key: ValueKey(view),
        length: MoneyHubView.values.length,
        initialIndex: view.index,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Money Hub'),
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              onTap: (i) => context.go('/money-hub/${MoneyHubView.values[i].key}'),
              tabs: [for (final v in MoneyHubView.values) Tab(text: v.label)],
            ),
          ),
          body: view == MoneyHubView.transactions
              ? TransactionsList(detailPath: (id) => '/money-hub/transactions/$id')
              : hub.when(
                  loading: () => const LoadingView(),
                  error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(moneyHubProvider)),
                  data: (h) => RefreshIndicator(
                    onRefresh: () => ref.refresh(moneyHubProvider.future),
                    child: ListView(padding: const EdgeInsets.all(16), children: [
                      _Balance(hub: h),
                      const SizedBox(height: 16),
                      ...switch (view) {
                        MoneyHubView.out => _moneyOut(context, h),
                        MoneyHubView.moneyIn => _moneyIn(context, h),
                        MoneyHubView.expected => _expected(context, h),
                        MoneyHubView.goals => [_Goals(goals: h.goals)],
                        MoneyHubView.transactions => const <Widget>[],
                      },
                      launcherClearance,
                    ]),
                  ),
                ),
        ),
      ),
    );
  }

  List<Widget> _moneyOut(BuildContext context, MoneyHub h) {
    final c = context.bank;
    final palette = [c.essential, c.flexible, c.savings, c.moneyIn, c.brand2, c.moneyOut];
    return [
      SectionCard(
        title: 'Money out each month',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          StackedBarChart(
            semanticLabel: [for (final m in h.monthlySpending) '${monthName(m.month)}: ${gbp(m.total)}'].join('. '),
            bars: [
              for (final m in h.monthlySpending)
                StackedBar(label: shortMonth(m.month), segments: [BarSegment(m.essential, c.essential), BarSegment(m.discretionary, c.flexible)]),
            ],
          ),
          const SizedBox(height: 8),
          Legend(items: [('Essentials', c.essential), ('Spending you choose', c.flexible)]),
        ]),
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Where your money goes',
        child: Column(children: [
          for (var i = 0; i < h.overview.topSpending.length; i++)
            ShareBar(
              label: h.overview.topSpending[i].words,
              amount: h.overview.topSpending[i].total,
              share: h.overview.topSpending[i].share,
              color: palette[i % palette.length],
            ),
        ]),
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Spending you choose',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${h.discretionary.share}% of your spending is on things you choose: about ${gbp(h.discretionary.discretionaryPerMonth)} a month, '
              'next to ${gbp(h.discretionary.essentialPerMonth)} on essentials.'),
          const SizedBox(height: 12),
          for (final habit in h.discretionary.habits.where((x) => x.discretionary).take(4))
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(Icons.local_cafe_outlined, color: c.flexible),
              title: Text(habit.words),
              subtitle: Text('About ${habit.timesPerMonth.round()} times a month'),
              trailing: Text('${gbp(habit.perMonth)}/mo', style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
        ]),
      ),
    ];
  }

  List<Widget> _moneyIn(BuildContext context, MoneyHub h) {
    final c = context.bank;
    return [
      SectionCard(
        title: 'Money in each month',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          StackedBarChart(
            semanticLabel: [for (final m in h.monthlyIncome) '${monthName(m.month)}: ${gbp(m.total)}'].join('. '),
            bars: [
              for (final m in h.monthlyIncome)
                StackedBar(label: shortMonth(m.month), segments: [BarSegment(m.salary, c.moneyIn), BarSegment(m.other, c.savings)]),
            ],
          ),
          const SizedBox(height: 8),
          Legend(items: [('Salary', c.moneyIn), ('Everything else', c.savings)]),
        ]),
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Where it comes from',
        child: Column(children: [
          for (final s in h.overview.moneyInSources) ShareBar(label: s.words, amount: s.total, share: s.share, color: c.moneyIn),
        ]),
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Coming in regularly',
        child: Column(children: [
          for (final r in h.recurring.where((r) => r.direction == 'in'))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(r.merchantName),
              subtitle: Text('${r.words} · next ${day(r.nextExpected)}'),
              trailing: AmountText(r.amount, moneyIn: true),
            ),
        ]),
      ),
    ];
  }

  List<Widget> _expected(BuildContext context, MoneyHub h) {
    final c = context.bank;
    return [
      for (final m in h.forecast.months) ...[
        SectionCard(
          title: monthName(m.month),
          trailing: Text('Ends at ${gbp(m.endBalance)}', style: TextStyle(color: m.endBalance < 0 ? c.moneyOut : c.muted, fontWeight: FontWeight.w600)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: _Figure(label: 'Expected in', value: signed(m.expectedIn, moneyIn: true), color: c.moneyIn)),
              Expanded(child: _Figure(label: 'Expected out', value: signed(m.expectedOut, moneyIn: false), color: c.ink)),
            ]),
            const SizedBox(height: 12),
            for (final item in [...m.regularIn, ...m.regularOut]..sort((a, b) => a.date.compareTo(b.date)))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  SizedBox(width: 56, child: Text(day(item.date), style: TextStyle(color: c.muted, fontSize: 13))),
                  Expanded(child: Text(item.merchantName, overflow: TextOverflow.ellipsis)),
                  AmountText(item.amount, moneyIn: m.regularIn.contains(item), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                const SizedBox(width: 56),
                Expanded(child: Text('Everyday spending', style: TextStyle(color: c.muted))),
                Text(signed(m.everydaySpending, moneyIn: false), style: TextStyle(color: c.muted)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
      ],
      if (h.forecast.basis.isNotEmpty) Text(h.forecast.basis, style: TextStyle(color: c.muted, fontSize: 12)),
    ];
  }
}

class _Balance extends StatelessWidget {
  const _Balance({required this.hub});

  final MoneyHub hub;

  @override
  Widget build(BuildContext context) {
    final c = context.bank;
    final month = hub.overview.thisMonth;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.brand, c.brand2]),
        borderRadius: BorderRadius.circular(BankColors.radius),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Current account balance', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
        Text(gbp(hub.overview.balance), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _Figure(label: '${month.month.isEmpty ? 'This month' : monthName(month.month)} in', value: signed(month.moneyIn, moneyIn: true), color: Colors.white, light: true)),
          Expanded(child: _Figure(label: 'Out so far', value: signed(month.moneyOut, moneyIn: false), color: Colors.white, light: true)),
        ]),
      ]),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, required this.color, this.light = false});

  final String label, value;
  final Color color;
  final bool light;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, color: light ? Colors.white70 : context.bank.muted)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: color)),
      ]);
}

class _Goals extends ConsumerWidget {
  const _Goals({required this.goals});

  final List<Goal> goals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bank;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (goals.isEmpty)
        const SectionCard(child: Text('No goals yet. Add one and we\'ll show what to put aside each month.')),
      for (final g in goals) ...[
        SectionCard(
          title: g.name,
          trailing: IconButton(
            tooltip: 'Delete ${g.name}',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final sure = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  title: Text('Delete ${g.name}?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Keep it')),
                    FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (sure == true) {
                await ref.read(moneyHubRepositoryProvider).deleteGoal(g.name);
                ref.read(dataVersionProvider.notifier).bump();
              }
            },
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${gbp(g.saved)} of ${gbp(g.target)}${g.targetDateWords != null ? ' by ${g.targetDateWords}' : ''}'),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: g.progress, minHeight: 12, color: c.savings, backgroundColor: c.line),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Icon(g.onTrack ? Icons.check_circle : Icons.info_outline, size: 18, color: g.onTrack ? c.moneyIn : c.flexible),
              const SizedBox(width: 6),
              Expanded(
                child: Text(g.onTrack
                    ? 'On track: ${gbp(g.neededPerMonth)} a month gets you there.'
                    : 'Put aside ${gbp(g.neededPerMonth)} a month to get there${g.reachedAtCurrentRate != null ? '. At today\'s rate: ${g.reachedAtCurrentRate}' : ''}.'),
              ),
            ]),
            if (g.changes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Ideas that would help', style: TextStyle(color: c.muted, fontSize: 13, fontWeight: FontWeight.w600)),
              for (final change in g.changes)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• ${change.change}: saves ${gbp(change.savesPerMonth)} a month'),
                ),
            ],
          ]),
        ),
        const SizedBox(height: 12),
      ],
      OutlinedButton.icon(onPressed: () => _addGoal(context, ref), icon: const Icon(Icons.add), label: const Text('Add a goal')),
    ]);
  }

  Future<void> _addGoal(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final target = TextEditingController();
    final saved = TextEditingController();
    var byDate = DateTime.now().add(const Duration(days: 365));
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(sheet).bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('A new goal', style: Theme.of(sheet).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'What for')),
            const SizedBox(height: 12),
            TextField(controller: target, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (£)')),
            const SizedBox(height: 12),
            TextField(controller: saved, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Saved so far (£)')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text('By ${longDay(byDate.toIso8601String().substring(0, 10))}'),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: sheet,
                  initialDate: byDate,
                  firstDate: DateTime.now().add(const Duration(days: 31)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                );
                if (picked != null) setSheet(() => byDate = picked);
              },
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(sheet, true), child: const Text('Save goal')),
          ]),
        ),
      ),
    );
    if (added != true) return;
    try {
      await ref.read(moneyHubRepositoryProvider).saveGoal(
            name: name.text.trim(),
            target: double.tryParse(target.text.replaceAll(',', '')) ?? 0,
            saved: double.tryParse(saved.text.replaceAll(',', '')) ?? 0,
            byDate: byDate.toIso8601String().substring(0, 10),
          );
      ref.read(dataVersionProvider.notifier).bump();
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
