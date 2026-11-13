// The one handler every notification tap goes through (a real push, a local notification, or a row on the
// Notifications screen), and where intents wait until the customer is signed in (in memory only).
import type { NavigationContainerRef } from '@react-navigation/native';
import type { RootParams } from '../../../app/navigation/routes';
import type { AssistantController } from '../../assistant/domain/assistantController';
import { AssistIntent, contextMatches, parseAssistIntent, PushData } from '../domain/intents';

type Listener = () => void;

// Intents that arrived before the app could run them (not signed in yet, or still loading).
class IntentInbox {
  private queue: AssistIntent[] = [];
  private listeners = new Set<Listener>();

  push(intent: AssistIntent): void {
    this.queue.push(intent);
    this.listeners.forEach((l) => l());
  }

  take(): AssistIntent | undefined {
    return this.queue.shift();
  }

  get size(): number {
    return this.queue.length;
  }

  subscribe(listener: Listener): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }
}

export const intentInbox = new IntentInbox();

// A notification's data, from any source: validated, then queued for the signed-in app.
export function handleNotificationTap(data: PushData): AssistIntent {
  const intent = parseAssistIntent(data);
  intentInbox.push(intent);
  return intent;
}

// Go to the intent's screen, then (for a money topic) start a chat or call once that screen has said where the
// customer is (CONTRACT.md section 7).
export function runIntent(intent: AssistIntent, navigation: NavigationContainerRef<RootParams>, assistant: AssistantController): void {
  const nonce = Date.now();
  const d = intent.destination;
  switch (d.screen) {
    case 'home':
      navigation.navigate('Tabs', { screen: 'Home' });
      break;
    case 'accounts':
      navigation.navigate('Tabs', { screen: 'Accounts' });
      break;
    case 'mortgages':
      navigation.navigate('Mortgages');
      break;
    case 'cards':
      navigation.navigate('Tabs', { screen: 'Cards', params: { paymentId: d.paymentId, tab: d.tab, nonce } });
      break;
    case 'money_hub':
      navigation.navigate('Tabs', { screen: 'MoneyHub', params: { view: d.view, nonce } });
      break;
    case 'transaction':
      navigation.navigate('TransactionDetail', { transactionId: d.transactionId, nonce });
      break;
  }
  if (intent.autoStart) assistant.autoStart(intent.mode, contextMatches(d));
}
