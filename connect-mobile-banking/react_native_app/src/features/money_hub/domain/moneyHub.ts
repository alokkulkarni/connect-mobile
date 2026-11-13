// The Money Hub: money in and out by month, what's expected, regular payments and savings goals (the Money Hub's own
// page view, moneyhub/service.py page_view). Its tabs are the `view` the assistant is told.

export type HubView = 'out' | 'in' | 'expected' | 'transactions' | 'goals';

export const HUB_VIEWS: [HubView, string][] = [
  ['out', 'Money out'],
  ['in', 'Money in'],
  ['expected', 'Expected'],
  ['transactions', 'Transactions'],
  ['goals', 'Goals'],
];

export const isHubView = (v: unknown): v is HubView => HUB_VIEWS.some(([key]) => key === v);

export type CategoryTotal = { category: string; words: string; total: number; count: number; share: number; discretionary?: boolean };
export type MonthSummary = { month: string; moneyIn: number; moneyOut: number; movedToSavings: number; net: number; transactions: number };
export type MonthSpending = { month: string; total: number; discretionary: number; essential: number; categories: CategoryTotal[] };
export type MonthIncome = { month: string; total: number; categories?: CategoryTotal[]; salary?: number; other?: number };
export type Expected = { merchant: string; merchantName: string; words: string; category: string; amount: number; date: string };
export type ForecastMonth = { month: string; expectedIn: number; expectedOut: number; regularIn: Expected[]; regularOut: Expected[]; endBalance?: number };
export type Recurring = {
  merchant: string;
  merchantName: string;
  category: string;
  words: string;
  direction: 'in' | 'out' | string;
  amount: number;
  dayOfMonth: number;
  lastPaid: string;
  nextExpected: string;
  discretionary: boolean;
};
export type Goal = {
  name: string;
  target: number;
  byDate: string;
  saved: number;
  neededPerMonth: number;
  onTrack: boolean;
  plan?: { months?: number; gapPerMonth?: number; targetDateWords?: string; reachedAtCurrentRate?: { words: string }; changes?: { change: string; savesPerMonth: number }[] };
};

export type MoneyHub = {
  overview: {
    asOf: string;
    balance: number;
    thisMonthSoFar: MonthSummary;
    months: MonthSummary[];
    averageMonth: { moneyIn: number; moneyOut: number; movedToSavings: number; net: number };
    topSpending: CategoryTotal[];
    moneyInSources: CategoryTotal[];
  };
  forecast: { asOf: string; startBalance: number; months: ForecastMonth[] };
  monthlySpending: MonthSpending[];
  monthlyIncome: MonthIncome[];
  recurring: Recurring[];
  discretionary: { essentialPerMonth: number; discretionaryPerMonth: number; discretionaryShare: number };
  goals: Goal[];
  choices: { in: { category: string; words: string }[]; out: { category: string; words: string }[] };
  talk: boolean;
};

export type NewGoal = { name: string; target: number; byDate: string; saved: number };

export interface MoneyHubRepository {
  hub(): Promise<MoneyHub>;
  saveGoal(goal: NewGoal): Promise<void>;
  deleteGoal(name: string): Promise<void>;
}

// A goal from the form, checked before it goes to the server.
export function validateGoal(name: string, target: string, byDate: string, saved: string): NewGoal | string {
  const n = name.trim();
  const t = Number(target.replace(/[£,\s]/g, ''));
  const s = Number((saved || '0').replace(/[£,\s]/g, ''));
  if (!n) return 'Give the goal a name.';
  if (!(t > 0)) return 'Enter how much you want to save.';
  if (!(s >= 0) || s > t) return "What you've saved so far must be between £0 and the goal.";
  if (!/^\d{4}-\d{2}-\d{2}$/.test(byDate)) return 'Enter the date as YYYY-MM-DD.';
  return { name: n.slice(0, 60), target: t, byDate, saved: s };
}

export const goalProgress = (g: Goal): number => (g.target > 0 ? Math.max(0, Math.min(1, g.saved / g.target)) : 0);
