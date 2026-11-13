// The Money Hub: money out, money in, what's expected, every transaction and savings goals. The tab is what the
// assistant is told (`view`), so it reaches the Money Hub agent knowing which tab the customer is on.
import React, { useCallback, useEffect, useState } from 'react';
import { Alert, Modal, Pressable, ScrollView, Text, TextInput, View } from 'react-native';
import { useRoute } from '@react-navigation/native';
import { useApp, useRefreshOnActivity } from '../../../app/AppContext';
import { day, gbp, monthName, pounds } from '../../../core/format/money';
import { useTheme } from '../../../core/theme/theme';
import { Button, Card, Divider, Loading, Pill, Problem, Screen, Segmented, T } from '../../../core/ui/kit';
import { useAsync } from '../../../core/util/useAsync';
import { useScreenContext } from '../../assistant/presentation/useScreenContext';
import { TransactionsList } from '../../transactions/presentation/TransactionsScreen';
import { Goal, goalProgress, HUB_VIEWS, HubView, isHubView, MoneyHub, validateGoal } from '../domain/moneyHub';
import { Legend, ShareBar, StackedBars } from './charts';

export function MoneyHubScreen() {
  const { container } = useApp();
  const route = useRoute<any>();
  const routeView: HubView | undefined = isHubView(route.params?.view) ? route.params.view : undefined;
  const nonce = route.params?.nonce;
  const [picked, setPicked] = useState<HubView | undefined>(undefined); // undefined: follow the route
  useEffect(() => setPicked(undefined), [routeView, nonce]);
  const view: HubView = picked || routeView || 'out';

  const { data: hub, error, loading, reload } = useAsync(() => container.moneyHub.hub(), [container]);
  useRefreshOnActivity(reload);
  const label = HUB_VIEWS.find(([k]) => k === view)?.[1] || 'Money out';
  useScreenContext({ page: 'money_hub', view, label: `Money Hub · ${label}`, launcher: 'Ask about your money', screen: 'MoneyHub' });

  if (!hub && loading) return <Loading />;
  return (
    <Screen refreshing={loading && !!hub} onRefresh={reload}>
      {error ? <Problem words={error} onRetry={reload} /> : null}
      {hub ? <Summary hub={hub} /> : null}
      <Segmented<HubView> options={HUB_VIEWS} value={view} onChange={setPicked} />
      {hub && view === 'out' ? <MoneyOut hub={hub} /> : null}
      {hub && view === 'in' ? <MoneyIn hub={hub} /> : null}
      {hub && view === 'expected' ? <ExpectedTab hub={hub} /> : null}
      {view === 'transactions' ? (
        <Card>
          <TransactionsList embedded />
        </Card>
      ) : null}
      {hub && view === 'goals' ? <Goals hub={hub} onChanged={reload} /> : null}
    </Screen>
  );
}

function Summary({ hub }: { hub: MoneyHub }) {
  const { c, radius } = useTheme();
  const month = hub.overview.thisMonthSoFar;
  return (
    <View style={{ backgroundColor: c.brand, borderRadius: radius + 4, padding: 20, gap: 12 }}>
      <View>
        <Text style={{ color: '#ffffffaa', fontSize: 12 }}>Current account balance</Text>
        <Text style={{ color: '#fff', fontSize: 30, fontWeight: '800', fontVariant: ['tabular-nums'] }}>{gbp(hub.overview.balance)}</Text>
        <Text style={{ color: '#ffffff88', fontSize: 12 }}>up to {day(hub.overview.asOf)}</Text>
      </View>
      <View style={{ flexDirection: 'row', gap: 12 }}>
        <Stat label={`In so far in ${monthName(month.month, true)}`} value={gbp(month.moneyIn)} />
        <Stat label={`Out so far in ${monthName(month.month, true)}`} value={gbp(month.moneyOut)} />
      </View>
    </View>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <View style={{ flex: 1, backgroundColor: '#ffffff14', borderRadius: 12, padding: 10 }}>
      <Text style={{ color: '#ffffffaa', fontSize: 11 }}>{label}</Text>
      <Text style={{ color: '#fff', fontSize: 17, fontWeight: '700' }}>{value}</Text>
    </View>
  );
}

