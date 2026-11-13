// The forms WebView's locks (CONTRACT.md section 9; S6 in connect-banking-app/docs/mobile/README.md): it loads only
// the bank's own address and the dispute pages' address; anything else opens in the system browser. Pure logic.

export function originOf(url: string): string {
  const match = String(url || '').match(/^(https:\/\/[^/?#]+)/i);
  return match ? match[1].toLowerCase() : '';
}

export function allowedOrigins(appOrigin: string, disputePagesUrl: string): string[] {
  return [originOf(appOrigin), originOf(disputePagesUrl)].filter(Boolean);
}

export function isAllowed(url: string, allowed: string[]): boolean {
  if (url === 'about:blank') return true;
  const origin = originOf(url);
  return Boolean(origin) && allowed.includes(origin);
}

// The page each form opens at.
export function formUrl(
  form: { kind: 'mortgage' } | { kind: 'link'; url: string } | { kind: 'disputeSession'; sessionId: string },
  appOrigin: string,
  secret: string,
): string {
  if (form.kind === 'link') return form.url;
  const path = form.kind === 'mortgage' ? '/apply/about-you' : '/cards/dispute';
  return `${appOrigin}${path}#k=${encodeURIComponent(secret)}`;
}

// Injected before the page's own scripts, only into pages from the allowed origins: the page's "Call us" asks the app
// through window.AndroidBridge.startCall(json), as the mortgage form does inside the native apps.
export function bridgeShim(allowed: string[]): string {
  return `(function () {
  var allowed = ${JSON.stringify(allowed)};
  if (allowed.indexOf(location.origin.toLowerCase()) < 0 || !window.ReactNativeWebView) return;
  window.AndroidBridge = {
    startCall: function (json) {
      window.ReactNativeWebView.postMessage(JSON.stringify({ type: 'startCall', payload: String(json) }));
    }
  };
})(); true;`;
}

// App -> page: a CustomEvent the form listens for ('mortgage:call-started' {contactId}, 'dispute:open' {sessionId}).
export function dispatchEvent(name: 'mortgage:call-started' | 'dispute:open', detail: Record<string, string>): string {
  return `window.dispatchEvent(new CustomEvent(${JSON.stringify(name)}, { detail: ${JSON.stringify(detail)} })); true;`;
}
