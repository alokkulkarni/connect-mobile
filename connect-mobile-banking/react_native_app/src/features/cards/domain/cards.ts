// The customer's cards, their card payments (the card dispute service's own list) and their disputes.

export type BankCard = { type: 'debit' | 'credit' | string; ending: string; name: string };

export type CardPayment = { id: string; date: string; merchant: string; amount: number; card: string; ending: string };

export type CardsView = { cards: BankCard[]; payments: CardPayment[] };

export type Dispute = {
  disputeId: string;
  status: string;
  statusWords: string;
  merchant: string;
  amount: string;
  transactionDate: string;
  cardType: string;
  cardLastFour: string;
  missing: string[];
  open: boolean;
  canSubmit: boolean;
  transactionId: string;
};

export interface CardsRepository {
  cards(): Promise<CardsView>;
}

export interface DisputesRepository {
  list(): Promise<Dispute[]>;
  submit(disputeId: string): Promise<Dispute>;
}

export const PAYMENT_ID = /^TXN-\d{4}-\d{8}-\d{1,9}$/;

export const cardLabel = (card: string, ending: string) => `${card === 'debit' ? 'Debit' : 'Credit'} card ••${ending}`;

// The payment named by a push or a link, only if it is one of the customer's own.
export const findPayment = (view: CardsView, id: string): CardPayment | null =>
  PAYMENT_ID.test(id) ? view.payments.find((p) => p.id === id) || null : null;
