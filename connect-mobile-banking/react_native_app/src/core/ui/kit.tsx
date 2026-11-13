// The app's building blocks, drawn from the theme. Every value is shown as text.
import React from 'react';
import {
  ActivityIndicator,
  Pressable,
  RefreshControl,
  ScrollView,
  StyleProp,
  StyleSheet,
  Text,
  TextStyle,
  View,
  ViewStyle,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '../theme/theme';
import { initials, signed, tidyMerchant } from '../format/money';

// Room at the bottom of every scrolling screen for the assistant's launcher.
export const LAUNCHER_ROOM = 88;

export function Screen({
  children,
  refreshing = false,
  onRefresh,
  padded = true,
}: {
  children: React.ReactNode;
  refreshing?: boolean;
  onRefresh?: () => void;
  padded?: boolean;
}) {
  const { c, space } = useTheme();
  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: c.bg }}
      contentContainerStyle={{ padding: padded ? space(4) : 0, paddingBottom: LAUNCHER_ROOM + space(6), gap: space(4) }}
      refreshControl={onRefresh ? <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={c.brand2} /> : undefined}
      keyboardShouldPersistTaps="handled">
      {children}
    </ScrollView>
  );
}

export function Card({ children, style, onPress, label }: { children: React.ReactNode; style?: StyleProp<ViewStyle>; onPress?: () => void; label?: string }) {
  const { c, radius, space, dark } = useTheme();
  const base: ViewStyle = {
    backgroundColor: c.card,
    borderRadius: radius,
    padding: space(4),
    borderWidth: dark ? StyleSheet.hairlineWidth : 0,
    borderColor: c.line,
    shadowColor: '#101631',
    shadowOpacity: dark ? 0 : 0.06,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 4 },
    elevation: dark ? 0 : 2,
  };
  if (!onPress) return <View style={[base, style]}>{children}</View>;
  return (
    <Pressable accessibilityRole="button" accessibilityLabel={label} onPress={onPress} style={({ pressed }) => [base, style, pressed && { opacity: 0.85 }]}>
      {children}
    </Pressable>
  );
}

export function T({
  children,
  variant = 'body',
  color,
  style,
  numberOfLines,
}: {
  children: React.ReactNode;
  variant?: 'title' | 'heading' | 'body' | 'small' | 'tiny' | 'amount' | 'label';
  color?: string;
  style?: StyleProp<TextStyle>;
  numberOfLines?: number;
}) {
  const { c, font } = useTheme();
  const styles: Record<string, TextStyle> = {
    title: { fontSize: font.title, fontWeight: '700', color: c.ink, letterSpacing: -0.3 },
    heading: { fontSize: font.heading, fontWeight: '700', color: c.ink },
    body: { fontSize: font.body, color: c.ink, lineHeight: 22 },
    small: { fontSize: font.small, color: c.muted, lineHeight: 19 },
    tiny: { fontSize: font.tiny, color: c.muted },
    amount: { fontSize: font.amount, fontWeight: '700', color: c.ink, fontVariant: ['tabular-nums'] },
    label: { fontSize: font.tiny, fontWeight: '700', color: c.muted, textTransform: 'uppercase', letterSpacing: 0.6 },
  };
  return (
    <Text style={[styles[variant], color ? { color } : null, style]} numberOfLines={numberOfLines}>
      {children}
    </Text>
  );
}

export function SectionHead({ title, action, onAction }: { title: string; action?: string; onAction?: () => void }) {
  const { c } = useTheme();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
      <T variant="heading">{title}</T>
      {action && onAction ? (
        <Pressable accessibilityRole="link" onPress={onAction} hitSlop={8}>
          <Text style={{ color: c.brand2, fontWeight: '600' }}>{action}</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

export function Button({
  title,
  onPress,
  kind = 'primary',
  disabled,
  icon,
  style,
}: {
  title: string;
  onPress: () => void;
  kind?: 'primary' | 'secondary' | 'ghost' | 'danger';
  disabled?: boolean;
  icon?: string;
  style?: StyleProp<ViewStyle>;
}) {
  const { c, radius } = useTheme();
  const bg = { primary: c.brand, secondary: c.accent, ghost: 'transparent', danger: c.moneyOutSoft }[kind];
  const fg = { primary: c.onBrand, secondary: c.brand2, ghost: c.brand2, danger: c.moneyOut }[kind];
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={title}
      accessibilityState={{ disabled: Boolean(disabled) }}
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => [
        {
          backgroundColor: bg,
          borderRadius: radius - 4,
          paddingVertical: 13,
          paddingHorizontal: 18,
          alignItems: 'center',
          justifyContent: 'center',
          flexDirection: 'row',
          gap: 8,
          opacity: disabled ? 0.45 : pressed ? 0.85 : 1,
          borderWidth: kind === 'ghost' ? 1 : 0,
          borderColor: c.line,
        },
        style,
      ]}>
      {icon ? <Text style={{ color: fg, fontSize: 16 }}>{icon}</Text> : null}
      <Text style={{ color: fg, fontWeight: '700', fontSize: 15 }}>{title}</Text>
    </Pressable>
  );
}

// A row of tabs (Money Hub's tabs, Cards' Payments and Your disputes).
export function Segmented<K extends string>({ options, value, onChange }: { options: [K, string][]; value: K; onChange: (k: K) => void }) {
  const { c } = useTheme();
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }} accessibilityRole="tablist">
      {options.map(([key, label]) => {
        const on = key === value;
        return (
          <Pressable
            key={key}
            accessibilityRole="tab"
            accessibilityState={{ selected: on }}
            onPress={() => onChange(key)}
            style={{ paddingVertical: 8, paddingHorizontal: 14, borderRadius: 999, backgroundColor: on ? c.brand : c.card, borderWidth: on ? 0 : 1, borderColor: c.line }}>
            <Text style={{ color: on ? c.onBrand : c.ink, fontWeight: '600' }}>{label}</Text>
          </Pressable>
        );
      })}
    </ScrollView>
  );
}

