// A current account card payment's card payment ID, so "Dispute this payment" can name it (moneyhub/data.py
// card_payments: TXN-<card ending>-<date without dashes>-<amount in pence>). Shown only when the ID is in the
// card payments the Cards screen lists (only the latest 25 are).
import type { CardPayment, CardsView } from '../../cards/domain/cards';
import type { Transaction } from './transactions';

// The categories whose money out is a debit card payment (moneyhub/data.py CARD_CATEGORIES).
export const CARD_CATEGORIES = new Set([
  'groceries',
  'coffee',
  'takeaways',
  'eating_out',
  'transport',
  'shopping',
  'entertainment',
  'gifts',
  'holidays',
  'subscriptions',
]);

export function cardPaymentId(t: Pick<Transaction, 'date' | 'amount' | 'category'>, debitEnding: string): string {
  if (!debitEnding || !(t.amount < 0) || !CARD_CATEGORIES.has(t.category)) return '';
  return `TXN-${debitEnding}-${t.date.replace(/-/g, '')}-${Math.round(Math.abs(t.amount) * 100)}`;
}

export function matchCardPayment(t: Pick<Transaction, 'date' | 'amount' | 'category'>, cards: CardsView): CardPayment | null {
  const debit = cards.cards.find((c) => c.type === 'debit');
  const id = cardPaymentId(t, debit?.ending || '');
  return id ? cards.payments.find((p) => p.id === id) || null : null;
}
