// Cards: the customer's cards, their card payments and their disputes (web/pages/cards.js).
//   Payments       the card dispute service's own list. "Dispute" chooses a payment and opens the assistant: the
//                  conversation goes to ARIA and on to the card dispute assistant with that payment (card_dispute).
//   Your disputes  every dispute and where it's up to. A complete draft can be submitted; an unfinished one goes back
//                  to the dispute assistant with its payment.
import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { ScrollView, Text, View } from 'react-native';
import { useIsFocused, useRoute } from '@react-navigation/native';
import { useApp, useRefreshOnActivity } from '../../../app/AppContext';
import { TIMINGS } from '../../../core/config/appConfig';
import { day, gbp, tidyMerchant } from '../../../core/format/money';
import { useTheme } from '../../../core/theme/theme';
import { Button, Card, Loading, PaymentRow, Pill, Problem, Screen, Segmented, T } from '../../../core/ui/kit';
import { useAsync } from '../../../core/util/useAsync';
import { useScreenContext } from '../../assistant/presentation/useScreenContext';
import { BankCard, CardPayment, cardLabel, Dispute, findPayment } from '../domain/cards';

type Tab = 'payments' | 'disputes';

export function CardsScreen() {
  const { container } = useApp();
  const route = useRoute<any>();
  const focused = useIsFocused();
  const view = useAsync(() => container.cards.cards(), [container]);
  const [tab, setTab] = useState<Tab>('payments');
  const [filter, setFilter] = useState('all');
  const [picked, setPicked] = useState<CardPayment | null | undefined>(undefined); // undefined: follow the route
  const [disputes, setDisputes] = useState<Dispute[] | null>(null);
  const [problem, setProblem] = useState('');

  // A payment or tab named by a push or by "Dispute this payment": only one of the customer's own payments. Worked
  // out in the same render the data arrives, so the first context published already names it.
  const wantedPayment: string | undefined = route.params?.paymentId;
  const wantedTab: Tab | undefined = route.params?.tab;
  const nonce = route.params?.nonce;
  const routePayment = useMemo(() => (view.data && wantedPayment ? findPayment(view.data, wantedPayment) : null), [view.data, wantedPayment]);
  useEffect(() => {
    setPicked(undefined);
    if (wantedTab) setTab(wantedTab);
    else if (wantedPayment) setTab('payments');
  }, [wantedTab, wantedPayment, nonce]);
  const chosen = picked !== undefined ? picked : routePayment;
  const setChosen = setPicked;

  const loadDisputes = useCallback(async () => {
    try {
      setDisputes(await container.disputes.list());
    } catch {
      setDisputes((d) => d || []); // disputes aren't set up: the tab still works
    }
  }, [container]);
  useEffect(() => {
    loadDisputes();
  }, [loadDisputes]);
  // The list follows a dispute being filled in, while the tab is showing.
  useEffect(() => {
    if (!focused || tab !== 'disputes') return;
    const timer = setInterval(loadDisputes, TIMINGS.disputesListMs);
    return () => clearInterval(timer);
  }, [focused, tab, loadDisputes]);
  const reloadCards = view.reload;
  const refresh = useCallback(() => {
    reloadCards();
    loadDisputes();
  }, [reloadCards, loadDisputes]);
  useRefreshOnActivity(refresh);

  useScreenContext(
    chosen
      ? { page: 'card_dispute', paymentId: chosen.id, label: `Disputing ${tidyMerchant(chosen.merchant)} ${gbp(chosen.amount)}`, launcher: 'Help with a payment', screen: 'Cards' }
      : view.data || wantedPayment === undefined
        ? { page: 'cards', label: tab === 'disputes' ? 'Cards · Your disputes' : 'Cards', launcher: 'Help with a payment', screen: 'Cards' }
        : null,
  );

  const payments = useMemo(() => (view.data?.payments || []).filter((p) => filter === 'all' || p.card === filter), [view.data, filter]);
  const openCount = (disputes || []).filter((d) => d.open).length;

  if (!view.data && view.loading) return <Loading />;

  const dispute = (p: CardPayment) => {
    setChosen(p);
    setTimeout(() => container.assistant.open(), 50);
  };

  return (
    <Screen refreshing={view.loading} onRefresh={refresh}>
      {view.error ? <Problem words={view.error} onRetry={view.reload} /> : null}
      {problem ? <Problem words={problem} /> : null}
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 12 }}>
        {(view.data?.cards || []).map((c) => (
          <CardFace key={c.ending} card={c} />
        ))}
      </ScrollView>

      <Segmented<Tab>
        options={[
          ['payments', 'Payments'],
          ['disputes', openCount ? `Your disputes (${openCount})` : 'Your disputes'],
        ]}
        value={tab}
        onChange={setTab}
      />

      {tab === 'payments' ? (
        <Card>
          {chosen ? (
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 8 }}>
              <View style={{ flex: 1 }}>
                <Pill text={`Disputing ${tidyMerchant(chosen.merchant)} ${gbp(chosen.amount)}`} tone="warn" />
              </View>
              <Button title="Not this one" kind="ghost" onPress={() => setChosen(null)} />
            </View>
          ) : null}
          <Segmented
            options={[['all', 'All cards'] as [string, string], ...(view.data?.cards || []).map((c) => [c.type, `${c.type === 'debit' ? 'Debit' : 'Credit'} ••${c.ending}`] as [string, string])]}
            value={filter}
            onChange={setFilter}
          />
          <View style={{ height: 8 }} />
          {payments.map((p) => (
            <View key={p.id} style={chosen?.id === p.id ? { backgroundColor: '#e08a1e1a', borderRadius: 12, paddingHorizontal: 6 } : undefined}>
              <PaymentRow
                name={tidyMerchant(p.merchant)}
                meta={`${cardLabel(p.card, p.ending)} · ${day(p.date)}`}
                amount={-p.amount}
                moneyIn={false}
                right={<Button title="Dispute" kind="ghost" onPress={() => dispute(p)} style={{ paddingVertical: 4, paddingHorizontal: 10 }} />}
              />
            </View>
          ))}
        </Card>
      ) : (
        <DisputesList
          disputes={disputes}
          onSubmit={async (d) => {
            try {
              await container.disputes.submit(d.disputeId);
              setProblem('');
              loadDisputes();
            } catch (e) {
              setProblem(e instanceof Error ? e.message : 'That dispute could not be sent.');
            }
          }}
          onFinish={(d) => {
            const payment = view.data?.payments.find((p) => p.id === d.transactionId);
            if (payment) {
              setTab('payments');
              dispute(payment);
            }
          }}
        />
      )}
    </Screen>
  );
}

