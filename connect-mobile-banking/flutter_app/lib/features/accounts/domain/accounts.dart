// The customer's accounts and their latest movements, as the Home and Accounts pages show them
// (connect-banking-app/bankapp/home.py).

enum AccountKind { current, savings, mortgage }

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.ending,
    required this.kind,
    this.balance,
    this.monthly,
    this.note,
  });

  final String id;
  final String name;
  final String ending;
  final AccountKind kind;
  final double? balance; // current and savings
  final double? monthly; // the mortgage's monthly payment
  final String? note;
}

/// One movement in or out, newest first.
class Movement {
  const Movement({
    required this.date,
    required this.merchant,
    required this.merchantName,
    required this.amount,
    required this.category,
    required this.moneyIn,
  });

  final String date;
  final String merchant;
  final String merchantName;
  final double amount; // negative = out
  final String category; // words, for example "Shopping"
  final bool moneyIn;
}

class AccountsView {
  const AccountsView({required this.asOf, required this.accounts, required this.selected, required this.recent});

  final String asOf;
  final List<Account> accounts;
  final String selected; // current or savings
  final List<Movement> recent;
}

abstract interface class AccountsRepository {
  /// Every account, and one account's latest movements (`current` or `savings`).
  Future<AccountsView> accounts(String account);
}
