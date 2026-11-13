// Settings: how the app is signed in, forgetting this device, and about the app.
import React from 'react';
import { Alert } from 'react-native';
import { useApp } from '../../../app/AppContext';
import { Button, Card, Divider, Screen, T } from '../../../core/ui/kit';
import { useScreenContext } from '../../assistant/presentation/useScreenContext';

export function SettingsScreen() {
  const { container, me, signOut } = useApp();
  useScreenContext({ page: 'home', label: 'Settings', launcher: 'Ask us anything', screen: 'Settings' });
  const session = container.session;

  const forget = () =>
    Alert.alert('Forget this device?', 'Any conversation ends, and your internet banking link is removed from this phone.', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Forget', style: 'destructive', onPress: () => signOut('This device has forgotten your internet banking. Open it from your link to see it again.') },
    ]);

  return (
    <Screen>
      <Card style={{ gap: 10 }}>
        <T variant="label">This device</T>
        <T variant="heading">{session.mode === 'sample' ? 'Sample data' : 'Signed in from your link'}</T>
        <T variant="small">
          {session.mode === 'sample'
            ? 'You are exploring with sample data. Chat and calls need your internet banking link.'
            : me.verified
              ? 'Your link is signed in, so our assistant knows who you are.'
              : "Your link isn't signed in, so our assistant will check who you are before it helps."}
        </T>
        <Divider />
        <Button title={session.mode === 'sample' ? 'Leave sample mode' : 'Forget this device'} kind="danger" onPress={forget} />
      </Card>
      <Card style={{ gap: 8 }}>
        <T variant="label">About</T>
        <T>Nationwide mobile banking (demo)</T>
        <T variant="small">Sample data only. Chat and calls reach the same assistants as internet banking: ARIA, and the Money Hub, card dispute and mortgage specialists.</T>
        <T variant="small">Your link is kept in this phone's secure storage. Conversation codes are kept in memory only.</T>
      </Card>
    </Screen>
  );
}
