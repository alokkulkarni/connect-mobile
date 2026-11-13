import '../../../core/network/api_transport.dart';
import '../domain/cards.dart';

class CardsRepositoryImpl implements CardsRepository {
  CardsRepositoryImpl(this._api);

  final ApiTransport _api;

  @override
  Future<CardsView> cards() async {
    final reply = await _api.post('app/cards');
    return CardsView(cards: cardsFromJson(reply['cards']), payments: paymentsFromJson(reply['payments']));
  }

  @override
  Future<List<Dispute>> disputes() async {
    final reply = await _api.post('disputes');
    return [
      for (final d in (reply['disputes'] as List? ?? const []).cast<Map<String, dynamic>>())
        Dispute(
          disputeId: d['disputeId'] as String? ?? '',
          status: d['status'] as String? ?? '',
          statusWords: d['statusWords'] as String? ?? '',
          merchant: d['merchant'] as String? ?? '',
          amount: double.tryParse('${d['amount']}') ?? 0,
          transactionDate: d['transactionDate'] as String? ?? '',
          cardType: d['cardType'] as String? ?? '',
          cardLastFour: d['cardLastFour'] as String? ?? '',
          missing: (d['missing'] as List? ?? const []).cast<String>(),
          open: d['open'] == true,
          canSubmit: d['canSubmit'] == true,
          transactionId: d['transactionId'] as String? ?? '',
        ),
    ];
  }

  @override
  Future<void> submitDispute(String disputeId) => _api.post('disputes/submit', {'disputeId': disputeId});
}

List<BankCard> cardsFromJson(Object? json) => [
      for (final c in (json as List? ?? const []).cast<Map<String, dynamic>>())
        BankCard(type: c['type'] as String? ?? '', ending: c['ending'] as String? ?? '', name: c['name'] as String? ?? ''),
    ];

List<CardPayment> paymentsFromJson(Object? json) => [
      for (final p in (json as List? ?? const []).cast<Map<String, dynamic>>())
        CardPayment(
          id: p['id'] as String? ?? '',
          date: p['date'] as String? ?? '',
          merchant: p['merchant'] as String? ?? '',
          amount: (p['amount'] as num?)?.toDouble() ?? 0,
          card: p['card'] as String? ?? '',
          ending: p['ending'] as String? ?? '',
        ),
    ];
