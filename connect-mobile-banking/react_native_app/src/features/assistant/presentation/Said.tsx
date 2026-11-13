// An assistant message laid out for reading (core/format/messageLayout): lines, lists, the closing question and
// the disclaimer, with £ amounts in bold. Always text, never HTML.
import React from 'react';
import { Text, View } from 'react-native';
import { amounts, layout } from '../../../core/format/messageLayout';
import { useTheme } from '../../../core/theme/theme';

function WithAmounts({ text, color, style }: { text: string; color: string; style?: object }) {
  return (
    <Text style={[{ color, fontSize: 15, lineHeight: 21 }, style]}>
      {amounts(text).map((part, i) =>
        part.amount ? (
          <Text key={i} style={{ fontWeight: '700' }}>
            {part.text}
          </Text>
        ) : (
          part.text
        ),
      )}
    </Text>
  );
}

export function Said({ words }: { words: string }) {
  const { c } = useTheme();
  return (
    <View style={{ gap: 6 }}>
      {layout(words).map((block, i) => {
        if (block.kind === 'list') {
          return (
            <View key={i} style={{ gap: 3 }}>
              {block.lead ? <WithAmounts text={block.lead} color={c.ink} /> : null}
              {block.items.map((item, j) => (
                <View key={j} style={{ flexDirection: 'row', gap: 6, paddingLeft: 4 }}>
                  <Text style={{ color: c.muted }}>{block.ordered ? `${j + 1}.` : '•'}</Text>
                  <View style={{ flex: 1 }}>
                    <WithAmounts text={item} color={c.ink} />
                  </View>
                </View>
              ))}
            </View>
          );
        }
        if (block.kind === 'note') return <WithAmounts key={i} text={block.text} color={c.muted} style={{ fontSize: 12 }} />;
        return <WithAmounts key={i} text={block.text} color={c.ink} style={block.kind === 'ask' ? { fontWeight: '600' } : undefined} />;
      })}
    </View>
  );
}
