// Simulated push: real local notifications from the phone's own notification system (notifee), carrying the same
// data a push would. A tap goes to the same handler as a real push (CONTRACT.md section 7, "Simulated push").
//
//   app open          onForegroundEvent PRESS
//   in the background onBackgroundEvent PRESS (registered in index.js, before the app mounts)
//   closed            getInitialNotification, read when the app starts listening (after sign-in has loaded)
//
// Timing: a notifee timestamp trigger. On iOS that is the system's own time-interval trigger, which fires with the
// phone locked or the app closed. On Android it uses an inexact AlarmManager alarm (SET_AND_ALLOW_WHILE_IDLE), which
// needs no exact-alarm permission and fires with the app closed; Android may hold it back a little in deep sleep.
// A JavaScript delay wouldn't survive iOS suspending the app, so it isn't used.
import { Platform } from 'react-native';
import notifee, { AlarmType, AndroidImportance, AuthorizationStatus, EventType, TriggerType } from '@notifee/react-native';
import type { PushData } from '../domain/intents';
import type { LocalNotifier, PushSource, TapHandler } from '../domain/ports';
import type { SampleNotification } from '../domain/samples';

const CHANNEL = { id: 'money-alerts', name: 'Money alerts', importance: AndroidImportance.HIGH };

// Taps that arrive before anything listens (a background tap while the app is waking) wait here.
const waiting: PushData[] = [];
const handled = new Set<string>();
let listener: TapHandler | null = null;

const asData = (raw: unknown): PushData => {
  const out: PushData = {};
  if (raw && typeof raw === 'object') for (const [k, v] of Object.entries(raw)) if (typeof v === 'string') out[k] = v;
  return out;
};

// One tap, once (iOS can report the launching tap both as the initial notification and as an event).
export function deliverTap(id: string | undefined, raw: unknown): void {
  if (id) {
    if (handled.has(id)) return;
    handled.add(id);
  }
  const data = asData(raw);
  if (listener) listener(data);
  else waiting.push(data);
}

// Called once from index.js: background taps, even before React has mounted.
export function registerBackgroundTaps(): void {
  notifee.onBackgroundEvent(async ({ type, detail }) => {
    if (type === EventType.PRESS) deliverTap(detail.notification?.id, detail.notification?.data);
  });
}

export class LocalNotificationPushSource implements PushSource, LocalNotifier {
  private channelReady: Promise<string> | null = null;

  async start(onTap: TapHandler): Promise<() => void> {
    listener = onTap;
    waiting.splice(0).forEach(onTap);
    const stopForeground = notifee.onForegroundEvent(({ type, detail }) => {
      if (type === EventType.PRESS) deliverTap(detail.notification?.id, detail.notification?.data);
    });
    try {
      const initial = await notifee.getInitialNotification();
      if (initial) deliverTap(initial.notification.id, initial.notification.data);
    } catch {
      /* nothing launched the app */
    }
    return () => {
      stopForeground();
      if (listener === onTap) listener = null;
    };
  }

  async ensurePermission(): Promise<boolean> {
    try {
      const settings = await notifee.requestPermission();
      return settings.authorizationStatus === AuthorizationStatus.AUTHORIZED || settings.authorizationStatus === AuthorizationStatus.PROVISIONAL;
    } catch {
      return false;
    }
  }

  private async content(notification: SampleNotification) {
    if (Platform.OS === 'android') {
      this.channelReady = this.channelReady || notifee.createChannel(CHANNEL);
      await this.channelReady;
    }
    return {
      id: `${notification.id}-${Date.now()}`,
      title: notification.title,
      body: notification.body,
      data: notification.data,
      android: { channelId: CHANNEL.id, importance: AndroidImportance.HIGH, pressAction: { id: 'default', launchActivity: 'default' }, smallIcon: 'ic_launcher' },
      ios: { foregroundPresentationOptions: { banner: true, list: true, sound: true, badge: false } },
    };
  }

  // A real push that arrived while the app is open shows as this banner; tapping it comes back through start().
  async showNow(notification: SampleNotification): Promise<void> {
    await notifee.displayNotification(await this.content(notification));
  }

  async schedule(notification: SampleNotification, delayMs: number): Promise<void> {
    await notifee.createTriggerNotification(
      await this.content(notification),
      {
        type: TriggerType.TIMESTAMP,
        timestamp: Date.now() + delayMs,
        ...(Platform.OS === 'android' ? { alarmManager: { type: AlarmType.SET_AND_ALLOW_WHILE_IDLE } } : {}),
      },
    );
  }
}
