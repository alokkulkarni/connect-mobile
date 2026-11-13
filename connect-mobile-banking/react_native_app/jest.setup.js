/* Native modules replaced for unit tests: nothing here reaches a device, a network or AWS. */
/* eslint-env jest */
import mockSafeAreaContext from 'react-native-safe-area-context/jest/mock';

jest.mock('react-native-safe-area-context', () => mockSafeAreaContext);

jest.mock('@notifee/react-native', () => require('@notifee/react-native/jest-mock'));

jest.mock('react-native-keychain', () => {
  let stored = null;
  return {
    ACCESSIBLE: { WHEN_UNLOCKED_THIS_DEVICE_ONLY: 'AccessibleWhenUnlockedThisDeviceOnly' },
    getGenericPassword: jest.fn(async () => (stored ? { username: 'session', password: stored } : false)),
    setGenericPassword: jest.fn(async (_u, password) => {
      stored = password;
      return true;
    }),
    resetGenericPassword: jest.fn(async () => {
      stored = null;
      return true;
    }),
  };
});

jest.mock('react-native-maps', () => {
  const React = require('react');
  const { View } = require('react-native');
  const MapView = (props) => React.createElement(View, props, props.children);
  const Marker = (props) => React.createElement(View, props);
  return { __esModule: true, default: MapView, Marker };
});

jest.mock('react-native-webview', () => {
  const React = require('react');
  const { View } = require('react-native');
  const WebView = React.forwardRef((props, ref) => React.createElement(View, { ...props, ref }));
  return { __esModule: true, default: WebView, WebView };
});

jest.mock('@react-native-firebase/app', () => ({ getApps: () => [] }));
jest.mock('@react-native-firebase/messaging', () => ({}));
