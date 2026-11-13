// Every current account transaction, newest first, 25 at a time, searchable by merchant and filtered by money in or
// out (the Money Hub's own list). Each opens its details.
import React, { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, FlatList, TextInput, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { useApp, useRefreshOnActivity } from '../../../app/AppContext';
import { day } from '../../../core/format/money';
import { useTheme } from '../../../core/theme/theme';
import { Button, Divider, LAUNCHER_ROOM, PaymentRow, Problem, Segmented, T } from '../../../core/ui/kit';
import { useScreenContext } from '../../assistant/presentation/useScreenContext';
import { isMoneyIn, Transaction } from '../domain/transactions';

type Direction = 'all' | 'in' | 'out';

export function TransactionsList({ embedded = false }: { embedded?: boolean }) {
  const { container } = useApp();
  const { c, radius } = useTheme();
  const navigation = useNavigation<any>();
  const [rows, setRows] = useState<Transaction[]>([]);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [direction, setDirection] = useState<Direction>('all');
  const [search, setSearch] = useState('');
  const [query, setQuery] = useState('');

  useEffect(() => {
    const t = setTimeout(() => setQuery(search.trim()), 350);
    return () => clearTimeout(t);
  }, [search]);

  const load = useCallback(
    async (next: number) => {
      setLoading(true);
      try {
        const found = await container.transactions.list({ page: next, direction: direction === 'all' ? '' : direction, merchant: query });
        setRows((before) => (next === 1 ? found.transactions : [...before, ...found.transactions]));
        setPage(found.page);
        setHasMore(found.hasMore);
        setError('');
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Something went wrong. Try again.');
      } finally {
        setLoading(false);
      }
    },
    [container, direction, query],
  );

  useEffect(() => {
    load(1);
  }, [load]);
  const reload = useCallback(() => load(1), [load]);
  useRefreshOnActivity(reload);

  const header = (
    <View style={{ gap: 12, paddingBottom: 8 }}>
      <TextInput
        accessibilityLabel="Search by merchant"
        placeholder="Search by merchant"
        placeholderTextColor={c.muted}
        value={search}
        onChangeText={setSearch}
        style={{ backgroundColor: c.card, borderRadius: radius - 4, paddingHorizontal: 14, paddingVertical: 12, color: c.ink, borderWidth: 1, borderColor: c.line }}
      />
      <Segmented<Direction>
        options={[
          ['all', 'All'],
          ['in', 'Money in'],
          ['out', 'Money out'],
        ]}
        value={direction}
        onChange={setDirection}
      />
      {error ? <Problem words={error} onRetry={reload} /> : null}
    </View>
  );

  const renderRow = (t: Transaction) => (
    <PaymentRow
      key={t.transactionId}
      name={t.merchantName}
      meta={`${t.categoryWords} · ${day(t.date)}`}
      amount={t.amount}
      moneyIn={isMoneyIn(t)}
      onPress={() => navigation.navigate('TransactionDetail', { transaction: t })}
    />
  );

  const footer = (
    <View style={{ paddingVertical: 12 }}>
      {loading ? <ActivityIndicator color={c.brand2} /> : hasMore ? <Button title="Show more" kind="secondary" onPress={() => load(page + 1)} /> : rows.length ? <T variant="small" style={{ textAlign: 'center' }}>That's everything.</T> : <T variant="small">No transactions match.</T>}
    </View>
  );

  if (embedded) {
    return (
      <View>
        {header}
        {rows.map(renderRow)}
        {footer}
      </View>
    );
  }
  return (
    <FlatList
      style={{ flex: 1, backgroundColor: c.bg }}
      contentContainerStyle={{ padding: 16, paddingBottom: LAUNCHER_ROOM + 24 }}
      data={rows}
      keyExtractor={(t) => t.transactionId}
      ListHeaderComponent={header}
      ItemSeparatorComponent={Divider}
      renderItem={({ item }) => renderRow(item)}
      ListFooterComponent={footer}
      keyboardShouldPersistTaps="handled"
    />
  );
}

export function TransactionsScreen() {
  useScreenContext({ page: 'money_hub', view: 'transactions', label: 'Transactions', launcher: 'Ask about your money', screen: 'Transactions' });
  return <TransactionsList />;
}
