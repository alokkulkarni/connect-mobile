// The assistant as a bottom sheet: start a chat or call, follow the conversation, type, mute, end. Minimising
// keeps the conversation going behind the launcher; closing ends it (web/widget/dock.js, talk.js).
// It sits above the tab bar and leaves the screen behind it usable, so the customer can move between screens during a
// conversation (and the assistant follows them, CONTRACT.md section 6). Drag the grip or the header to resize it; it
// settles at one of three heights, and dragging it well below the smallest minimises it, as the web's sheet does.
import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  AccessibilityActionEvent,
  Animated,
  FlatList,
  Keyboard,
  PanResponder,
  Platform,
  Pressable,
  Text,
  TextInput,
  useWindowDimensions,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAssistant } from '../../../app/AppContext';
import { useTheme } from '../../../core/theme/theme';
import { Button } from '../../../core/ui/kit';
import type { ChatLine } from '../domain/chatEngine';
import { Said } from './Said';

const SNAPS = [0.38, 0.62, 1]; // of the room above the tab bar
const START = 1; // opens at the middle height
const DRAG_START = 6; // points moved before a drag on the header counts

// bottomInset: what the sheet sits on (the tab bar on the tab screens, else nothing), measured by the app.
export function AssistantSheet({ bottomInset }: { bottomInset: number }) {
  const [state, assistant] = useAssistant();
  const { c, radius } = useTheme();
  const insets = useSafeAreaInsets();
  const window = useWindowDimensions();
  const list = useRef<FlatList<ChatLine>>(null);
  const [mounted, setMounted] = useState(state.open);
  const [keyboard, setKeyboard] = useState(0);

  // The room above whatever it sits on: above the keyboard while it's open (iOS; Android resizes the window itself).
  const below = keyboard > 0 ? keyboard : bottomInset;
  const room = Math.max(240, window.height - insets.top - below - 12);
  const snaps = useMemo(() => SNAPS.map(f => Math.round(f * room)), [room]);
  const [size, setSize] = useState<number | null>(null); // null: the starting height
  const height = Math.min(size ?? snaps[START], room);
  const slide = useRef(new Animated.Value(window.height)).current;

  useEffect(() => {
    if (state.open) setMounted(true);
    Animated.timing(slide, {
      toValue: state.open ? 0 : window.height,
      duration: 260,
      useNativeDriver: true,
    }).start(({ finished }) => {
      if (finished && !state.open) {
        setMounted(false);
        setSize(null);
      }
    });
  }, [state.open, window.height, slide]);

  useEffect(() => {
    if (state.lines.length)
      setTimeout(() => list.current?.scrollToEnd({ animated: true }), 50);
  }, [state.lines.length]);

  useEffect(() => {
    if (Platform.OS !== 'ios') return;
    const shown = Keyboard.addListener('keyboardWillShow', e =>
      setKeyboard(e.endCoordinates.height),
    );
    const hidden = Keyboard.addListener('keyboardWillHide', () =>
      setKeyboard(0),
    );
    return () => {
      shown.remove();
      hidden.remove();
    };
  }, []);

  // Resizing: the grip or the header follows the finger, then settles at the nearest height.
  const dragFrom = useRef(0);
  const live = useRef({ height, snaps });
  live.current = { height, snaps };
  const resize = useMemo(
    () =>
      PanResponder.create({
        onMoveShouldSetPanResponder: (_, g) =>
          Math.abs(g.dy) > DRAG_START && Math.abs(g.dy) > Math.abs(g.dx),
        onPanResponderGrant: () => {
          dragFrom.current = live.current.height;
        },
        onPanResponderMove: (_, g) =>
          setSize(Math.max(120, dragFrom.current - g.dy)),
        onPanResponderRelease: (_, g) => {
          const wanted = dragFrom.current - g.dy - g.vy * 120; // a flick carries on a little
          const [smallest] = live.current.snaps;
          if (wanted < smallest * 0.6) {
            assistant.minimise();
            return;
          }
          setSize(
            live.current.snaps.reduce((best, s) =>
              Math.abs(s - wanted) < Math.abs(best - wanted) ? s : best,
            ),
          );
        },
        onPanResponderTerminate: () => setSize(dragFrom.current),
      }),
    [assistant],
  );

  // For VoiceOver and TalkBack: swipe up or down on the grip to change the height.
  const step = (event: AccessibilityActionEvent) => {
    const at = snaps.findIndex(s => s >= height - 1);
    const next =
      event.nativeEvent.actionName === 'increment'
        ? Math.min(snaps.length - 1, at + 1)
        : Math.max(0, at - 1);
    setSize(snaps[next]);
  };

  if (!mounted) return null;
  const talking = state.kind !== null;

  return (
    <Animated.View
      accessibilityViewIsModal={false}
      style={{
        position: 'absolute',
        left: 0,
        right: 0,
        bottom: below,
        height,
        transform: [{ translateY: slide }],
        backgroundColor: c.card,
        borderTopLeftRadius: radius + 8,
        borderTopRightRadius: radius + 8,
        paddingBottom: below > 0 ? 8 : insets.bottom + 8,
        shadowColor: '#000',
        shadowOpacity: 0.18,
        shadowRadius: 16,
        shadowOffset: { width: 0, height: -4 },
        elevation: 16,
      }}
    >
      <View {...resize.panHandlers}>
        <View
          accessible
          accessibilityRole="adjustable"
          accessibilityLabel="Resize the assistant"
          accessibilityHint="Swipe up or down to make it taller or shorter. Drag it down to minimise."
          accessibilityActions={[{ name: 'increment' }, { name: 'decrement' }]}
          onAccessibilityAction={step}
          hitSlop={{ top: 10, bottom: 10 }}
          style={{ alignItems: 'center', paddingTop: 8, paddingBottom: 2 }}
        >
          <View
            style={{
              width: 44,
              height: 5,
              borderRadius: 3,
              backgroundColor: c.line,
            }}
          />
        </View>
        {/* Header: who, where, minimise and close */}
        <View
          style={{
            flexDirection: 'row',
            alignItems: 'center',
            paddingHorizontal: 18,
            paddingVertical: 10,
            gap: 10,
          }}
        >
          <View
            style={{
              width: 38,
              height: 38,
              borderRadius: 19,
              backgroundColor: c.brand,
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Text style={{ color: '#fff', fontWeight: '800' }}>N</Text>
          </View>
          <View style={{ flex: 1 }}>
            <Text
              style={{ color: c.ink, fontWeight: '700', fontSize: 17 }}
              accessibilityRole="header"
            >
              Nationwide assistant
            </Text>
            <Text style={{ color: c.muted, fontSize: 12 }} numberOfLines={1}>
              {talking ? (state.kind === 'call' ? 'Call' : 'Chat') + ' · ' : ''}
              {state.context.label}
            </Text>
          </View>
          <HeaderIcon
            label="Minimise the assistant"
            glyph="–"
            onPress={() => assistant.minimise()}
          />
          <HeaderIcon
            label="Close the assistant"
            glyph="×"
            onPress={() => assistant.close()}
          />
        </View>
      </View>
      <View style={{ height: 1, backgroundColor: c.line }} />

      {talking ? (
        <FlatList
          ref={list}
          style={{ flex: 1 }}
          contentContainerStyle={{ padding: 16, gap: 10 }}
          data={state.lines}
          keyExtractor={line => line.id}
          ListHeaderComponent={
            state.kind === 'call' ? (
              <CallPanel
                muted={state.muted}
                connected={state.connected}
                withPerson={state.withPerson}
              />
            ) : undefined
          }
          renderItem={({ item }) => (
            <Bubble
              line={item}
              onOpenForm={url => assistant.openFormLink(url)}
            />
          )}
        />
      ) : (
        <StartPanel label={state.context.label} available={state.available} />
      )}

      {state.status ? (
        <Text
          accessibilityLiveRegion="polite"
          style={{
            color: c.muted,
            fontSize: 13,
            paddingHorizontal: 18,
            paddingVertical: 6,
          }}
        >
          {state.status}
        </Text>
      ) : null}

      {talking && state.kind === 'chat' ? (
        <View
          style={{
            flexDirection: 'row',
            gap: 8,
            paddingHorizontal: 12,
            alignItems: 'flex-end',
          }}
        >
          <TextInput
            accessibilityLabel="Your message"
            value={state.draft}
            onChangeText={t => assistant.setDraft(t)}
            editable={state.inputEnabled}
            placeholder={
              state.inputEnabled ? 'Type your message' : 'Please wait…'
            }
            placeholderTextColor={c.muted}
            multiline
            style={{
              flex: 1,
              maxHeight: 110,
              minHeight: 44,
              borderRadius: 22,
              borderWidth: 1,
              borderColor: c.line,
              paddingHorizontal: 16,
              paddingTop: 12,
              paddingBottom: 10,
              color: c.ink,
              backgroundColor: c.soft,
            }}
          />
          <Button
            title="Send"
            onPress={() => assistant.send()}
            disabled={!state.inputEnabled || !state.draft.trim()}
          />
        </View>
      ) : null}
      {talking ? (
        <View
          style={{
            flexDirection: 'row',
            gap: 8,
            paddingHorizontal: 12,
            paddingTop: 8,
          }}
        >
          {state.kind === 'call' ? (
            <Button
              style={{ flex: 1 }}
              kind="secondary"
              title={state.muted ? 'Unmute' : 'Mute'}
              onPress={() => assistant.toggleMute()}
            />
          ) : null}
          <Button
            style={{ flex: 1 }}
            kind="danger"
            title={state.kind === 'call' ? 'End call' : 'End chat'}
            onPress={() => assistant.end()}
          />
        </View>
      ) : null}
    </Animated.View>
  );
}

function HeaderIcon({
  label,
  glyph,
  onPress,
}: {
  label: string;
  glyph: string;
  onPress: () => void;
}) {
  const { c } = useTheme();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      onPress={onPress}
      hitSlop={8}
      style={{
        width: 36,
        height: 36,
        borderRadius: 18,
        alignItems: 'center',
        justifyContent: 'center',
        backgroundColor: c.soft,
      }}
    >
      <Text style={{ color: c.ink, fontSize: 20, lineHeight: 22 }}>
        {glyph}
      </Text>
    </Pressable>
  );
}

function StartPanel({
  label,
  available,
}: {
  label: string;
  available: boolean;
}) {
  const [, assistant] = useAssistant();
  const { c } = useTheme();
  return (
    <View style={{ flex: 1, padding: 20, gap: 16 }}>
      <Text style={{ color: c.ink, fontSize: 16, lineHeight: 23 }}>
        Chat or talk with our assistant. It can see which screen you're on,
        starting with <Text style={{ fontWeight: '700' }}>{label}</Text>.
      </Text>
      <View style={{ flexDirection: 'row', gap: 12 }}>
        <Button
          style={{ flex: 1 }}
          title="Chat"
          icon="💬"
          onPress={() => assistant.startChat()}
          disabled={!available}
        />
        <Button
          style={{ flex: 1 }}
          title="Call"
          icon="📞"
          kind="secondary"
          onPress={() => assistant.startCall()}
          disabled={!available}
        />
      </View>
      <Text style={{ color: c.muted, fontSize: 13, lineHeight: 18 }}>
        It's an AI assistant, not a person. Ask at any time to speak to one of
        our colleagues.
      </Text>
    </View>
  );
}

function CallPanel({
  muted,
  connected,
  withPerson,
}: {
  muted: boolean;
  connected: boolean;
  withPerson: boolean;
}) {
  const { c } = useTheme();
  return (
    <View style={{ alignItems: 'center', paddingVertical: 18, gap: 8 }}>
      <View
        style={{
          width: 92,
          height: 92,
          borderRadius: 46,
          backgroundColor: connected ? c.moneyInSoft : c.accent,
          alignItems: 'center',
          justifyContent: 'center',
          borderWidth: 3,
          borderColor: connected ? c.moneyIn : c.brand2,
        }}
      >
        <Text style={{ fontSize: 36 }}>{muted ? '🔇' : '🎧'}</Text>
      </View>
      <Text style={{ color: c.ink, fontWeight: '700' }}>
        {withPerson
          ? 'With a colleague'
          : connected
          ? 'Connected'
          : 'Connecting…'}
      </Text>
      <Text style={{ color: c.muted, fontSize: 12 }}>
        What's said appears below.
      </Text>
    </View>
  );
}

function Bubble({
  line,
  onOpenForm,
}: {
  line: ChatLine;
  onOpenForm: (url: string) => void;
}) {
  const { c } = useTheme();
  const me = line.who === 'me';
  return (
    <View
      style={{
        alignSelf: me ? 'flex-end' : 'flex-start',
        maxWidth: '86%',
        gap: 4,
      }}
    >
      <Text
        style={{
          color: c.muted,
          fontSize: 11,
          fontWeight: '700',
          alignSelf: me ? 'flex-end' : 'flex-start',
        }}
      >
        {me ? 'You' : 'Assistant'}
      </Text>
      <View
        style={{
          backgroundColor: me ? c.brand : c.soft,
          borderRadius: 18,
          borderBottomRightRadius: me ? 4 : 18,
          borderBottomLeftRadius: me ? 18 : 4,
          paddingHorizontal: 14,
          paddingVertical: 10,
        }}
      >
        {me ? (
          <Text style={{ color: '#fff', fontSize: 15, lineHeight: 21 }}>
            {line.text}
          </Text>
        ) : (
          <Said words={line.text} />
        )}
      </View>
      {line.formLink ? (
        <Button
          title="Open the form here"
          kind="secondary"
          onPress={() => onOpenForm(line.formLink!)}
        />
      ) : null}
    </View>
  );
}
