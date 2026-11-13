import 'dart:io';

import 'package:connect_banking/features/transactions/data/transactions_repository_impl.dart';
import 'package:connect_banking/features/transactions/domain/transactions.dart';
import 'package:flutter_test/flutter_test.dart';

// Where a payment happened, and which card payment a transaction is (docs/CONTRACT.md section 8).
void main() {
  Transaction tx({double amount = -32.45, String date = '2026-10-15', String merchant = 'AMAZON.CO.UK'}) => Transaction(
        id: 'MH-001-20261015-0332',
        date: date,
        merchant: merchant,
        merchantName: 'Amazon',
        amount: amount,
        category: 'shopping',
        categoryWords: 'Shopping',
        direction: amount < 0 ? 'out' : 'in',
        balanceAfter: 2828.8,
        recategorised: false,
      );

  group('card payment', () {
    test('the ID a debit card payment would have', () {
      expect(cardPaymentIdFor(tx(), '4821'), 'TXN-4821-20261015-3245');
      expect(cardPaymentIdFor(tx(amount: -1050), '4821'), 'TXN-4821-20261015-105000');
      expect(cardPaymentIdFor(tx(amount: 3150), '4821'), isNull); // money in is never a card payment
    });

    test('disputable only when the Cards list holds it', () {
      expect(disputablePaymentId(tx(), '4821', ['TXN-4821-20261015-3245']), 'TXN-4821-20261015-3245');
      expect(disputablePaymentId(tx(), '4821', ['TXN-4821-20261014-3245']), isNull);
      expect(disputablePaymentId(tx(), '', ['TXN--20261015-3245']), isNull);
    });

    test('the fixtures agree: the newest Amazon payment is in the Cards list', () {
      final cards = File('assets/fixtures/app_cards.json').readAsStringSync();
      expect(cards, contains(cardPaymentIdFor(tx(), '4821')));
    });
  });

  group('places', () {
    final rules = merchantPlacesFromJson(File('assets/fixtures/merchant_places.json').readAsStringSync());

    test('a shop has a place; online merchants have none; unknown ones are null', () {
      final tesco = placeFor('TESCO STORES 2041', rules)!;
      expect((tesco.online, tesco.area), (false, 'Altrincham'));
      expect(placeFor('tesco stores', rules)?.name, 'Tesco Extra');
      expect(placeFor('AMAZON.CO.UK', rules)?.online, isTrue);
      expect(placeFor('UBER EATS', rules)?.online, isTrue);
      expect(placeFor('NATIONWIDE MORTGAGE', rules), isNull);
    });
  });

  test('the date inside a transaction ID', () {
    expect(dateOfTransactionId('MH-001-20261015-0332'), '2026-10-15');
    expect(dateOfTransactionId('TXN-4821-20261015-3245'), isNull);
  });

  test('finding a transaction by its ID lists that day only', () async {
    final repository = _OneDay([tx()]);
    expect((await findTransaction(repository, 'MH-001-20261015-0332'))?.merchantName, 'Amazon');
    expect(repository.filters.single.from, '2026-10-15');
    expect(await findTransaction(repository, 'MH-001-20261015-9999'), isNull);
    expect(await findTransaction(repository, 'nonsense'), isNull);
  });
}

class _OneDay implements TransactionsRepository {
  _OneDay(this.rows);

  final List<Transaction> rows;
  final List<TransactionFilter> filters = [];

  @override
  Future<TransactionPage> list(TransactionFilter filter, {int page = 1}) async {
    filters.add(filter);
    return TransactionPage(transactions: rows, page: 1, hasMore: false, total: rows.length);
  }

  @override
  Future<Transaction> recategorise(String transactionId, String category) => throw UnimplementedError();
}
