// One transaction: who, how much, when, its category (which the customer can change), the balance after, its
// reference and where it happened; and the assistant, about this payment (CONTRACT.md section 8).
import React, { useEffect, useMemo, useState } from 'react';
import { Modal, Pressable, ScrollView, Text, View } from 'react-native';
import { useNavigation, useRoute } from '@react-navigation/native';
import { useApp } from '../../../app/AppContext';
import { gbp, longDay, signed } from '../../../core/format/money';
import { useTheme } from '../../../core/theme/theme';
import { Button, Card, Divider, Loading, MerchantTile, Pill, Problem, Screen, T } from '../../../core/ui/kit';
import { useAsync } from '../../../core/util/useAsync';
import { useScreenContext } from '../../assistant/presentation/useScreenContext';
import type { CardPayment } from '../../cards/domain/cards';
import { matchCardPayment } from '../domain/cardPayment';
import { lookupPlace } from '../domain/places';
import { askDraft, categoryChoices, Choice, findTransaction, isMoneyIn, Transaction } from '../domain/transactions';
import { PlaceMap } from './PlaceMap';

export function TransactionDetailScreen() {
  const { container } = useApp();
  const navigation = useNavigation<any>();
  const route = useRoute<any>();
  const given: Transaction | undefined = route.params?.transaction;
  const wantedId: string | undefined = route.params?.transactionId;
  const [transaction, setTransaction] = useState<Transaction | null>(given || null);
  const [problem, setProblem] = useState('');

  // Opened by reference (a push): it must be one of the customer's own, or the topic's fallback (Money Hub, Transactions).
  useEffect(() => {
    if (given || !wantedId) return;
    let alive = true;
    findTransaction(container.transactions, wantedId)
      .then((found) => {
        if (!alive) return;
        if (found) setTransaction(found);
        else {
          container.assistant.retarget('MoneyHub');
          navigation.replace('Tabs', { screen: 'MoneyHub', params: { view: 'transactions', nonce: Date.now() } });
        }
      })
      .catch((e) => alive && setProblem(e instanceof Error ? e.message : 'Something went wrong. Try again.'));
    return () => {
      alive = false;
    };
  }, [container, given, wantedId, navigation]);

  const cards = useAsync(() => container.cards.cards(), [container]);
  const hub = useAsync(() => container.moneyHub.hub(), [container]);
  const payment: CardPayment | null = useMemo(() => (transaction && cards.data ? matchCardPayment(transaction, cards.data) : null), [transaction, cards.data]);
  const place = useMemo(() => lookupPlace(container.places.places(), transaction?.merchant || ''), [container, transaction]);
  const [choosing, setChoosing] = useState(false);

  useScreenContext(
    transaction
      ? {
          page: 'money_hub',
          view: 'transactions',
          label: `Payment to ${transaction.merchantName}`,
          launcher: 'Ask about this payment',
          draft: askDraft(transaction),
          screen: 'TransactionDetail',
        }
      : null,
  );

  if (problem) return <Screen><Problem words={problem} /></Screen>;
  if (!transaction) return <Loading words="Finding that payment…" />;
  const moneyIn = isMoneyIn(transaction);

  const recategorise = async (choice: Choice) => {
    setChoosing(false);
    try {
      setTransaction(await container.transactions.recategorise(transaction.transactionId, choice.category));
    } catch (e) {
      setProblem(e instanceof Error ? e.message : 'That category could not be saved.');
    }
  };

  return (
    <Screen>
      <Card style={{ alignItems: 'center', gap: 8, paddingVertical: 24 }}>
        <MerchantTile name={transaction.merchantName} size={64} />
        <T variant="heading" style={{ textAlign: 'center' }}>
          {transaction.merchantName}
        </T>
        <Text style={{ fontSize: 34, fontWeight: '800' }} accessibilityLabel={`${moneyIn ? 'Money in' : 'Money out'} ${gbp(Math.abs(transaction.amount))}`}>
          <AmountText amount={transaction.amount} moneyIn={moneyIn} />
        </Text>
        <T variant="small">{longDay(transaction.date)}</T>
        <Pill text={transaction.categoryWords} tone={moneyIn ? 'in' : 'brand'} />
      </Card>

      <View style={{ flexDirection: 'row', gap: 10 }}>
        <Button style={{ flex: 1 }} title="Ask about this payment" onPress={() => container.assistant.open(askDraft(transaction))} />
        {payment ? (
          <Button
            style={{ flex: 1 }}
            kind="secondary"
            title="Dispute this payment"
            onPress={() => {
              navigation.navigate('Tabs', { screen: 'Cards', params: { paymentId: payment.id, nonce: Date.now() } });
              setTimeout(() => container.assistant.open(), 400);
            }}
          />
        ) : null}
      </View>

      <Card style={{ gap: 12 }}>
        <Detail label="Category" value={transaction.categoryWords + (transaction.recategorised ? ' (changed by you)' : '')} action={hub.data ? 'Change category' : undefined} onAction={() => setChoosing(true)} />
        <Divider />
        <Detail label="Balance after" value={gbp(transaction.balanceAfter)} />
        <Divider />
        <Detail label="Merchant on your statement" value={transaction.merchant} />
        <Divider />
        <Detail label="Reference" value={transaction.transactionId} />
        {payment ? (
          <>
            <Divider />
            <Detail label="Paid with" value={`Debit card ending ${payment.ending}`} />
          </>
        ) : null}
      </Card>

      <Card style={{ gap: 10 }}>
        <T variant="heading">Where</T>
        <PlaceMap place={place} />
        {place.kind === 'place' ? <T variant="tiny">Places in this demo are made up: the sample data has no locations.</T> : null}
      </Card>

      <Modal visible={choosing} transparent animationType="fade" onRequestClose={() => setChoosing(false)}>
        <ChoiceSheet choices={hub.data ? categoryChoices(transaction, hub.data.choices) : []} current={transaction.category} onPick={recategorise} onClose={() => setChoosing(false)} />
      </Modal>
    </Screen>
  );
}