function CardFace({ card }: { card: BankCard }) {
  const { c } = useTheme();
  const credit = card.type === 'credit';
  return (
    <View
      accessible
      accessibilityLabel={`${card.name} ending ${card.ending}`}
      style={{ width: 280, height: 170, borderRadius: 18, padding: 18, justifyContent: 'space-between', backgroundColor: credit ? c.creditCard : c.brand, overflow: 'hidden' }}>
      <View style={{ position: 'absolute', right: -40, top: -40, width: 160, height: 160, borderRadius: 80, backgroundColor: '#ffffff14' }} />
      <View style={{ position: 'absolute', right: 30, bottom: -60, width: 140, height: 140, borderRadius: 70, backgroundColor: '#ffffff0d' }} />
      <Text style={{ color: '#fff', fontWeight: '800', fontSize: 16, letterSpacing: 0.5 }}>Nationwide</Text>
      <View style={{ width: 40, height: 28, borderRadius: 6, backgroundColor: '#e8c76a' }} />
      <View>
        <Text style={{ color: '#ffffffcc', fontSize: 12 }}>{card.name}</Text>
        <Text style={{ color: '#fff', fontSize: 18, letterSpacing: 2, fontVariant: ['tabular-nums'] }}>•••• •••• •••• {card.ending}</Text>
      </View>
    </View>
  );
}

function DisputesList({ disputes, onSubmit, onFinish }: { disputes: Dispute[] | null; onSubmit: (d: Dispute) => void; onFinish: (d: Dispute) => void }) {
  if (disputes === null) return <Loading words="Loading your disputes…" />;
  if (!disputes.length) {
    return (
      <Card>
        <T>You have no disputes. Choose Dispute on a payment you don't recognise.</T>
      </Card>
    );
  }
  return (
    <View style={{ gap: 12 }}>
      {disputes.map((d) => (
        <DisputeRow key={d.disputeId} dispute={d} onSubmit={onSubmit} onFinish={onFinish} />
      ))}
    </View>
  );
}

export function DisputeRow({ dispute, onSubmit, onFinish }: { dispute: Dispute; onSubmit?: (d: Dispute) => void; onFinish?: (d: Dispute) => void }) {
  return (
    <Card style={{ gap: 8 }}>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start', gap: 8 }}>
        <View style={{ flex: 1 }}>
          <T style={{ fontWeight: '700' }}>{tidyMerchant(dispute.merchant)}</T>
          <T variant="small">
            {gbp(dispute.amount)} · {day(dispute.transactionDate)} · {cardLabel(dispute.cardType, dispute.cardLastFour)}
          </T>
        </View>
        <Pill text={dispute.statusWords} tone={dispute.open ? 'warn' : 'in'} />
      </View>
      <T variant="tiny">Reference {dispute.disputeId}</T>
      {dispute.missing.length && dispute.open ? <T variant="small">Still needed: {dispute.missing.join(', ')}</T> : null}
      <View style={{ flexDirection: 'row', gap: 8 }}>
        {dispute.canSubmit && onSubmit ? <Button style={{ flex: 1 }} title="Submit" onPress={() => onSubmit(dispute)} /> : null}
        {dispute.open && !dispute.canSubmit && onFinish ? <Button style={{ flex: 1 }} kind="secondary" title="Finish with the assistant" onPress={() => onFinish(dispute)} /> : null}
      </View>
    </Card>
  );
}
