import 'dart:convert';

import '../../../core/network/api_transport.dart';
import '../../../core/network/sample_transport.dart';
import '../domain/transactions.dart';

class TransactionsRepositoryImpl implements TransactionsRepository {
  TransactionsRepositoryImpl(this._api);

  final ApiTransport _api;

  @override
  Future<TransactionPage> list(TransactionFilter filter, {int page = 1}) async {
    final reply = await _api.post('transactions', {...filter.toFields(), 'page': page});
    return TransactionPage(
      transactions: [for (final t in (reply['transactions'] as List? ?? const [])) transactionFromJson(t as Map<String, dynamic>)],
      page: (reply['page'] as num?)?.toInt() ?? page,
      hasMore: reply['hasMore'] == true,
      total: (reply['total'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<Transaction> recategorise(String transactionId, String category) async {
    final reply = await _api.post('recategorise', {'transactionId': transactionId, 'category': category});
    return transactionFromJson(reply['transaction'] as Map<String, dynamic>);
  }
}

Transaction transactionFromJson(Map<String, dynamic> t) => Transaction(
      id: t['transactionId'] as String? ?? '',
      date: t['date'] as String? ?? '',
      merchant: t['merchant'] as String? ?? '',
      merchantName: t['merchantName'] as String? ?? '',
      amount: (t['amount'] as num?)?.toDouble() ?? 0,
      category: t['category'] as String? ?? '',
      categoryWords: t['categoryWords'] as String? ?? '',
      direction: t['direction'] as String? ?? 'out',
      balanceAfter: (t['balanceAfter'] as num?)?.toDouble(),
      recategorised: t['recategorised'] == true,
    );

// The merchant places table, bundled with the app (fixtures/merchant_places.json). Illustrative only.
class BundledMerchantPlaces implements MerchantPlacesRepository {
  BundledMerchantPlaces(this._load);

  final FixtureLoader _load;
  List<MerchantPlaceRule>? _rules;

  @override
  Future<List<MerchantPlaceRule>> rules() async => _rules ??= merchantPlacesFromJson(await _load('merchant_places'));
}

List<MerchantPlaceRule> merchantPlacesFromJson(String json) {
  final places = ((jsonDecode(json) as Map<String, dynamic>)['places'] as List).cast<Map<String, dynamic>>();
  return [
    for (final p in places)
      MerchantPlaceRule(
        p['match'] as String,
        p['online'] == true
            ? const MerchantPlace.online()
            : MerchantPlace.at(
                name: p['name'] as String,
                area: p['area'] as String,
                lat: (p['lat'] as num).toDouble(),
                lng: (p['lng'] as num).toDouble(),
              ),
      ),
  ];
}
