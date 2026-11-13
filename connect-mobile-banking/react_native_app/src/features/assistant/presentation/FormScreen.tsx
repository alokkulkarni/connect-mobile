// The mortgage and dispute forms, which their assistants fill in through Live Sync (web only), in a locked WebView.
// The app implements its side of the bridge now; the web side (W1 to W4) isn't wired yet, so the mortgage form's own
// assistant helps today (CONTRACT.md section 9).
import React, { useEffect, useMemo, useRef } from 'react';
import { Linking, Pressable, Text, View } from 'react-native';
import { WebView, WebViewMessageEvent } from 'react-native-webview';
import type { ShouldStartLoadRequest } from 'react-native-webview/lib/WebViewTypes';
import { useRoute } from '@react-navigation/native';
import { useApp, useAssistant } from '../../../app/AppContext';
import type { FormParams } from '../../../app/navigation/routes';
import { allowedOrigins, bridgeShim, dispatchEvent, formUrl, isAllowed, originOf } from '../../../core/forms/formPolicy';
import { useTheme } from '../../../core/theme/theme';
import { Card, Screen, T } from '../../../core/ui/kit';
import { parseStartCall } from '../../mortgages/domain/mortgages';
import { useScreenContext } from './useScreenContext';

export function FormScreen() {
  const { container, me } = useApp();
  const [state, assistant] = useAssistant();
  const { c } = useTheme();
  const form = useRoute<any>().params as FormParams;
  const web = useRef<{ injectJavaScript(script: string): void } | null>(null);
  const session = container.session;
  const appOrigin = session.mode === 'link' ? session.origin : '';
  const allowed = useMemo(() => allowedOrigins(appOrigin, me.disputePagesUrl), [appOrigin, me.disputePagesUrl]);
  const url = session.mode === 'link' ? formUrl(form, session.origin, session.secret) : '';

  // No assistant of the app's own on this screen: the launcher is hidden.
  useScreenContext({ label: form.kind === 'mortgage' ? 'Mortgage application' : 'Dispute form', launcher: '', screen: 'Form' });

  // App -> page: a call started from the form's own "Call us" is joined to the form.
  useEffect(() => {
    const stop = assistant.onStartedConversation((info) => {
      if (info.kind === 'call') web.current?.injectJavaScript(dispatchEvent('mortgage:call-started', { contactId: info.contactId }));
    });
    return stop;
  }, [assistant]);

  if (!url || !isAllowed(url, allowed)) {
    return (
      <Screen>
        <Card style={{ gap: 8 }}>
          <T variant="heading">{form.kind === 'mortgage' ? 'Your mortgage application' : 'Your dispute form'}</T>
          <T>
            {session.mode === 'sample'
              ? 'The form opens from your internet banking link, so our assistants can fill it in with you. Sample mode has no link.'
              : "This form can't be opened here."}
          </T>
        </Card>
      </Screen>
    );
  }

  const onShouldStart = (request: ShouldStartLoadRequest) => {
    if (isAllowed(request.url, allowed)) return true;
    if (originOf(request.url)) Linking.openURL(request.url).catch(() => {});
    return false;
  };

  const onMessage = (event: WebViewMessageEvent) => {
    if (!isAllowed(event.nativeEvent.url, allowed)) return;
    let message: { type?: string; payload?: string };
    try {
      message = JSON.parse(event.nativeEvent.data);
    } catch {
      return;
    }
    if (message.type !== 'startCall') return;
    const call = parseStartCall(message.payload);
    if (call) assistant.startFormCall(call.applicationId, call.stage);
  };

  return (
    <View style={{ flex: 1, backgroundColor: c.bg }}>
      <WebView
        ref={web as never}
        source={{ uri: url }}
        originWhitelist={['https://*']}
        onShouldStartLoadWithRequest={onShouldStart}
        injectedJavaScriptBeforeContentLoaded={bridgeShim(allowed)}
        onMessage={onMessage}
        onLoadEnd={() => {
          if (form.kind === 'disputeSession') web.current?.injectJavaScript(dispatchEvent('dispute:open', { sessionId: form.sessionId }));
        }}
        allowFileAccess={false}
        allowFileAccessFromFileURLs={false}
        allowUniversalAccessFromFileURLs={false}
        mixedContentMode="never"
        setSupportMultipleWindows={false}
        javaScriptCanOpenWindowsAutomatically={false}
        mediaPlaybackRequiresUserAction={false}
        allowsInlineMediaPlayback
        mediaCapturePermissionGrantType="grantIfSameHostElsePrompt"
        incognito={false}
        sharedCookiesEnabled={false}
        style={{ flex: 1 }}
      />
      {state.kind ? (
        <Pressable
          accessibilityRole="button"
          onPress={() => assistant.open()}
          style={{ flexDirection: 'row', alignItems: 'center', gap: 8, backgroundColor: c.brand, padding: 12 }}>
          <View style={{ width: 8, height: 8, borderRadius: 4, backgroundColor: '#34c294' }} />
          <Text style={{ color: '#fff', fontWeight: '700', flex: 1 }}>{state.kind === 'call' ? 'On a call with us' : 'Chatting with us'}</Text>
          <Text style={{ color: '#fff' }}>Open</Text>
        </Pressable>
      ) : null}
    </View>
  );
}
