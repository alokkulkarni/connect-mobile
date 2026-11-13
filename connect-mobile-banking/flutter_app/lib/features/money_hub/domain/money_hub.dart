// The Money Hub: where the customer's money goes, what comes in, what's expected and their savings goals
// (connect-money-hub/moneyhub/service.py page_view). Its tabs are the `view` the assistant is told.

enum MoneyHubView {
  out('out', 'Money out'),
  moneyIn('in', 'Money in'),
  expected('expected', 'Expected'),
  transactions('transactions', 'Transactions'),
  goals('goals', 'Goals');

  const MoneyHubView(this.key, this.label);

  final String key; // what the server calls the tab
  final String label;

  static MoneyHubView? fromKey(String? key) => values.where((v) => v.key == key).firstOrNull;
}

class CategoryTotal {
  const CategoryTotal({required this.category, required this.words, required this.total, required this.share, required this.discretionary});

  final String category, words;
  final double total;
  final int share; // per cent
  final bool discretionary;
}

class MonthSummary {
  const MonthSummary({required this.month, required this.moneyIn, required this.moneyOut, required this.movedToSavings, required this.net});

  final String month; // 2026-10
  final double moneyIn, moneyOut, movedToSavings, net;
}

class MonthSpending {
  const MonthSpending({required this.month, required this.total, required this.essential, required this.discretionary});

  final String month;
  final double total, essential, discretionary;
}

class MonthIncome {
  const MonthIncome({required this.month, required this.total, required this.salary, required this.other});

  final String month;
  final double total, salary, other;
}

class Overview {
  const Overview({
    required this.asOf,
    required this.balance,
    required this.thisMonth,
    required this.months,
    required this.averageMonth,
    required this.topSpending,
    required this.moneyInSources,
  });

  final String asOf;
  final double balance;
  final MonthSummary thisMonth;
  final List<MonthSummary> months;
  final MonthSummary averageMonth;
  final List<CategoryTotal> topSpending;
  final List<CategoryTotal> moneyInSources;
}

class ExpectedItem {
  const ExpectedItem({required this.merchantName, required this.words, required this.amount, required this.date});

  final String merchantName, words, date;
  final double amount;
}

class ForecastMonth {
  const ForecastMonth({
    required this.month,
    required this.expectedIn,
    required this.expectedOut,
    required this.regularIn,
    required this.regularOut,
    required this.everydaySpending,
    required this.endBalance,
  });

  final String month;
  final double expectedIn, expectedOut, everydaySpending, endBalance;
  final List<ExpectedItem> regularIn, regularOut;
}

class Forecast {
  const Forecast({required this.startBalance, required this.months, required this.basis});

  final double startBalance;
  final List<ForecastMonth> months;
  final String basis;
}

class Habit {
  const Habit({required this.words, required this.perMonth, required this.discretionary, required this.timesPerMonth});

  final String words;
  final double perMonth, timesPerMonth;
  final bool discretionary;
}

class Discretionary {
  const Discretionary({required this.essentialPerMonth, required this.discretionaryPerMonth, required this.share, required this.habits});

  final double essentialPerMonth, discretionaryPerMonth;
  final int share;
  final List<Habit> habits;
}

class GoalChange {
  const GoalChange(this.change, this.savesPerMonth);

  final String change;
  final double savesPerMonth;
}

class Goal {
  const Goal({
    required this.name,
    required this.target,
    required this.byDate,
    required this.saved,
    required this.neededPerMonth,
    required this.onTrack,
    this.targetDateWords,
    this.reachedAtCurrentRate,
    this.changes = const [],
  });

  final String name, byDate;
  final double target, saved, neededPerMonth;
  final bool onTrack;
  final String? targetDateWords, reachedAtCurrentRate;
  final List<GoalChange> changes;

  double get progress => target <= 0 ? 0 : (saved / target).clamp(0, 1);
}

/// A payment that comes in or goes out regularly, and when it's next expected.
class RegularPayment {
  const RegularPayment({required this.merchantName, required this.words, required this.category, required this.direction, required this.amount, required this.nextExpected});

  final String merchantName, words, category, direction, nextExpected;
  final double amount;
}

class CategoryChoice {
  const CategoryChoice(this.category, this.words);

  final String category, words;
}

class MoneyHub {
  const MoneyHub({
    required this.overview,
    required this.forecast,
    required this.monthlySpending,
    required this.monthlyIncome,
    required this.discretionary,
    required this.recurring,
    required this.goals,
    required this.choicesIn,
    required this.choicesOut,
  });

  final Overview overview;
  final Forecast forecast;
  final List<MonthSpending> monthlySpending;
  final List<MonthIncome> monthlyIncome;
  final Discretionary discretionary;
  final List<RegularPayment> recurring;
  final List<Goal> goals;
  final List<CategoryChoice> choicesIn, choicesOut;

  /// The categories a transaction may move to: money in only to money in, money out only to money out.
  List<CategoryChoice> choicesFor({required bool moneyIn}) => moneyIn ? choicesIn : choicesOut;
}

abstract interface class MoneyHubRepository {
  Future<MoneyHub> hub();
  Future<void> saveGoal({required String name, required double target, required String byDate, double saved = 0});
  Future<void> deleteGoal(String name);
}