function MoneyOut({ hub }: { hub: MoneyHub }) {
  const { c } = useTheme();
  const palette = [c.essential, c.flexible, c.savings, c.moneyIn, c.moneyOut, c.brand2];
  return (
    <>
      <Card style={{ gap: 12 }}>
        <T variant="heading">Money out by month</T>
        <StackedBars
          bars={hub.monthlySpending.map((m) => ({
            label: monthName(m.month, true),
            parts: [
              { value: m.essential, color: c.essential },
              { value: m.discretionary, color: c.flexible },
            ],
          }))}
        />
        <Legend items={[{ label: 'Essentials', color: c.essential }, { label: 'Spending you choose', color: c.flexible }]} />
        <T variant="small">
          About {hub.discretionary.discretionaryShare}% of what you spend is spending you choose: {pounds(hub.discretionary.discretionaryPerMonth)} a month on average.
        </T>
      </Card>
      <Card>
        <T variant="heading" style={{ marginBottom: 6 }}>
          Where it goes
        </T>
        {hub.overview.topSpending.map((cat, i) => (
          <ShareBar key={cat.category} label={cat.words} value={pounds(cat.total / 3)} share={cat.share} color={palette[i % palette.length]} />
        ))}
        <T variant="tiny" style={{ marginTop: 6 }}>
          A month on average over the last three full months.
        </T>
      </Card>
    </>
  );
}

function MoneyIn({ hub }: { hub: MoneyHub }) {
  const { c } = useTheme();
  return (
    <>
      <Card style={{ gap: 12 }}>
        <T variant="heading">Money in by month</T>
        <StackedBars
          bars={hub.monthlyIncome.map((m) => ({
            label: monthName(m.month, true),
            parts: [
              { value: m.salary ?? m.total, color: c.moneyIn },
              { value: m.other ?? 0, color: c.savings },
            ],
          }))}
        />
        <Legend items={[{ label: 'Salary', color: c.moneyIn }, { label: 'Everything else', color: c.savings }]} />
      </Card>
      <Card>
        <T variant="heading" style={{ marginBottom: 6 }}>
          Where it comes from
        </T>
        {hub.overview.moneyInSources.map((cat) => (
          <ShareBar key={cat.category} label={cat.words} value={pounds(cat.total / 3)} share={cat.share} color={c.moneyIn} />
        ))}
      </Card>
    </>
  );
}

function ExpectedTab({ hub }: { hub: MoneyHub }) {
  const { c } = useTheme();
  const next = hub.forecast.months[0];
  return (
    <>
      {hub.forecast.months.map((m) => (
        <Card key={m.month} style={{ gap: 8 }}>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
            <T variant="heading">{monthName(m.month)}</T>
            {typeof m.endBalance === 'number' ? <Pill text={`Ends near ${pounds(m.endBalance)}`} tone={m.endBalance < 500 ? 'out' : 'brand'} /> : null}
          </View>
          <View style={{ flexDirection: 'row', gap: 12 }}>
            <View style={{ flex: 1 }}>
              <T variant="tiny">Expected in</T>
              <Text style={{ color: c.moneyIn, fontWeight: '800', fontSize: 18 }}>+{gbp(m.expectedIn)}</Text>
            </View>
            <View style={{ flex: 1 }}>
              <T variant="tiny">Expected out</T>
              <Text style={{ color: c.ink, fontWeight: '800', fontSize: 18 }}>−{gbp(m.expectedOut)}</Text>
            </View>
          </View>
        </Card>
      ))}
      {next ? (
        <Card>
          <T variant="heading" style={{ marginBottom: 6 }}>
            Coming up in {monthName(next.month)}
          </T>
          {[...next.regularIn.map((r) => ({ ...r, in: true })), ...next.regularOut.map((r) => ({ ...r, in: false }))]
            .sort((a, b) => a.date.localeCompare(b.date))
            .map((r, i) => (
              <View key={`${r.merchant}-${i}`}>
                {i ? <Divider /> : null}
                <View style={{ flexDirection: 'row', paddingVertical: 10, gap: 10 }}>
                  <Text style={{ color: c.muted, width: 52 }}>{day(r.date)}</Text>
                  <View style={{ flex: 1 }}>
                    <T style={{ fontWeight: '600' }}>{r.merchantName}</T>
                    <T variant="tiny">{r.words}</T>
                  </View>
                  <Text style={{ color: r.in ? c.moneyIn : c.ink, fontWeight: '700' }}>
                    {r.in ? '+' : '−'}
                    {gbp(r.amount)}
                  </Text>
                </View>
              </View>
            ))}
          <T variant="tiny" style={{ marginTop: 8 }}>
            Regular payments on their usual day; everyday spending isn't listed here.
          </T>
        </Card>
      ) : null}
    </>
  );
}

function Goals({ hub, onChanged }: { hub: MoneyHub; onChanged: () => void }) {
  const { container } = useApp();
  const [adding, setAdding] = useState(false);
  const remove = useCallback(
    (goal: Goal) =>
      Alert.alert('Delete this goal?', `${goal.name} will be removed.`, [
        { text: 'Keep it', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            await container.moneyHub.deleteGoal(goal.name).catch(() => {});
            onChanged();
          },
        },
      ]),
    [container, onChanged],
  );
  return (
    <>
      {hub.goals.length ? hub.goals.map((g) => <GoalCard key={g.name} goal={g} onDelete={() => remove(g)} />) : (
        <Card>
          <T>No savings goals yet. Add one, or ask our assistant to help you plan one.</T>
        </Card>
      )}
      <Button title="Add a goal" icon="＋" onPress={() => setAdding(true)} />
      <Modal visible={adding} transparent animationType="slide" onRequestClose={() => setAdding(false)}>
        <GoalForm
          onClose={() => setAdding(false)}
          onSaved={() => {
            setAdding(false);
            onChanged();
          }}
        />
      </Modal>
    </>
  );
}

