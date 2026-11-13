// Where notification taps come from, and how the app posts its own (simulated) ones. Implementations live in data/.
import type { PushData } from './intents';
import type { SampleNotification } from './samples';

export type TapHandler = (data: PushData) => void;

// A source of notification taps: a real push service, or local notifications. Each calls `onTap` with the
// notification's data, for the one handler both share; `start` also reports the tap that launched the app.
export interface PushSource {
  start(onTap: TapHandler): Promise<() => void>;
}

export interface LocalNotifier {
  // Asks the first time; false if the customer refused.
  ensurePermission(): Promise<boolean>;
  // Posts the notification `delayMs` from now.
  schedule(notification: SampleNotification, delayMs: number): Promise<void>;
}

export const SEND_DELAY_MS = 5_000;
export const SENDING_WORDS = 'Sending in 5 seconds… lock your phone or leave the app to see it arrive.';
export const REFUSED_WORDS = 'Allow notifications for this app in Settings to try this.';
