import '../../../core/network/api_transport.dart';
import '../domain/accounts.dart';

// app/accounts, as JSON → the domain's accounts.
class AccountsRepositoryImpl implements AccountsRepository {
  AccountsRepositoryImpl(this._api);

  final ApiTransport _api;

  @override
  Future<AccountsView> accounts(String account) async {
    final reply = await _api.post('app/accounts', {'account': account == 'savings' ? 'savings' : 'current'});
    return AccountsView(
      asOf: reply['asOf'] as String? ?? '',
      accounts: accountsFromJson(reply['accounts']),
      selected: reply['selected'] as String? ?? 'current',
      recent: movementsFromJson(reply['recent']),
    );
  }
}

double? _num(Object? value) => value is num ? value.toDouble() : null;

List<Account> accountsFromJson(Object? json) => [
      for (final a in (json as List? ?? const []).cast<Map<String, dynamic>>())
        Account(
          id: a['id'] as String? ?? '',
          name: a['name'] as String? ?? '',
          ending: a['ending'] as String? ?? '',
          kind: switch (a['kind']) { 'savings' => AccountKind.savings, 'mortgage' => AccountKind.mortgage, _ => AccountKind.current },
          balance: _num(a['balance']),
          monthly: _num(a['monthly']),
          note: a['note'] as String?,
        ),
    ];

List<Movement> movementsFromJson(Object? json) => [
      for (final t in (json as List? ?? const []).cast<Map<String, dynamic>>())
        Movement(
          date: t['date'] as String? ?? '',
          merchant: t['merchant'] as String? ?? '',
          merchantName: t['merchantName'] as String? ?? '',
          amount: _num(t['amount']) ?? 0,
          category: t['category'] as String? ?? '',
          moneyIn: t['in'] == true,
        ),
    ];