function GoalCard({ goal, onDelete }: { goal: Goal; onDelete: () => void }) {
  const { c } = useTheme();
  const progress = goalProgress(goal);
  return (
    <Card style={{ gap: 10 }}>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
        <T variant="heading">{goal.name}</T>
        <Pill text={goal.onTrack ? 'On track' : 'Needs a little more'} tone={goal.onTrack ? 'in' : 'warn'} />
      </View>
      <T variant="small">
        {gbp(goal.saved)} of {gbp(goal.target)}
        {goal.plan?.targetDateWords ? ` by ${goal.plan.targetDateWords}` : ''}
      </T>
      <View style={{ height: 12, borderRadius: 6, backgroundColor: c.savingsSoft, overflow: 'hidden' }} accessible accessibilityLabel={`${Math.round(progress * 100)}% saved`}>
        <View style={{ width: `${Math.round(progress * 100)}%`, height: 12, backgroundColor: c.savings, borderRadius: 6 }} />
      </View>
      <T variant="small">You'd need to put away {gbp(goal.neededPerMonth)} a month.</T>
      {goal.plan?.reachedAtCurrentRate?.words && !goal.onTrack ? <T variant="small">At the rate you save now, you'd get there in {goal.plan.reachedAtCurrentRate.words}.</T> : null}
      {(goal.plan?.changes || []).slice(0, 2).map((ch) => (
        <T key={ch.change} variant="small">
          💡 {ch.change}: saves {gbp(ch.savesPerMonth)} a month
        </T>
      ))}
      <Pressable accessibilityRole="button" onPress={onDelete} hitSlop={8}>
        <Text style={{ color: c.moneyOut, fontWeight: '600' }}>Delete goal</Text>
      </Pressable>
    </Card>
  );
}

function GoalForm({ onClose, onSaved }: { onClose: () => void; onSaved: () => void }) {
  const { container } = useApp();
  const { c, radius } = useTheme();
  const [name, setName] = useState('');
  const [target, setTarget] = useState('');
  const [byDate, setByDate] = useState('');
  const [saved, setSaved] = useState('');
  const [problem, setProblem] = useState('');
  const field = { borderWidth: 1, borderColor: c.line, borderRadius: radius - 6, padding: 12, color: c.ink, backgroundColor: c.soft } as const;

  const save = async () => {
    const goal = validateGoal(name, target, byDate, saved);
    if (typeof goal === 'string') return setProblem(goal);
    try {
      await container.moneyHub.saveGoal(goal);
      onSaved();
    } catch (e) {
      setProblem(e instanceof Error ? e.message : 'The goal could not be saved.');
    }
  };

  return (
    <Pressable style={{ flex: 1, backgroundColor: '#0008', justifyContent: 'flex-end' }} onPress={onClose}>
      <Pressable style={{ backgroundColor: c.card, borderTopLeftRadius: radius + 8, borderTopRightRadius: radius + 8, padding: 20, gap: 12 }}>
        <ScrollView keyboardShouldPersistTaps="handled" contentContainerStyle={{ gap: 12 }}>
          <T variant="heading">A new savings goal</T>
          <TextInput accessibilityLabel="Goal name" placeholder="What it's for (for example A new car)" placeholderTextColor={c.muted} value={name} onChangeText={setName} style={field} />
          <TextInput accessibilityLabel="Amount" placeholder="How much, £" placeholderTextColor={c.muted} keyboardType="decimal-pad" value={target} onChangeText={setTarget} style={field} />
          <TextInput accessibilityLabel="By when" placeholder="By when (YYYY-MM-DD)" placeholderTextColor={c.muted} value={byDate} onChangeText={setByDate} style={field} />
          <TextInput accessibilityLabel="Saved so far" placeholder="Saved so far, £ (optional)" placeholderTextColor={c.muted} keyboardType="decimal-pad" value={saved} onChangeText={setSaved} style={field} />
          {problem ? <Text style={{ color: c.moneyOut }}>{problem}</Text> : null}
          <View style={{ flexDirection: 'row', gap: 10 }}>
            <Button style={{ flex: 1 }} kind="ghost" title="Cancel" onPress={onClose} />
            <Button style={{ flex: 1 }} title="Save goal" onPress={save} />
          </View>
        </ScrollView>
      </Pressable>
    </Pressable>
  );
}
