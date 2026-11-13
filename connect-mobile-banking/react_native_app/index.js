/**
 * @format
 */

// Polyfills first: secure random numbers (Connect ClientTokens) and URL.
import 'react-native-get-random-values';
import 'react-native-url-polyfill/auto';
import { AppRegistry } from 'react-native';
import App from './src/app/App';
import { registerBackgroundTaps } from './src/features/notifications/data/LocalNotificationPushSource';
import { name as appName } from './app.json';

// A notification tapped while the app is in the background: registered before the app mounts (notifee's rule).
registerBackgroundTaps();

AppRegistry.registerComponent(appName, () => App);
