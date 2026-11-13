// The current account's transactions (the Money Hub's own list, with the customer's own categories), where each
// happened, and the card payment a transaction is, for "Dispute this payment". docs/CONTRACT.md section 8.

class Transaction {
  const Transaction({
    required this.id,
    required this.date,
    required this.merchant,
    required this.merchantName,
    required this.amount,
    required this.category,
    required this.categoryWords,
    required this.direction,
    required this.balanceAfter,
    required this.recategorised,
  });

  final String id; // MH-<nnn>-<yyyymmdd>-<nnnn>
  final String date;
  final String merchant;
  final String merchantName;
  final double amount; // negative = out
  final String category;
  final String categoryWords;
  final String direction; // in, out (or move, for money moved to savings)
  final double? balanceAfter;
  final bool recategorised;

  bool get moneyIn => direction == 'in';
}

class TransactionFilter {
  const TransactionFilter({this.from = '', this.to = '', this.category = '', this.direction = '', this.merchant = ''});

  final String from, to, category, direction, merchant;

  Map<String, Object> toFields() =>
      {'from': from, 'to': to, 'category': category, 'direction': direction, 'merchant': merchant};
}

class TransactionPage {
  const TransactionPage({required this.transactions, required this.page, required this.hasMore, required this.total});

  final List<Transaction> transactions;
  final int page;
  final bool hasMore;
  final int total;
}

abstract interface class TransactionsRepository {
  Future<TransactionPage> list(TransactionFilter filter, {int page = 1});

  /// Put one transaction in another category (money in only to money in, money out only to money out).
  Future<Transaction> recategorise(String transactionId, String category);
}

/// The date inside a transaction's ID (MH-001-20261015-0332 → 2026-10-15), or null if the ID isn't one.
String? dateOfTransactionId(String id) {
  final match = RegExp(r'^MH-\d{3}-(\d{4})(\d{2})(\d{2})-\d{4}$').firstMatch(id);
  return match == null ? null : '${match[1]}-${match[2]}-${match[3]}';
}

/// One transaction by its ID: list that day's transactions and match the ID (the route has no lookup by ID).
Future<Transaction?> findTransaction(TransactionsRepository repository, String id) async {
  final date = dateOfTransactionId(id);
  if (date == null) return null;
  var page = 1;
  while (true) {
    final found = await repository.list(TransactionFilter(from: date, to: date), page: page);
    final match = found.transactions.where((t) => t.id == id).firstOrNull;
    if (match != null || !found.hasMore || page >= 10) return match;
    page++;
  }
}

/// Where a payment happened: a place on the map, or online (no map). Made up for the demo.
class MerchantPlace {
  const MerchantPlace.at({required String this.name, required String this.area, required double this.lat, required double this.lng})
      : online = false;
  const MerchantPlace.online()
      : online = true,
        name = null,
        area = null,
        lat = null,
        lng = null;

  final bool online;
  final String? name, area;
  final double? lat, lng;
}

class MerchantPlaceRule {
  const MerchantPlaceRule(this.match, this.place);

  final String match; // the start of the merchant's name, upper case
  final MerchantPlace place;
}

/// The place for a merchant: the first rule whose `match` starts the merchant's name (upper case), or null when the
/// table doesn't know it (a direct debit, a transfer).
MerchantPlace? placeFor(String merchant, List<MerchantPlaceRule> rules) {
  final name = merchant.trim().toUpperCase();
  for (final rule in rules) {
    if (name.startsWith(rule.match.toUpperCase())) return rule.place;
  }
  return null;
}

abstract interface class MerchantPlacesRepository {
  Future<List<MerchantPlaceRule>> rules();
}

/// The card payment ID a current account transaction would have, if it was paid with the debit card:
/// `TXN-<debit card ending>-<date without dashes>-<amount in pence>` (connect-money-hub/moneyhub/data.py card_payments).
/// Only money going out can be a card payment.
String? cardPaymentIdFor(Transaction t, String debitCardEnding) {
  if (t.amount >= 0 || debitCardEnding.isEmpty) return null;
  final pence = (t.amount.abs() * 100).round();
  return 'TXN-$debitCardEnding-${t.date.replaceAll('-', '')}-$pence';
}

/// The card payment to dispute for this transaction: only when its ID is in the Cards list (the latest 25).
String? disputablePaymentId(Transaction t, String debitCardEnding, Iterable<String> listedPaymentIds) {
  final id = cardPaymentIdFor(t, debitCardEnding);
  return id != null && listedPaymentIds.contains(id) ? id : null;
}
