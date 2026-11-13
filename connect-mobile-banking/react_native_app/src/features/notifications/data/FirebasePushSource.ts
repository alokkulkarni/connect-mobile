// A real push service (Firebase Cloud Messaging, for both platforms) behind the same PushSource as the local
// notifications. With no Firebase configuration in the app (none is in the repository) it does nothing: every call
// is guarded, and a missing default app is simply "no push here". Its taps go to the same handler.
import type { PushSource, TapHandler } from '../domain/ports';
import type { PushData } from '../domain/intents';

type Message = { data?: Record<string, unknown> } | null;
type Message2 = { data?: Record<string, unknown>; notification?: { title?: string; body?: string } } | null;
type Messaging = {
  getInitialNotification(): Promise<Message>;
  onNotificationOpenedApp(listener: (m: Message) => void): () => void;
  onMessage(listener: (m: Message2) => void): () => void;
};

// While the app is open a push isn't shown by the system: it is shown as a local notification instead.
export type ForegroundDisplay = (title: string, body: string, data: PushData) => void;

const asData = (raw: unknown): PushData => {
  const out: PushData = {};
  if (raw && typeof raw === 'object') for (const [k, v] of Object.entries(raw)) if (typeof v === 'string') out[k] = v;
  return out;
};

function messaging(): Messaging | null {
  try {
    // Loaded lazily: without the native Firebase setup, importing it must not stop the app starting.
    const app = require('@react-native-firebase/app');
    if (!app.getApps || app.getApps().length === 0) return null; // no GoogleService-Info.plist / google-services.json
    const m = require('@react-native-firebase/messaging');
    return (m.getMessaging ? m.getMessaging() : m.default()) as Messaging;
  } catch {
    return null;
  }
}

export class FirebasePushSource implements PushSource {
  constructor(private readonly showInForeground: ForegroundDisplay = () => {}) {}

  async start(onTap: TapHandler): Promise<() => void> {
    const m = messaging();
    if (!m) return () => {};
    try {
      const initial = await m.getInitialNotification();
      if (initial?.data) onTap(asData(initial.data));
      const stopOpened = m.onNotificationOpenedApp((message) => message?.data && onTap(asData(message.data)));
      const stopForeground = m.onMessage((message) => {
        if (message?.data) this.showInForeground(message.notification?.title || 'Nationwide', message.notification?.body || '', asData(message.data));
      });
      return () => {
        stopOpened();
        stopForeground();
      };
    } catch {
      return () => {};
    }
  }
}
