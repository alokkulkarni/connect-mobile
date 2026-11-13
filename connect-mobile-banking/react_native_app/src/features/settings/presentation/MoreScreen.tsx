// More: the screens that don't have a tab of their own.
import React from 'react';
import { Pressable, Text, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { useTheme } from '../../../core/theme/theme';
import { Card, Divider, Screen } from '../../../core/ui/kit';
import { useScreenContext } from '../../assistant/presentation/useScreenContext';

const ITEMS = [
  { label: 'Mortgages', hint: 'Your mortgage, our rates, apply', glyph: '🏠', go: 'Mortgages' },
  { label: 'Help and FAQs', hint: 'Common questions and your disputes', glyph: '❓', go: 'Help' },
  { label: 'Notifications', hint: 'Money alerts, and try them out', glyph: '🔔', go: 'Notifications' },
  { label: 'Settings', hint: 'This device, about the app', glyph: '⚙️', go: 'Settings' },
];

export function MoreScreen() {
  const { c } = useTheme();
  const navigation = useNavigation<any>();
  useScreenContext({ page: 'home', label: 'More', launcher: 'Ask us anything', screen: 'More' });
  return (
    <Screen>
      <Card style={{ paddingVertical: 4 }}>
        {ITEMS.map((item, i) => (
          <View key={item.go}>
            {i ? <Divider /> : null}
            <Pressable accessibilityRole="button" accessibilityLabel={item.label} onPress={() => navigation.navigate(item.go)} style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', gap: 14, paddingVertical: 14, opacity: pressed ? 0.6 : 1 })}>
              <View style={{ width: 42, height: 42, borderRadius: 14, backgroundColor: c.accent, alignItems: 'center', justifyContent: 'center' }}>
                <Text style={{ fontSize: 20 }}>{item.glyph}</Text>
              </View>
              <View style={{ flex: 1 }}>
                <Text style={{ color: c.ink, fontWeight: '700', fontSize: 16 }}>{item.label}</Text>
                <Text style={{ color: c.muted, fontSize: 13 }}>{item.hint}</Text>
              </View>
              <Text style={{ color: c.muted, fontSize: 22 }}>›</Text>
            </Pressable>
          </View>
        ))}
      </Card>
    </Screen>
  );
}
