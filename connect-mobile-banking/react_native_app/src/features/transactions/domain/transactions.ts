// Current account transactions (the Money Hub's own list), finding one by its reference, and the words for asking
// the assistant about one (CONTRACT.md section 8).
import { dayMonth, gbp } from '../../../core/format/money';

export type Transaction = {
  transactionId: string;
  date: string;
  merchant: string;
  merchantName: string;
  amount: number; // negative = money out
  category: string;
  categoryWords: string;
  direction: 'in' | 'out' | string;
  balanceAfter: number;
  recategorised: boolean;
};

export type TransactionPage = { transactions: Transaction[]; page: number; totalPages: number; total: number; hasMore: boolean };

export type TransactionFilter = { from?: string; to?: string; category?: string; direction?: string; merchant?: string; page?: number };

export interface TransactionsRepository {
  list(filter: TransactionFilter): Promise<TransactionPage>;
  recategorise(transactionId: string, category: string): Promise<Transaction>;
}

export const TRANSACTION_ID = /^MH-\d{3}-\d{8}-\d{4}$/;

// MH-001-20261015-0332 -> 2026-10-15
export function dateOfTransactionId(id: string): string {
  if (!TRANSACTION_ID.test(id)) return '';
  const d = id.split('-')[2];
  return `${d.slice(0, 4)}-${d.slice(4, 6)}-${d.slice(6, 8)}`;
}

// One of the customer's transactions by its reference: the day's list, then the reference. Null if not theirs.
export async function findTransaction(repository: TransactionsRepository, id: string): Promise<Transaction | null> {
  const date = dateOfTransactionId(id);
  if (!date) return null;
  for (let page = 1; page <= 5; page++) {
    const found = await repository.list({ from: date, to: date, page });
    const hit = found.transactions.find((t) => t.transactionId === id);
    if (hit) return hit;
    if (!found.hasMore) break;
  }
  return null;
}

export const isMoneyIn = (t: Pick<Transaction, 'direction' | 'amount'>): boolean => t.direction === 'in' || (t.direction !== 'out' && t.amount > 0);

// The words put in the chat box (unsent) for "Ask about this payment".
export function askDraft(t: Pick<Transaction, 'amount' | 'merchantName' | 'date'>): string {
  return `About my ${gbp(Math.abs(t.amount))} payment to ${t.merchantName} on ${dayMonth(t.date)}: `;
}

// The categories one transaction may move to: money in only to money-in ones, money out only to money-out ones.
export function categoryChoices(t: Transaction, choices: { in: Choice[]; out: Choice[] }): Choice[] {
  return isMoneyIn(t) ? choices.in : choices.out;
}

export type Choice = { category: string; words: string };