const TILE_COLOURS = ['#4864e6', '#0f8a66', '#e08a1e', '#7b5cff', '#c63d3d', '#2a3f86', '#13859b', '#a0469b'];

export function MerchantTile({ name, size = 40 }: { name: string; size?: number }) {
  const sum = Array.from(String(name)).reduce((a, ch) => a + ch.charCodeAt(0), 0);
  const colour = TILE_COLOURS[sum % TILE_COLOURS.length];
  return (
    <View
      accessible={false}
      style={{ width: size, height: size, borderRadius: size / 3, backgroundColor: colour + '22', alignItems: 'center', justifyContent: 'center' }}>
      <Text style={{ color: colour, fontWeight: '800', fontSize: size * 0.36 }}>{initials(name)}</Text>
    </View>
  );
}

// One payment in a list: tile, name, category and date, and the amount (green with + when money comes in).
export function PaymentRow({
  name,
  meta,
  amount,
  moneyIn,
  onPress,
  right,
}: {
  name: string;
  meta: string;
  amount: number;
  moneyIn: boolean;
  onPress?: () => void;
  right?: React.ReactNode;
}) {
  const { c } = useTheme();
  const content = (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 10 }}>
      <MerchantTile name={name} />
      <View style={{ flex: 1 }}>
        <T numberOfLines={1} style={{ fontWeight: '600' }}>
          {name === name.toUpperCase() ? tidyMerchant(name) : name}
        </T>
        <T variant="small" numberOfLines={1}>
          {meta}
        </T>
      </View>
      <View style={{ alignItems: 'flex-end', gap: 4 }}>
        <Text style={{ color: moneyIn ? c.moneyIn : c.ink, fontWeight: '700', fontVariant: ['tabular-nums'] }}>{signed(amount, moneyIn)}</Text>
        {right}
      </View>
    </View>
  );
  if (!onPress) return content;
  return (
    <Pressable accessibilityRole="button" accessibilityLabel={`${name}, ${signed(amount, moneyIn)}, ${meta}`} onPress={onPress} style={({ pressed }) => pressed && { opacity: 0.6 }}>
      {content}
    </Pressable>
  );
}

export function Divider() {
  const { c } = useTheme();
  return <View style={{ height: StyleSheet.hairlineWidth, backgroundColor: c.line }} />;
}

export function Loading({ words = 'Loading…' }: { words?: string }) {
  const { c } = useTheme();
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 40, gap: 12, backgroundColor: c.bg }}>
      <ActivityIndicator color={c.brand2} />
      <T variant="small">{words}</T>
    </View>
  );
}

export function Problem({ words, onRetry }: { words: string; onRetry?: () => void }) {
  return (
    <Card style={{ gap: 12 }}>
      <T>{words}</T>
      {onRetry ? <Button title="Try again" kind="secondary" onPress={onRetry} /> : null}
    </Card>
  );
}

// onSignIn: Sample mode only, a way back to the sign-in screen to paste the internet banking link.
export function DemoBanner({ onSignIn }: { onSignIn?: () => void }) {
  const { c } = useTheme();
  const insets = useSafeAreaInsets();
  return (
    <View style={{ backgroundColor: c.brand, paddingTop: insets.top, paddingBottom: 4, alignItems: 'center' }}>
      <Text style={{ color: '#ffffffcc', fontSize: 11, fontWeight: '600', letterSpacing: 0.4 }} accessibilityRole="text">
        Demo · sample data
      </Text>
      {onSignIn ? (
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Sign in with your internet banking link"
          onPress={onSignIn}
          hitSlop={8}
          style={({ pressed }) => ({ marginTop: 6, marginBottom: 2, paddingHorizontal: 14, paddingVertical: 5, borderRadius: 999, backgroundColor: '#ffffff26', opacity: pressed ? 0.6 : 1 })}>
          <Text style={{ color: '#fff', fontSize: 13, fontWeight: '700' }}>Exploring sample data · Sign in with your link ›</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

export function Pill({ text, tone = 'neutral' }: { text: string; tone?: 'neutral' | 'in' | 'out' | 'warn' | 'brand' }) {
  const { c } = useTheme();
  const map = {
    neutral: [c.soft, c.muted],
    in: [c.moneyInSoft, c.moneyIn],
    out: [c.moneyOutSoft, c.moneyOut],
    warn: [c.flexibleSoft, c.flexible],
    brand: [c.accent, c.brand2],
  } as const;
  const [bg, fg] = map[tone];
  return (
    <View style={{ backgroundColor: bg, borderRadius: 999, paddingHorizontal: 10, paddingVertical: 3, alignSelf: 'flex-start' }}>
      <Text style={{ color: fg, fontSize: 12, fontWeight: '700' }}>{text}</Text>
    </View>
  );
}
