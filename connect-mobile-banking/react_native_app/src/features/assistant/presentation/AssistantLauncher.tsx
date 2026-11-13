// The assistant's button, above the tab bar on every screen but the forms WebView, with the screen's own words
// and a live dot while a conversation is going (web/widget/dock.js).
import React, { useEffect, useRef } from 'react';
import { Animated, Pressable, Text, View } from 'react-native';
import { useAssistant } from '../../../app/AppContext';
import { useTheme } from '../../../core/theme/theme';

// bottomInset: what's below it (the tab bar, or the home indicator), measured by the app.
export function AssistantLauncher({
  route,
  bottomInset,
}: {
  route: string;
  bottomInset: number;
}) {
  const [state, assistant] = useAssistant();
  const { c } = useTheme();
  const pulse = useRef(new Animated.Value(1)).current;
  const live = state.kind !== null;

  useEffect(() => {
    if (!live) return;
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, {
          toValue: 0.35,
          duration: 700,
          useNativeDriver: true,
        }),
        Animated.timing(pulse, {
          toValue: 1,
          duration: 700,
          useNativeDriver: true,
        }),
      ]),
    );
    loop.start();
    return () => loop.stop();
  }, [live, pulse]);

  if (state.open || route === 'Form' || !route) return null;
  const bottom = bottomInset + 10;
  const title = live
    ? state.kind === 'call'
      ? 'On a call with us'
      : 'Chatting with us'
    : state.context.launcher;
  return (
    <View
      pointerEvents="box-none"
      style={{ position: 'absolute', left: 16, right: 16, bottom }}
    >
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`${title}. ${state.context.label}`}
        onPress={() => assistant.open()}
        style={({ pressed }) => ({
          flexDirection: 'row',
          alignItems: 'center',
          gap: 12,
          backgroundColor: c.brand,
          borderRadius: 999,
          paddingVertical: 12,
          paddingHorizontal: 18,
          shadowColor: '#000',
          shadowOpacity: 0.25,
          shadowRadius: 14,
          shadowOffset: { width: 0, height: 6 },
          elevation: 8,
          opacity: pressed ? 0.9 : 1,
        })}
      >
        <Animated.View
          style={{
            width: 10,
            height: 10,
            borderRadius: 5,
            backgroundColor: live ? '#34c294' : '#9fb0ff',
            opacity: live ? pulse : 1,
          }}
        />
        <View style={{ flex: 1 }}>
          <Text
            style={{ color: '#fff', fontWeight: '700', fontSize: 15 }}
            numberOfLines={1}
          >
            {title}
          </Text>
          <Text style={{ color: '#ffffffb3', fontSize: 12 }} numberOfLines={1}>
            {state.context.label}
          </Text>
        </View>
        <Text style={{ color: '#fff', fontSize: 20 }}>💬</Text>
      </Pressable>
    </View>
  );
}
