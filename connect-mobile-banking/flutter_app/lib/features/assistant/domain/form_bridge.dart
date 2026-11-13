import 'dart:convert';

import '../../mortgages/domain/mortgages.dart';
import 'screen_context.dart';

// The bridge between the mortgage form page (in the WebView) and the app: docs/CONTRACT.md section 9 and
// connect-banking-app/docs/mobile/README.md section 6. The page's "Call us" sends
// startCall({applicationId, stage}); the app checks both, then starts a call joined to that form.

/// The call the form asked for, or null when its message isn't one the app accepts.
ScreenContext? mortgageCallFromBridge(String message) {
  Object? parsed;
  try {
    parsed = jsonDecode(message);
  } catch (_) {
    return null;
  }
  if (parsed is! Map) return null;
  final applicationId = parsed['applicationId'];
  final stage = parsed['stage'];
  if (applicationId is! String || !mortgageApplicationId.hasMatch(applicationId)) return null;
  if (stage is! String || !mortgageStages.containsKey(stage)) return null;
  return ScreenContext(
    page: 'mortgage',
    stage: stage,
    applicationId: applicationId,
    label: 'Mortgage application',
    launcher: 'Help with a mortgage',
  );
}

final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);

/// app → page, once the form's call has started: the event the form listens for (web change W1).
String mortgageCallStartedScript(String contactId) {
  if (!_uuid.hasMatch(contactId)) return '';
  return "window.dispatchEvent(new CustomEvent('mortgage:call-started', {detail: {contactId: ${jsonEncode(contactId)}}}));";
}

/// app → page, for the dispute watch: the event the dispute page listens for (web change W3).
String disputeOpenScript(String sessionId) {
  if (!RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(sessionId)) return '';
  return "window.dispatchEvent(new CustomEvent('dispute:open', {detail: {sessionId: ${jsonEncode(sessionId)}}}));";
}

/// The page-side shim: the mortgage form calls window.AndroidBridge.startCall(json) when it's inside the app; here it
/// posts to the app's NativeBridge channel instead. Defined only on the bank's own pages.
const bridgeShim = '''
(function () {
  if (window.AndroidBridge || !window.NativeBridge) return;
  window.AndroidBridge = { startCall: function (json) { window.NativeBridge.postMessage(String(json)); } };
})();
''';
