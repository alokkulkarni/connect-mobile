// Mortgages: the customer's mortgage, the products (illustrative rates), what the application involves, and the way
// in. The application form is the web app's own (in a WebView), filled in with its own assistant through Live Sync.
import React, { useMemo, useState } from 'react';
import { Text, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { useApp } from '../../../app/AppContext';
import { gbp, pounds } from '../../../core/format/money';
import { useTheme } from '../../../core/theme/theme';
import { Button, Card, Divider, Loading, Pill, Problem, Screen, Segmented, T } from '../../../core/ui/kit';
import { useAsync } from '../../../core/util/useAsync';
import { useScreenContext } from '../../assistant/presentation/useScreenContext';
import { monthlyRepayment } from '../domain/mortgages';

const STEPS = ['About you', 'Property and loan', 'Decision in Principle', 'Choose a product', 'Documents', 'Review and submit'];
const LOANS: [string, string][] = [
  ['150000', '£150k'],
  ['200000', '£200k'],
  ['300000', '£300k'],
];

export function MortgagesScreen() {
  const { container, me } = useApp();
  const { c } = useTheme();
  const navigation = useNavigation<any>();
  const { data: products, error, loading, reload } = useAsync(() => container.mortgages.products(), [container]);
  const [loan, setLoan] = useState('200000');
  const current = me.accounts.find((a) => a.kind === 'mortgage');
  useScreenContext({ page: 'mortgages', label: 'Mortgages', launcher: 'Help with a mortgage', screen: 'Mortgages' });
  const best = useMemo(() => (products || []).reduce((low, p) => (!low || p.rate < low.rate ? p : low), null as null | { id: string; rate: number }), [products]);

  if (!products && loading) return <Loading />;
  return (
    <Screen refreshing={loading} onRefresh={reload}>
      {error ? <Problem words={error} onRetry={reload} /> : null}
      {current ? (
        <Card style={{ gap: 6, borderLeftWidth: 4, borderLeftColor: c.flexible }}>
          <T variant="label">Your mortgage</T>
          <T variant="heading">Ending {current.ending}</T>
          <T>{gbp(current.monthly || 0)} a month</T>
          {current.note ? <T variant="small">{current.note}</T> : null}
        </Card>
      ) : null}

      <Card style={{ gap: 12 }}>
        <T variant="heading">Apply for a mortgage</T>
        <T variant="small">Fill it in yourself, or with our assistant: it fills in the form with you as you talk. Choosing a product is up to you.</T>
        <View style={{ gap: 6 }}>
          {STEPS.map((step, i) => (
            <View key={step} style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
              <View style={{ width: 24, height: 24, borderRadius: 12, backgroundColor: c.accent, alignItems: 'center', justifyContent: 'center' }}>
                <Text style={{ color: c.brand2, fontWeight: '800', fontSize: 12 }}>{i + 1}</Text>
              </View>
              <T>{step}</T>
            </View>
          ))}
        </View>
        <Button title="Start your application" onPress={() => navigation.navigate('Form', { kind: 'mortgage' })} />
      </Card>

      <Card style={{ gap: 10 }}>
        <T variant="heading">Our mortgages</T>
        <T variant="small">Monthly repayments for a loan over 25 years:</T>
        <Segmented options={LOANS} value={loan} onChange={setLoan} />
        {(products || []).map((p, i) => (
          <View key={p.id}>
            {i ? <Divider /> : null}
            <View style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 12, gap: 10 }}>
              <View style={{ flex: 1, gap: 2 }}>
                <View style={{ flexDirection: 'row', gap: 6, alignItems: 'center' }}>
                  <T style={{ fontWeight: '700' }}>{p.name}</T>
                  {best?.id === p.id ? <Pill text="Lowest rate" tone="in" /> : null}
                </View>
                <T variant="small">
                  Fee {pounds(p.fee)} · up to {p.maxLtv}% of the property's value
                </T>
                <T variant="small">About {gbp(monthlyRepayment(Number(loan), p.rate, 25))} a month</T>
              </View>
              <Text style={{ color: c.brand2, fontSize: 22, fontWeight: '800' }}>{p.rate.toFixed(2)}%</Text>
            </View>
          </View>
        ))}
        <T variant="tiny">Rates are examples, not offers.</T>
      </Card>
    </Screen>
  );
}