function AmountText({ amount, moneyIn }: { amount: number; moneyIn: boolean }) {
  const { c } = useTheme();
  return <Text style={{ color: moneyIn ? c.moneyIn : c.ink, fontVariant: ['tabular-nums'] }}>{signed(amount, moneyIn)}</Text>;
}

function Detail({ label, value, action, onAction }: { label: string; value: string; action?: string; onAction?: () => void }) {
  const { c } = useTheme();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
      <View style={{ flex: 1 }}>
        <T variant="tiny">{label}</T>
        <T style={{ fontWeight: '600' }} numberOfLines={2}>
          {value}
        </T>
      </View>
      {action ? (
        <Pressable accessibilityRole="button" onPress={onAction} hitSlop={8}>
          <Text style={{ color: c.brand2, fontWeight: '700' }}>{action}</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

function ChoiceSheet({ choices, current, onPick, onClose }: { choices: Choice[]; current: string; onPick: (c: Choice) => void; onClose: () => void }) {
  const { c, radius } = useTheme();
  return (
    <Pressable style={{ flex: 1, backgroundColor: '#0008', justifyContent: 'flex-end' }} onPress={onClose} accessibilityLabel="Close">
      <Pressable style={{ backgroundColor: c.card, borderTopLeftRadius: radius + 8, borderTopRightRadius: radius + 8, maxHeight: '70%', padding: 16 }}>
        <T variant="heading" style={{ marginBottom: 8 }}>
          Change category
        </T>
        <ScrollView>
          {choices.map((choice) => (
            <Pressable
              key={choice.category}
              accessibilityRole="button"
              accessibilityState={{ selected: choice.category === current }}
              onPress={() => onPick(choice)}
              style={{ paddingVertical: 14, flexDirection: 'row', justifyContent: 'space-between', borderBottomWidth: 1, borderBottomColor: c.line }}>
              <Text style={{ color: c.ink, fontSize: 16 }}>{choice.words}</Text>
              {choice.category === current ? <Text style={{ color: c.moneyIn, fontWeight: '800' }}>✓</Text> : null}
            </Pressable>
          ))}
        </ScrollView>
      </Pressable>
    </Pressable>
  );
}
