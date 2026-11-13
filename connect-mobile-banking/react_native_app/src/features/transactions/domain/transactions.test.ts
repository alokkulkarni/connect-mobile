import { fixtures } from '../../../core/fixtures';
import type { CardsView } from '../../cards/domain/cards';
import { cardPaymentId, matchCardPayment } from './cardPayment';
import { lookupPlace, PlaceEntry } from './places';
import { askDraft, dateOfTransactionId, findTransaction, Transaction, TransactionsRepository } from './transactions';

const cards = fixtures.appCards as CardsView;
const transactions = fixtures.transactions as Transaction[];
const places = fixtures.merchantPlaces.places as PlaceEntry[];

describe('card payment matching', () => {
  it('builds TXN-<debit ending>-<date>-<pence> for a card payment', () => {
    expect(cardPaymentId({ date: '2026-10-15', amount: -32.45, category: 'shopping' }, '4821')).toBe('TXN-4821-20261015-3245');
  });

  it('is empty for money in, direct debits and transfers', () => {
    expect(cardPaymentId({ date: '2026-10-15', amount: 32.45, category: 'shopping' }, '4821')).toBe('');
    expect(cardPaymentId({ date: '2026-10-01', amount: -1050, category: 'housing' }, '4821')).toBe('');
    expect(cardPaymentId({ date: '2026-10-01', amount: -10, category: 'groceries' }, '')).toBe('');
  });

  it("finds the newest card payment among the customer's listed card payments", () => {
    const newest = transactions[0];
    const match = matchCardPayment(newest, cards);
    expect(match?.id).toBe('TXN-4821-20261015-3245');
    expect(match?.merchant).toBe(newest.merchant);
  });

  it('finds nothing for a payment older than the 25 listed', () => {
    const old = transactions.filter((t) => t.amount < 0 && t.category === 'groceries').at(-1)!;
    expect(cards.payments.find((p) => p.id === cardPaymentId(old, '4821'))).toBeUndefined();
    expect(matchCardPayment(old, cards)).toBeNull();
  });
});

describe('merchant places', () => {
  it('finds a physical place by the start of the merchant name', () => {
    expect(lookupPlace(places, 'TESCO STORES 2041')).toMatchObject({ kind: 'place', name: 'Tesco Extra', area: 'Altrincham' });
    expect(lookupPlace(places, 'BP')).toMatchObject({ kind: 'place', area: 'Sale' });
  });

  it('marks online merchants, and knows nothing about direct debits', () => {
    expect(lookupPlace(places, 'AMAZON.CO.UK')).toEqual({ kind: 'online' });
    expect(lookupPlace(places, 'UBER TRIP')).toEqual({ kind: 'online' });
    expect(lookupPlace(places, 'OCTOPUS ENERGY')).toEqual({ kind: 'unknown' });
  });
});

describe('transactions', () => {
  it('reads the date out of a reference', () => {
    expect(dateOfTransactionId('MH-001-20261015-0332')).toBe('2026-10-15');
    expect(dateOfTransactionId('nope')).toBe('');
  });

  it("finds one of the customer's transactions through that day's list", async () => {
    const wanted = transactions[3];
    const list = jest.fn(async ({ from, to }: { from?: string; to?: string }) => {
      const rows = transactions.filter((t) => t.date >= (from || '') && t.date <= (to || '9'));
      return { transactions: rows, page: 1, totalPages: 1, total: rows.length, hasMore: false };
    });
    const repository: TransactionsRepository = { list, recategorise: jest.fn() };
    expect(await findTransaction(repository, wanted.transactionId)).toEqual(wanted);
    expect(list).toHaveBeenCalledWith({ from: wanted.date, to: wanted.date, page: 1 });
    expect(await findTransaction(repository, 'MH-001-20261015-9999')).toBeNull();
  });

  it('offers words for the chat box', () => {
    expect(askDraft({ amount: -32.45, merchantName: 'Amazon', date: '2026-10-15' })).toBe('About my £32.45 payment to Amazon on 15 October: ');
  });
});
