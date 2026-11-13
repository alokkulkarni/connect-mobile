// A push notification's data, turned into what the app should do (CONTRACT.md section 7). The data carries no
// secret, no customer ID and no amount the app trusts: it names a topic, a mode and at most one of the customer's
// own payments or transactions, which the screens check against the customer's own data.
import { isHubView, HubView } from '../../money_hub/domain/moneyHub';
import { PAYMENT_ID } from '../../cards/domain/cards';
import { TRANSACTION_ID } from '../../transactions/domain/transactions';

export type Mode = 'chat' | 'call';

// Where an intent goes. `transaction` and `card_payment` fall back to their topic's screen when the item isn't found.
export type Destination =
  | { screen: 'home' }
  | { screen: 'accounts' }
  | { screen: 'mortgages' }
  | { screen: 'cards'; paymentId?: string; tab?: 'payments' | 'disputes' }
  | { screen: 'money_hub'; view: HubView }
  | { screen: 'transaction'; transactionId: string };

export type AssistIntent = {
  topic: string;
  mode: Mode;
  destination: Destination;
  autoStart: boolean;
};

export const MONEY_TOPICS = new Set([
  'unusual_payment',
  'large_payment',
  'money_out',
  'money_in',
  'salary_in',
  'low_balance',
  'bill_due',
  'savings_goal',
  'transfer',
  'spending_insight',
  'dispute_update',
]);

const TOPIC_VIEWS: Record<string, HubView> = {
  money_out: 'out',
  spending_insight: 'out',
  money_in: 'in',
  salary_in: 'in',
  low_balance: 'expected',
  bill_due: 'expected',
  savings_goal: 'goals',
};

const str = (data: Record<string, unknown>, key: string): string => (typeof data[key] === 'string' ? (data[key] as string).trim() : '');

const HOME: AssistIntent = { topic: '', mode: 'chat', destination: { screen: 'home' }, autoStart: false };

export function parseAssistIntent(raw: unknown): AssistIntent {
  if (!raw || typeof raw !== 'object') return HOME;
  const data = raw as Record<string, unknown>;
  if (str(data, 'v') !== '1') return HOME;
  const topic = str(data, 'topic');
  const mode: Mode = str(data, 'mode') === 'call' ? 'call' : 'chat';
  const paymentId = PAYMENT_ID.test(str(data, 'paymentId')) ? str(data, 'paymentId') : '';
  const transactionId = TRANSACTION_ID.test(str(data, 'transactionId')) ? str(data, 'transactionId') : '';
  const view = isHubView(str(data, 'view')) ? (str(data, 'view') as HubView) : undefined;
  const autoStart = str(data, 'intent') === 'assist' && MONEY_TOPICS.has(topic);
  return { topic, mode, destination: destinationFor(topic, { paymentId, transactionId, view }), autoStart };
}

function destinationFor(topic: string, ids: { paymentId: string; transactionId: string; view?: HubView }): Destination {
  switch (topic) {
    case 'unusual_payment':
      return ids.paymentId ? { screen: 'cards', paymentId: ids.paymentId } : { screen: 'cards' };
    case 'large_payment':
      return ids.transactionId ? { screen: 'transaction', transactionId: ids.transactionId } : { screen: 'money_hub', view: ids.view || 'transactions' };
    case 'transfer':
      return { screen: 'accounts' };
    case 'dispute_update':
      return { screen: 'cards', tab: 'disputes' };
    case 'mortgage':
      return { screen: 'mortgages' };
    default:
      if (TOPIC_VIEWS[topic]) return { screen: 'money_hub', view: ids.view || TOPIC_VIEWS[topic] };
      return { screen: 'home' };
  }
}

// The fallback when a named payment or transaction isn't one of the customer's own.
export function fallbackFor(destination: Destination): Destination {
  if (destination.screen === 'transaction') return { screen: 'money_hub', view: 'transactions' };
  if (destination.screen === 'cards') return { screen: 'cards' };
  return destination;
}

// The data a push (or a simulated one) carries: strings only.
export type PushData = Record<string, string>;

// The screen (route) a destination opens.
export function screenOf(destination: Destination): string {
  switch (destination.screen) {
    case 'home':
      return 'Home';
    case 'accounts':
      return 'Accounts';
    case 'mortgages':
      return 'Mortgages';
    case 'cards':
      return 'Cards';
    case 'money_hub':
      return 'MoneyHub';
    case 'transaction':
      return 'TransactionDetail';
  }
}

type PublishedContext = { screen: string; page?: string; view?: string; paymentId?: string };

// When the screen has published the context the intent asked for: the Money Hub on its tab, Cards with the payment
// chosen (or, when it isn't one of the customer's, Cards without one), the transaction's details.
export function contextMatches(destination: Destination): (context: PublishedContext) => boolean {
  const screen = screenOf(destination);
  return (context) => {
    if (context.screen !== screen) return false;
    if (destination.screen === 'money_hub') return context.view === destination.view;
    if (destination.screen === 'cards' && destination.paymentId) {
      return context.paymentId === destination.paymentId || (context.page === 'cards' && !context.paymentId);
    }
    return true;
  };
}
