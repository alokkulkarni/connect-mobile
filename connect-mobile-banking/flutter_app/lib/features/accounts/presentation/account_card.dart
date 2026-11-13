import 'package:flutter/material.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/tokens.dart';
import '../domain/accounts.dart';

// An account as a card: its name and ending, then its balance (or, for a mortgage, the monthly payment).
// [home.js accountCard]
class AccountCard extends StatelessWidget {
  const AccountCard({super.key, required this.account, this.selected = false, this.onTap});

  final Account account;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.bank;
    final mortgage = account.kind == AccountKind.mortgage;
    final accent = switch (account.kind) { AccountKind.current => c.brand2, AccountKind.savings => c.savings, AccountKind.mortgage => c.flexible };
    return Semantics(
      selected: selected,
      button: onTap != null,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BankColors.radius),
          side: BorderSide(color: selected ? accent : c.line, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(border: Border(left: BorderSide(color: accent, width: 5))),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(account.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                Text('ending ${account.ending}', style: TextStyle(color: c.muted, fontSize: 13)),
              ]),
              const SizedBox(height: 12),
              Text(mortgage ? 'Monthly payment' : 'Balance', style: TextStyle(color: c.muted, fontSize: 13)),
              Text(
                gbp(mortgage ? account.monthly ?? 0 : account.balance ?? 0),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, fontFeatures: [FontFeature.tabularFigures()]),
              ),
              if (account.note != null) ...[
                const SizedBox(height: 6),
                Text(account.note!, style: TextStyle(color: c.muted, fontSize: 13)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
