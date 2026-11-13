// An account as a card: its name and ending, then its balance (or, for a mortgage, the monthly payment).
import React from 'react';
import { Text, View } from 'react-native';
import { gbp } from '../../../core/format/money';
import { useTheme } from '../../../core/theme/theme';
import { Card } from '../../../core/ui/kit';
import type { Account } from '../domain/accounts';

export function AccountCard({ account, selected, onPress, compact }: { account: Account; selected?: boolean; onPress?: () => void; compact?: boolean }) {
  const { c } = useTheme();
  const accent = account.kind === 'savings' ? c.savings : account.kind === 'mortgage' ? c.flexible : c.essential;
  const value = account.kind === 'mortgage' ? account.monthly ?? 0 : account.balance ?? 0;
  return (
    <Card
      onPress={onPress}
      label={`${account.name}, ending ${account.ending}, ${account.kind === 'mortgage' ? 'monthly payment' : 'balance'} ${gbp(value)}`}
      style={[{ gap: 6, borderLeftWidth: 4, borderLeftColor: accent }, selected && { borderWidth: 2, borderColor: c.brand2, borderLeftWidth: 4 }, compact && { width: 220 }]}>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
        <Text style={{ color: c.ink, fontWeight: '700', fontSize: 15 }} numberOfLines={1}>
          {account.name}
        </Text>
        <Text style={{ color: c.muted, fontSize: 12 }}>••{account.ending}</Text>
      </View>
      <Text style={{ color: c.muted, fontSize: 12 }}>{account.kind === 'mortgage' ? 'Monthly payment' : 'Balance'}</Text>
      <Text style={{ color: c.ink, fontWeight: '800', fontSize: 24, fontVariant: ['tabular-nums'] }}>{gbp(value)}</Text>
      {account.note && !compact ? <Text style={{ color: c.muted, fontSize: 12 }}>{account.note}</Text> : null}
    </Card>
  );
}
