// The app's notification sources, started once when the app starts (before sign-in, so the tap that launched the
// app isn't lost). Every tap goes to the one handler; intents wait in memory until the customer is signed in.
import { FirebasePushSource } from '../features/notifications/data/FirebasePushSource';
import { LocalNotificationPushSource } from '../features/notifications/data/LocalNotificationPushSource';
import { handleNotificationTap } from '../features/notifications/presentation/intents';

export const localNotifications = new LocalNotificationPushSource();

const firebase = new FirebasePushSource((title, body, data) => {
  localNotifications.showNow({ id: `push-${data.topic || 'message'}`, title, body, data }).catch(() => {});
});

let started: Promise<() => void> | null = null;

export function startPush(): Promise<() => void> {
  started =
    started ||
    Promise.all([localNotifications.start(handleNotificationTap), firebase.start(handleNotificationTap)]).then((stops) => () => stops.forEach((s) => s()));
  return started;
}
