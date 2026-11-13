import '../../../core/network/api_transport.dart';
import '../domain/mortgages.dart';

class MortgagesRepositoryImpl implements MortgagesRepository {
  MortgagesRepositoryImpl(this._api);

  final ApiTransport _api;

  @override
  Future<List<MortgageProduct>> products() async {
    final reply = await _api.post('mortgage/config');
    return [
      for (final p in (reply['products'] as List? ?? const []).cast<Map<String, dynamic>>())
        MortgageProduct(
          id: p['id'] as String? ?? '',
          name: p['name'] as String? ?? '',
          rate: (p['rate'] as num?)?.toDouble() ?? 0,
          fee: (p['fee'] as num?)?.toDouble() ?? 0,
          maxLtv: (p['maxLtv'] as num?)?.toInt() ?? 0,
          fixedTermYears: (p['fixedTermYears'] as num?)?.toInt() ?? 0,
        ),
    ];
  }
}
