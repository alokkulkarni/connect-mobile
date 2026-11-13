// Notifications: money alerts built from the customer's own data. "Send notification" posts a real local
// notification 5 seconds later (lock the phone or leave the app to see it arrive); tapping it, or tapping the row,
// goes through the same handler as a real push and starts a chat or call there (CONTRACT.md section 7).
import React, { useState } from 'react';
import { Pressable, Text, View } from 'react-native';
import { useApp } from '../../../app/AppContext';
import { localNotifications } from '../../../app/push';
import { useTheme } from '../../../core/theme/theme';
import { Button, Card, Loading, Pill, Problem, Screen, T } from '../../../core/ui/kit';
import { useAsync } from '../../../core/util/useAsync';
import { useScreenContext } from '../../assistant/presentation/useScreenContext';
import { REFUSED_WORDS, SEND_DELAY_MS, SENDING_WORDS } from '../domain/ports';
import { buildSamples, SampleNotification } from '../domain/samples';
import { handleNotificationTap } from './intents';

const GLYPHS: Record<string, string> = { unusual_payment: '⚠️', low_balance: '📉', salary_in: '💷', savings_goal: '🎯', large_payment: '💸' };

export function NotificationsScreen() {
  const { container } = useApp();
  const { c } = useTheme();
  const [notes, setNotes] = useState<Record<string, string>>({});
  useScreenContext({ page: 'home', label: 'Notifications', launcher: 'Ask us anything', screen: 'Notifications' });

  const { data: samples, error, loading, reload } = useAsync(async () => {
    const [cards, hub, page] = await Promise.all([container.cards.cards(), container.moneyHub.hub(), container.transactions.list({ page: 1 })]);
    return buildSamples({ cards, hub, transactions: page.transactions });
  }, [container]);

  const send = async (sample: SampleNotification) => {
    if (!(await localNotifications.ensurePermission())) {
      setNotes((n) => ({ ...n, [sample.id]: REFUSED_WORDS }));
      return;
    }
    try {
      await localNotifications.schedule(sample, SEND_DELAY_MS);
      setNotes((n) => ({ ...n, [sample.id]: SENDING_WORDS }));
    } catch {
      setNotes((n) => ({ ...n, [sample.id]: "The notification couldn't be sent on this device." }));
    }
  };

  if (!samples && loading) return <Loading />;
  return (
    <Screen refreshing={loading} onRefresh={reload}>
      <Card style={{ gap: 6 }}>
        <T variant="heading">Money alerts</T>
        <T variant="small">
          Each alert opens the screen it's about and starts a chat or call there, so our assistant already knows what it's about. Tap one to try it now, or send it as a real
          notification.
        </T>
      </Card>
      {error ? <Problem words={error} onRetry={reload} /> : null}
      {(samples || []).map((sample) => (
        <Card key={sample.id} style={{ gap: 10 }}>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={`${sample.title}. ${sample.body}`}
            onPress={() => handleNotificationTap(sample.data)}
            style={({ pressed }) => ({ flexDirection: 'row', gap: 12, opacity: pressed ? 0.7 : 1 })}>
            <View style={{ width: 44, height: 44, borderRadius: 14, backgroundColor: c.accent, alignItems: 'center', justifyContent: 'center' }}>
              <Text style={{ fontSize: 22 }}>{GLYPHS[sample.id] || '🔔'}</Text>
            </View>
            <View style={{ flex: 1, gap: 4 }}>
              <T style={{ fontWeight: '700' }}>{sample.title}</T>
              <T variant="small">{sample.body}</T>
              <Pill text={sample.data.mode === 'call' ? 'Starts a call' : 'Starts a chat'} tone={sample.data.mode === 'call' ? 'brand' : 'in'} />
            </View>
          </Pressable>
          <Button title="Send notification" kind="secondary" icon="🔔" onPress={() => send(sample)} />
          {notes[sample.id] ? (
            <Text accessibilityLiveRegion="polite" style={{ color: c.muted, fontSize: 13 }}>
              {notes[sample.id]}
            </Text>
          ) : null}
        </Card>
      ))}
    </Screen>
  );
}
