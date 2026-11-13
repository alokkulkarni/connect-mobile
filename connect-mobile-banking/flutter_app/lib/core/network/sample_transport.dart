import 'dart:convert';

import 'api_transport.dart';

/// Reads one bundled fixture by name (for example `app_home`).
typedef FixtureLoader = Future<String> Function(String name);

// Sample mode: the banking app's own replies for the sample customer (fixtures/, made by
// scripts/make_fixtures.py from the backend's own code), so every screen works with no backend. The write routes
// change an in-memory copy for this session only. Chat and calls are off (`talk` is false), as on a web page with
// no assistant set up.
class SampleTransport implements ApiTransport {
  SampleTransport(this._load);

  final FixtureLoader _load;
  final Map<String, Map<String, dynamic>> _cache = {};
  List<Map<String, dynamic>>? _transactions;

  Future<Map<String, dynamic>> _fixture(String name) async {
    final cached = _cache[name];
    if (cached != null) return cached;
    final parsed = jsonDecode(await _load(name)) as Map<String, dynamic>;
    return _cache[name] = parsed;
  }

  Future<List<Map<String, dynamic>>> _allTransactions() async {
    if (_transactions != null) return _transactions!;
    final rows = <Map<String, dynamic>>[];
    for (final page in ['transactions_p1', 'transactions_p2', 'transactions_p3']) {
      rows.addAll(((await _fixture(page))['transactions'] as List).cast<Map<String, dynamic>>());
    }
    return _transactions = rows;
  }

  @override
  Future<Map<String, dynamic>> post(String route, [Map<String, dynamic> body = const {}]) async {
    switch (route) {
      case 'app/home':
        return {...await _fixture('app_home'), 'talk': false};
      case 'app/accounts':
        return _fixture(body['account'] == 'savings' ? 'app_accounts_savings' : 'app_accounts_current');
      case 'app/cards':
        return _fixture('app_cards');
      case 'hub':
        return {...await _fixture('hub'), 'talk': false};
      case 'transactions':
        return _listTransactions(body);
      case 'recategorise':
        return _recategorise(body);
      case 'goal':
        return _saveGoal(body);
      case 'goal/delete':
        final hub = await _fixture('hub');
        final goals = (hub['goals'] as List).cast<Map<String, dynamic>>()..removeWhere((g) => g['name'] == body['name']);
        return {'goals': goals};
      case 'disputes':
        return _fixture('disputes');
      case 'disputes/submit':
        throw const ApiException('Submitting a dispute needs your internet banking link.', code: 'not_verified', status: 403);
      case 'mortgage/config':
        return _fixture('mortgage_config');
      default:
        if (route.startsWith('contact/') || route.startsWith('disputes/')) {
          throw const ApiException('Chat and calls need your internet banking link.', code: 'talk_unavailable', status: 503);
        }
        throw const ApiException('Not found', code: 'not_found', status: 404);
    }
  }

  Future<Map<String, dynamic>> _listTransactions(Map<String, dynamic> body) async {
    String s(String k) => (body[k] as String?)?.trim() ?? '';
    final from = s('from'), to = s('to'), category = s('category'), direction = s('direction');
    final merchant = s('merchant').toLowerCase();
    final rows = (await _allTransactions()).where((t) {
      final date = t['date'] as String;
      return (from.isEmpty || date.compareTo(from) >= 0) &&
          (to.isEmpty || date.compareTo(to) <= 0) &&
          (category.isEmpty || t['category'] == category) &&
          (direction.isEmpty || t['direction'] == direction) &&
          (merchant.isEmpty || (t['merchant'] as String).toLowerCase().contains(merchant));
    }).toList();
    const perPage = 25;
    final pages = rows.isEmpty ? 1 : (rows.length / perPage).ceil();
    final page = ((body['page'] as num?)?.toInt() ?? 1).clamp(1, 1 << 20);
    final start = (page - 1) * perPage;
    return {
      'transactions': start >= rows.length ? <Map<String, dynamic>>[] : rows.sublist(start, (start + perPage).clamp(0, rows.length)),
      'page': page,
      'totalPages': pages,
      'total': rows.length,
      'hasMore': page < pages,
    };
  }

  Future<Map<String, dynamic>> _recategorise(Map<String, dynamic> body) async {
    final rows = await _allTransactions();
    final index = rows.indexWhere((t) => t['transactionId'] == body['transactionId']);
    if (index < 0) throw const ApiException("That transaction isn't on this account.", code: 'transaction_not_found', status: 404);
    final hub = await _fixture('hub');
    final choices = hub['choices'] as Map<String, dynamic>;
    final current = rows[index];
    final allowed = ((current['direction'] == 'in' ? choices['in'] : choices['out']) as List).cast<Map<String, dynamic>>();
    final chosen = allowed.where((c) => c['category'] == body['category']).firstOrNull;
    if (chosen == null) {
      throw const ApiException('Money in can only go in a money-in category, and money out in a money-out one.',
          code: 'wrong_direction', status: 400);
    }
    rows[index] = {...current, 'category': chosen['category'], 'categoryWords': chosen['words'], 'recategorised': true};
    return {'transaction': rows[index]};
  }

  Future<Map<String, dynamic>> _saveGoal(Map<String, dynamic> body) async {
    final hub = await _fixture('hub');
    final name = (body['name'] as String?)?.trim() ?? '';
    final target = (body['target'] as num?)?.toDouble() ?? 0;
    final saved = (body['saved'] as num?)?.toDouble() ?? 0;
    final byDate = (body['byDate'] as String?) ?? '';
    final due = DateTime.tryParse(byDate);
    if (name.isEmpty || target <= 0 || due == null) {
      throw const ApiException('Give the goal a name, an amount and a date.', code: 'bad_request', status: 400);
    }
    final asOf = DateTime.parse((hub['overview'] as Map)['asOf'] as String);
    final months = ((due.year - asOf.year) * 12 + due.month - asOf.month).clamp(1, 600);
    final needed = ((target - saved) / months).clamp(0, double.infinity).toDouble();
    final goal = {
      'name': name,
      'target': target,
      'byDate': byDate,
      'saved': saved,
      'neededPerMonth': double.parse(needed.toStringAsFixed(2)),
      'onTrack': needed <= 209.9,
      'plan': {'months': months, 'neededPerMonth': double.parse(needed.toStringAsFixed(2)), 'changes': <Object>[]},
    };
    final goals = (hub['goals'] as List).cast<Map<String, dynamic>>()
      ..removeWhere((g) => g['name'] == name)
      ..add(goal);
    hub['goals'] = goals;
    return {'goal': goal, 'plan': goal['plan']};
  }
}
