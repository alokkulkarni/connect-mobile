// Help: how to reach us, the customer's disputes at a glance, and common questions. The assistant helps from here.
import React, { useState } from 'react';
import { LayoutAnimation, Pressable, Text, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { useApp } from '../../../app/AppContext';
import { useTheme } from '../../../core/theme/theme';
import { Button, Card, Divider, Screen, SectionHead, T } from '../../../core/ui/kit';
import { useAsync } from '../../../core/util/useAsync';
import { useScreenContext } from '../../assistant/presentation/useScreenContext';
import { DisputeRow } from '../../cards/presentation/CardsScreen';
import { FAQS } from '../domain/faqs';

export function HelpScreen() {
  const { container } = useApp();
  const { c } = useTheme();
  const navigation = useNavigation<any>();
  const [open, setOpen] = useState<number | null>(null);
  const disputes = useAsync(() => container.disputes.list().catch(() => []), [container]);
  useScreenContext({ page: 'help', label: 'Help', launcher: 'Ask us anything', screen: 'Help' });

  const go = (screen: string) => (screen === 'MoneyHub' || screen === 'Cards' ? navigation.navigate('Tabs', { screen }) : navigation.navigate(screen));

  return (
    <Screen>
      <Card style={{ gap: 10 }}>
        <T variant="heading">Ask us anything</T>
        <T>
          Chat or call with our assistant from the button at the bottom of any screen. It knows which screen you're on, so it can help with that straight away: your Money Hub, a
          mortgage application or a card payment.
        </T>
        <Button title="Talk to us" onPress={() => container.assistant.open()} />
      </Card>

      {disputes.data && disputes.data.length ? (
        <View>
          <SectionHead title="Your disputes" action="See them in Cards" onAction={() => navigation.navigate('Tabs', { screen: 'Cards', params: { tab: 'disputes', nonce: Date.now() } })} />
          <View style={{ gap: 10 }}>
            {disputes.data.slice(0, 4).map((d) => (
              <DisputeRow key={d.disputeId} dispute={d} />
            ))}
          </View>
        </View>
      ) : null}

      <Card>
        <T variant="heading" style={{ marginBottom: 4 }}>
          Common questions
        </T>
        {FAQS.map((faq, i) => (
          <View key={faq.q}>
            {i ? <Divider /> : null}
            <Pressable
              accessibilityRole="button"
              accessibilityState={{ expanded: open === i }}
              onPress={() => {
                LayoutAnimation.easeInEaseOut();
                setOpen(open === i ? null : i);
              }}
              style={{ paddingVertical: 14, flexDirection: 'row', gap: 10, alignItems: 'center' }}>
              <Text style={{ color: c.ink, fontWeight: '600', flex: 1, fontSize: 15 }}>{faq.q}</Text>
              <Text style={{ color: c.muted, fontSize: 18 }}>{open === i ? '−' : '+'}</Text>
            </Pressable>
            {open === i ? (
              <View style={{ paddingBottom: 14, gap: 10 }}>
                <T>{faq.a}</T>
                {faq.go ? (
                  <Pressable accessibilityRole="link" onPress={() => go(faq.go!.screen)}>
                    <Text style={{ color: c.brand2, fontWeight: '700' }}>{faq.go.label} ›</Text>
                  </Pressable>
                ) : null}
              </View>
            ) : null}
          </View>
        ))}
      </Card>
    </Screen>
  );
}
