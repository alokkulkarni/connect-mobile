// Small charts for the Money Hub, drawn with react-native-svg.
import React from 'react';
import { Text, View } from 'react-native';
import Svg, { Rect, Line } from 'react-native-svg';
import { pounds } from '../../../core/format/money';
import { useTheme } from '../../../core/theme/theme';

export type StackedBar = { label: string; parts: { value: number; color: string }[] };

// Bars side by side, each stacked from its parts (essentials and spending they choose, for example).
export function StackedBars({ bars, height = 160 }: { bars: StackedBar[]; height?: number }) {
  const { c } = useTheme();
  const max = Math.max(1, ...bars.map((b) => b.parts.reduce((s, p) => s + p.value, 0)));
  const width = 300;
  const slot = width / Math.max(1, bars.length);
  const barWidth = Math.min(56, slot * 0.55);
  return (
    <View accessible accessibilityLabel={bars.map((b) => `${b.label}: ${pounds(b.parts.reduce((s, p) => s + p.value, 0))}`).join('. ')}>
      <Svg width="100%" height={height} viewBox={`0 0 ${width} ${height}`}>
        <Line x1={0} y1={height - 1} x2={width} y2={height - 1} stroke={c.line} strokeWidth={1} />
        {bars.map((bar, i) => {
          let y = height - 1;
          const x = i * slot + (slot - barWidth) / 2;
          return bar.parts.map((part, j) => {
            const h = (part.value / max) * (height - 12);
            y -= h;
            return <Rect key={`${i}-${j}`} x={x} y={y} width={barWidth} height={Math.max(0, h)} rx={j === bar.parts.length - 1 ? 6 : 0} fill={part.color} />;
          });
        })}
      </Svg>
      <View style={{ flexDirection: 'row' }}>
        {bars.map((bar) => (
          <View key={bar.label} style={{ flex: 1, alignItems: 'center' }}>
            <Text style={{ color: c.muted, fontSize: 12 }}>{bar.label}</Text>
            <Text style={{ color: c.ink, fontSize: 13, fontWeight: '700' }}>{pounds(bar.parts.reduce((s, p) => s + p.value, 0))}</Text>
          </View>
        ))}
      </View>
    </View>
  );
}

// A labelled horizontal bar for one category's share.
export function ShareBar({ label, value, share, color }: { label: string; value: string; share: number; color: string }) {
  const { c } = useTheme();
  return (
    <View style={{ gap: 4, paddingVertical: 6 }} accessible accessibilityLabel={`${label}, ${value}, ${share}%`}>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
        <Text style={{ color: c.ink, fontWeight: '600' }}>{label}</Text>
        <Text style={{ color: c.ink, fontVariant: ['tabular-nums'] }}>{value}</Text>
      </View>
      <View style={{ height: 8, borderRadius: 4, backgroundColor: c.soft, overflow: 'hidden' }}>
        <View style={{ width: `${Math.max(2, Math.min(100, share))}%`, height: 8, borderRadius: 4, backgroundColor: color }} />
      </View>
    </View>
  );
}

export function Legend({ items }: { items: { label: string; color: string }[] }) {
  const { c } = useTheme();
  return (
    <View style={{ flexDirection: 'row', gap: 14, flexWrap: 'wrap' }}>
      {items.map((item) => (
        <View key={item.label} style={{ flexDirection: 'row', gap: 6, alignItems: 'center' }}>
          <View style={{ width: 10, height: 10, borderRadius: 3, backgroundColor: item.color }} />
          <Text style={{ color: c.muted, fontSize: 12 }}>{item.label}</Text>
        </View>
      ))}
    </View>
  );
}
