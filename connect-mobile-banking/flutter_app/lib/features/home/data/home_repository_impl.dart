import '../../../core/network/api_transport.dart';
import '../../accounts/data/accounts_repository_impl.dart';
import '../../cards/data/cards_repository_impl.dart';
import '../domain/home.dart';

class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl(this._api);

  final ApiTransport _api;

  @override
  Future<HomeSummary> home() async {
    final reply = await _api.post('app/home');
    return HomeSummary(
      firstName: reply['firstName'] as String? ?? '',
      asOf: reply['asOf'] as String? ?? '',
      accounts: accountsFromJson(reply['accounts']),
      recent: movementsFromJson(reply['recent']),
      cards: cardsFromJson(reply['cards']),
      talk: reply['talk'] == true,
      verified: reply['verified'] == true,
      disputePagesUrl: (reply['disputePagesUrl'] as String? ?? '').replaceAll(RegExp(r'/+$'), ''),
    );
  }
}
