// The Notifications screen's sample notifications, worded from the customer's own data (CONTRACT.md section 7,
// "Simulated push"). Each has a fixed mode, so both a chat and a call can be tried.
import { dayMonth, day, gbp, tidyMerchant } from '../../../core/format/money';
import type { CardsView } from '../../cards/domain/cards';
import type { MoneyHub } from '../../money_hub/domain/moneyHub';
import type { Transaction } from '../../transactions/domain/transactions';
import type { Mode, PushData } from './intents';

export type SampleNotification = { id: string; title: string; body: string; data: PushData };

const tap = (mode: Mode) => (mode === 'call' ? 'Tap to call us.' : 'Tap to chat with us.');

const data = (topic: string, mode: Mode, extra: Partial<PushData> = {}): PushData => ({
  v: '1',
  intent: 'assist',
  topic,
  mode,
  paymentId: '',
  transactionId: '',
  view: '',
  ...extra,
});

export function buildSamples(input: { cards: CardsView; hub: MoneyHub; transactions: Transaction[] }): SampleNotification[] {
  const out: SampleNotification[] = [];

  // The largest credit card payment (newest if tied; the list is newest first).
  const credit = input.cards.payments
    .filter((p) => p.card === 'credit')
    .reduce<CardsView['payments'][number] | undefined>((best, p) => (!best || p.amount > best.amount ? p : best), undefined);
  if (credit) {
    out.push({
      id: 'unusual_payment',
      title: 'Did you make this payment?',
      body: `${gbp(credit.amount)} at ${tidyMerchant(credit.merchant)} on your credit card ending ${credit.ending}. ${tap('chat')}`,
      data: data('unusual_payment', 'chat', { paymentId: credit.id }),
    });
  }

  // The next bills in the forecast.
  const bills = input.hub.forecast?.months?.[0]?.regularOut || [];
  if (bills.length) {
    const first = bills[0];
    const more = bills.length - 1;
    out.push({
      id: 'low_balance',
      title: 'Your balance is getting low',
      body: `${gbp(first.amount)} to ${first.merchantName}${more ? ` and ${more} more bills` : ''} due from ${day(first.date)}. ${tap('call')}`,
      data: data('low_balance', 'call'),
    });
  }

  // The salary.
  const salary = input.hub.recurring.find((r) => r.category === 'salary');
  if (salary) {
    out.push({
      id: 'salary_in',
      title: 'Your salary has arrived',
      body: `${gbp(salary.amount)} from ${salary.merchantName} arrived on ${dayMonth(salary.lastPaid)}. ${tap('chat')}`,
      data: data('salary_in', 'chat'),
    });
  }

  // The first savings goal, if there is one.
  const goal = input.hub.goals[0];
  if (goal) {
    out.push({
      id: 'savings_goal',
      title: `Your ${goal.name} goal`,
      body: `You've saved ${gbp(goal.saved)} of ${gbp(goal.target)}${goal.plan?.targetDateWords ? ` for ${goal.plan.targetDateWords}` : ''}. ${tap('call')}`,
      data: data('savings_goal', 'call'),
    });
  }

  // The largest money-out transaction on the first page.
  const largest = input.transactions.filter((t) => t.amount < 0).sort((a, b) => a.amount - b.amount)[0];
  if (largest) {
    out.push({
      id: 'large_payment',
      title: 'A large payment left your account',
      body: `${gbp(Math.abs(largest.amount))} to ${largest.merchantName} on ${dayMonth(largest.date)}. ${tap('chat')}`,
      data: data('large_payment', 'chat', { transactionId: largest.transactionId }),
    });
  }
  return out;
}
