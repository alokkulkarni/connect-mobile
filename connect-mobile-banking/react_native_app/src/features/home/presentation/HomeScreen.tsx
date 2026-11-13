// Home: a greeting, the customer's money at a glance, their accounts, shortcuts, and the latest payments.
import React, { useCallback } from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { useApp, useRefreshOnActivity } from '../../../app/AppContext';
import { day, gbp } from '../../../core/format/money';
import { useTheme } from '../../../core/theme/theme';
import { Card, PaymentRow, Problem, Screen, SectionHead, T } from '../../../core/ui/kit';
import { useAsync } from '../../../core/util/useAsync';
import { totalBalance } from '../../accounts/domain/accounts';
import { AccountCard } from '../../accounts/presentation/AccountCard';
import { useScreenContext } from '../../assistant/presentation/useScreenContext';
import { greeting } from '../domain/home';

const SHORTCUTS = [
  { label: 'Money Hub', glyph: '📊', go: 'MoneyHub' },
  { label: 'Cards', glyph: '💳', go: 'Cards' },
  { label: 'Mortgages', glyph: '🏠', go: 'Mortgages' },
  { label: 'Alerts', glyph: '🔔', go: 'Notifications' },
] as const;

export function HomeScreen() {
  const { container, reloadMe } = useApp();
  const { c, radius } = useTheme();
  const navigation = useNavigation<any>();
  const { data: me, error, loading, reload } = useAsync(() => container.home.home(), [container]);
  const refresh = useCallback(() => {
    reload();
    reloadMe();
  }, [reload, reloadMe]);
  useRefreshOnActivity(reload);
  useScreenContext({ page: 'home', label: 'Home', launcher: 'Ask us anything', screen: 'Home' });

  const go = (to: string) => (to === 'MoneyHub' || to === 'Cards' ? navigation.navigate('Tabs', { screen: to }) : navigation.navigate(to));

  return (
    <Screen refreshing={loading && !!me} onRefresh={refresh}>
      {error ? <Problem words={error} onRetry={reload} /> : null}
      <View style={{ backgroundColor: c.brand, borderRadius: radius + 4, padding: 20, gap: 6 }}>
        <Text style={{ color: '#ffffffcc', fontSize: 14 }}>{greeting(me?.firstName || '', new Date().getHours())}</Text>
        <Text style={{ color: '#ffffff99', fontSize: 12, marginTop: 8 }}>Total in your accounts</Text>
        <Text style={{ color: '#fff', fontSize: 34, fontWeight: '800', fontVariant: ['tabular-nums'] }}>{me ? gbp(totalBalance(me.accounts)) : '—'}</Text>
        <Text style={{ color: '#ffffff99', fontSize: 12 }}>{me?.asOf ? `Balances up to ${day(me.asOf)}` : ' '}</Text>
        {me && !me.verified && container.session.mode === 'link' ? (
          <Text style={{ color: '#ffd9a0', fontSize: 12, marginTop: 6 }}>
            This link isn't signed in, so our assistant will check who you are before it helps.
          </Text>
        ) : null}
      </View>

      <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
        {SHORTCUTS.map((s) => (
          <Pressable key={s.label} accessibilityRole="button" accessibilityLabel={s.label} onPress={() => go(s.go)} style={{ alignItems: 'center', gap: 6, width: '23%' }}>
            <View style={{ width: 56, height: 56, borderRadius: 18, backgroundColor: c.card, alignItems: 'center', justifyContent: 'center', borderWidth: 1, borderColor: c.line }}>
              <Text style={{ fontSize: 24 }}>{s.glyph}</Text>
            </View>
            <Text style={{ color: c.ink, fontSize: 12, fontWeight: '600' }}>{s.label}</Text>
          </Pressable>
        ))}
      </View>

      <View>
        <SectionHead title="Your accounts" action="See all" onAction={() => navigation.navigate('Tabs', { screen: 'Accounts' })} />
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 12, paddingVertical: 4, paddingRight: 8 }}>
          {(me?.accounts || []).map((a) => (
            <AccountCard
              key={a.id}
              compact
              account={a}
              onPress={() => (a.kind === 'mortgage' ? navigation.navigate('Mortgages') : navigation.navigate('Tabs', { screen: 'Accounts', params: { account: a.id } }))}
            />
          ))}
        </ScrollView>
      </View>

      <Card>
        <SectionHead title="Latest payments" action="All transactions" onAction={() => navigation.navigate('Transactions')} />
        {(me?.recent || []).map((t, i) => (
          <PaymentRow key={`${t.date}-${i}`} name={t.merchantName} meta={`${t.category} · ${day(t.date)}`} amount={t.amount} moneyIn={t.in} onPress={() => navigation.navigate('Transactions')} />
        ))}
        {me && !me.recent.length ? <T variant="small">Nothing has moved in or out yet.</T> : null}
      </Card>
    </Screen>
  );
}
