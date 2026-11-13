// Accounts: every account, and the chosen account's latest movements. The saver shows only money moved to and from
// the current account: a savings account has no merchant payments (bankapp/home.py account_history).
import React, { useState } from 'react';
import { useNavigation, useRoute } from '@react-navigation/native';
import { useApp, useRefreshOnActivity } from '../../../app/AppContext';
import { day } from '../../../core/format/money';
import { Button, Card, Loading, PaymentRow, Problem, Screen, SectionHead, T } from '../../../core/ui/kit';
import { useAsync } from '../../../core/util/useAsync';
import { useScreenContext } from '../../assistant/presentation/useScreenContext';
import { SAVINGS_NOTE } from '../domain/accounts';
import { AccountCard } from './AccountCard';

export function AccountsScreen() {
  const { container } = useApp();
  const navigation = useNavigation<any>();
  const route = useRoute<any>();
  const [which, setWhich] = useState<'current' | 'savings'>(route.params?.account === 'savings' ? 'savings' : 'current');
  React.useEffect(() => {
    if (route.params?.account === 'savings' || route.params?.account === 'current') setWhich(route.params.account);
  }, [route.params?.account]);
  const { data, error, loading, reload } = useAsync(() => container.accounts.accounts(which), [container, which]);
  useRefreshOnActivity(reload);
  const chosen = data?.accounts.find((a) => a.id === data.selected);
  useScreenContext({ page: 'accounts', label: chosen ? chosen.name : 'Accounts', launcher: 'Ask us anything', screen: 'Accounts' });

  if (!data && loading) return <Loading />;
  return (
    <Screen refreshing={loading} onRefresh={reload}>
      {error ? <Problem words={error} onRetry={reload} /> : null}
      {(data?.accounts || []).map((a) => (
        <AccountCard
          key={a.id}
          account={a}
          selected={a.id === data?.selected}
          onPress={() => (a.kind === 'mortgage' ? navigation.navigate('Mortgages') : setWhich(a.id as 'current' | 'savings'))}
        />
      ))}
      {data ? (
        <Card>
          <SectionHead title={chosen ? `${chosen.name}, ending ${chosen.ending}` : 'Current account'} />
          <T variant="small" style={{ marginBottom: 6 }}>
            up to {day(data.asOf)}
          </T>
          {data.recent.length ? (
            data.recent.map((t, i) => (
              <PaymentRow
                key={`${t.date}-${i}`}
                name={t.merchantName}
                meta={`${t.category} · ${day(t.date)}`}
                amount={t.amount}
                moneyIn={t.in}
                onPress={data.selected === 'current' ? () => navigation.navigate('Transactions') : undefined}
              />
            ))
          ) : (
            <T variant="small">Nothing has moved in or out yet.</T>
          )}
          {data.selected === 'savings' ? (
            <T variant="small" style={{ marginTop: 8 }}>
              {SAVINGS_NOTE}
            </T>
          ) : (
            <Button title="See all transactions" kind="secondary" onPress={() => navigation.navigate('Transactions')} style={{ marginTop: 10 }} />
          )}
        </Card>
      ) : null}
    </Screen>
  );
}
