// Sign in: open the app from the internet banking link (pasted here, or opened on the phone as a verified link), or
// explore with sample data. The demo has no username or password: the link stands for the customer signed in.
import React, { useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, Text, TextInput, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '../../../core/theme/theme';
import { Button } from '../../../core/ui/kit';

export function SignInScreen({ notice, onLink, onSample }: { notice: string; onLink: (link: string) => Promise<void>; onSample: () => void }) {
  const { c, radius } = useTheme();
  const insets = useSafeAreaInsets();
  const [link, setLink] = useState('');
  const [problem, setProblem] = useState('');
  const [busy, setBusy] = useState(false);

  const open = async () => {
    setBusy(true);
    setProblem('');
    try {
      await onLink(link);
    } catch (e) {
      setProblem(e instanceof Error ? e.message : "That link didn't work.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={{ flex: 1, backgroundColor: c.brand }}>
      <ScrollView contentContainerStyle={{ flexGrow: 1, paddingTop: insets.top + 48, paddingHorizontal: 24, paddingBottom: insets.bottom + 24, gap: 28 }} keyboardShouldPersistTaps="handled">
        <View style={{ gap: 10 }}>
          <View style={{ width: 64, height: 64, borderRadius: 20, backgroundColor: '#ffffff1f', alignItems: 'center', justifyContent: 'center' }}>
            <Text style={{ color: '#fff', fontSize: 30, fontWeight: '900' }}>N</Text>
          </View>
          <Text style={{ color: '#fff', fontSize: 30, fontWeight: '800', letterSpacing: -0.5 }} accessibilityRole="header">
            Nationwide
          </Text>
          <Text style={{ color: '#ffffffcc', fontSize: 16, lineHeight: 23 }}>Your banking, your Money Hub, and help from our assistant by chat or call, wherever you are in the app.</Text>
          <Text style={{ color: '#ffffff99', fontSize: 12 }}>Demo · sample data</Text>
        </View>

        {notice ? (
          <View style={{ backgroundColor: '#ffffff1a', borderRadius: radius - 4, padding: 14 }}>
            <Text style={{ color: '#fff', lineHeight: 20 }}>{notice}</Text>
          </View>
        ) : null}

        <View style={{ backgroundColor: c.card, borderRadius: radius + 4, padding: 20, gap: 14 }}>
          <Text style={{ color: c.ink, fontWeight: '700', fontSize: 18 }}>Open your internet banking</Text>
          <Text style={{ color: c.muted, lineHeight: 20 }}>Open the link we gave you on this phone, or paste it here.</Text>
          <TextInput
            accessibilityLabel="Your internet banking link"
            value={link}
            onChangeText={setLink}
            placeholder="https://…#k=…"
            placeholderTextColor={c.muted}
            autoCapitalize="none"
            autoCorrect={false}
            keyboardType="url"
            secureTextEntry={false}
            style={{ borderWidth: 1, borderColor: c.line, borderRadius: radius - 6, padding: 14, color: c.ink, backgroundColor: c.soft }}
          />
          {problem ? <Text style={{ color: c.moneyOut }}>{problem}</Text> : null}
          <Button title={busy ? 'Opening…' : 'Open'} onPress={open} disabled={busy || !link.trim()} />
        </View>

        <View style={{ gap: 8 }}>
          <Button title="Explore with sample data" kind="secondary" onPress={onSample} />
          <Text style={{ color: '#ffffffaa', fontSize: 12, textAlign: 'center' }}>Everything works on sample data except chat and calls, which need your link.</Text>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
