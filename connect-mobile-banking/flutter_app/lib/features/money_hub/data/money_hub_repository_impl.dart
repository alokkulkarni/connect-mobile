import '../../../core/network/api_transport.dart';
import '../domain/money_hub.dart';

class MoneyHubRepositoryImpl implements MoneyHubRepository {
  MoneyHubRepositoryImpl(this._api);

  final ApiTransport _api;

  @override
  Future<MoneyHub> hub() async => moneyHubFromJson(await _api.post('hub'));

  @override
  Future<void> saveGoal({required String name, required double target, required String byDate, double saved = 0}) =>
      _api.post('goal', {'name': name, 'target': target, 'byDate': byDate, 'saved': saved});

  @override
  Future<void> deleteGoal(String name) => _api.post('goal/delete', {'name': name});
}

typedef Json = Map<String, dynamic>;

double _d(Object? v) => v is num ? v.toDouble() : 0;
List<Json> _list(Object? v) => (v as List? ?? const []).cast<Json>();

MonthSummary _month(Object? json) {
  final m = json as Json? ?? const {};
  return MonthSummary(
    month: m['month'] as String? ?? '',
    moneyIn: _d(m['moneyIn']),
    moneyOut: _d(m['moneyOut']),
    movedToSavings: _d(m['movedToSavings']),
    net: _d(m['net']),
  );
}

List<CategoryTotal> _categories(Object? json) => [
      for (final c in _list(json))
        CategoryTotal(
          category: c['category'] as String? ?? '',
          words: c['words'] as String? ?? '',
          total: _d(c['total']),
          share: (c['share'] as num?)?.toInt() ?? 0,
          discretionary: c['discretionary'] == true,
        ),
    ];

List<ExpectedItem> _expected(Object? json) => [
      for (final r in _list(json))
        ExpectedItem(
          merchantName: r['merchantName'] as String? ?? '',
          words: r['words'] as String? ?? '',
          amount: _d(r['amount']),
          date: r['date'] as String? ?? '',
        ),
    ];

MoneyHub moneyHubFromJson(Json json) {
  final o = json['overview'] as Json? ?? const {};
  final f = json['forecast'] as Json? ?? const {};
  final d = json['discretionary'] as Json? ?? const {};
  final choices = json['choices'] as Json? ?? const {};
  return MoneyHub(
    overview: Overview(
      asOf: o['asOf'] as String? ?? '',
      balance: _d(o['balance']),
      thisMonth: _month(o['thisMonthSoFar']),
      months: [for (final m in _list(o['months'])) _month(m)],
      averageMonth: _month(o['averageMonth']),
      topSpending: _categories(o['topSpending']),
      moneyInSources: _categories(o['moneyInSources']),
    ),
    forecast: Forecast(
      startBalance: _d(f['startBalance']),
      basis: f['basis'] is String ? f['basis'] as String : '',
      months: [
        for (final m in _list(f['months']))
          ForecastMonth(
            month: m['month'] as String? ?? '',
            expectedIn: _d(m['expectedIn']),
            expectedOut: _d(m['expectedOut']),
            regularIn: _expected(m['regularIn']),
            regularOut: _expected(m['regularOut']),
            everydaySpending: m['everydaySpending'] is List
                ? _list(m['everydaySpending']).fold<double>(0, (sum, c) => sum + _d(c['amount']))
                : _d(m['everydaySpending']),
            endBalance: _d(m['endBalance']),
          ),
      ],
    ),
    monthlySpending: [
      for (final m in _list(json['monthlySpending']))
        MonthSpending(
          month: m['month'] as String? ?? '',
          total: _d(m['total']),
          essential: _d(m['essential']),
          discretionary: _d(m['discretionary']),
        ),
    ],
    monthlyIncome: [
      for (final m in _list(json['monthlyIncome']))
        MonthIncome(month: m['month'] as String? ?? '', total: _d(m['total']), salary: _d(m['salary']), other: _d(m['other'])),
    ],
    discretionary: Discretionary(
      essentialPerMonth: _d(d['essentialPerMonth']),
      discretionaryPerMonth: _d(d['discretionaryPerMonth']),
      share: (d['discretionaryShare'] as num?)?.toInt() ?? 0,
      habits: [
        for (final h in _list(d['habits']))
          Habit(
            words: h['words'] as String? ?? '',
            perMonth: _d(h['perMonth']),
            discretionary: h['discretionary'] == true,
            timesPerMonth: _d(h['timesPerMonth']),
          ),
      ],
    ),
    recurring: [
      for (final r in _list(json['recurring']))
        RegularPayment(
          merchantName: r['merchantName'] as String? ?? '',
          words: r['words'] as String? ?? '',
          category: r['category'] as String? ?? '',
          direction: r['direction'] as String? ?? '',
          amount: _d(r['amount']),
          nextExpected: r['nextExpected'] as String? ?? '',
        ),
    ],
    goals: [
      for (final g in _list(json['goals']))
        () {
          final plan = g['plan'] as Json? ?? const {};
          final reached = plan['reachedAtCurrentRate'];
          return Goal(
            name: g['name'] as String? ?? '',
            target: _d(g['target']),
            byDate: g['byDate'] as String? ?? '',
            saved: _d(g['saved']),
            neededPerMonth: _d(g['neededPerMonth']),
            onTrack: g['onTrack'] == true,
            targetDateWords: plan['targetDateWords'] as String?,
            reachedAtCurrentRate: reached is Map ? reached['words'] as String? : null,
            changes: [for (final c in _list(plan['changes'])) GoalChange(c['change'] as String? ?? '', _d(c['savesPerMonth']))],
          );
        }(),
    ],
    choicesIn: [for (final c in _list(choices['in'])) CategoryChoice(c['category'] as String, c['words'] as String)],
    choicesOut: [for (final c in _list(choices['out'])) CategoryChoice(c['category'] as String, c['words'] as String)],
  );
}
