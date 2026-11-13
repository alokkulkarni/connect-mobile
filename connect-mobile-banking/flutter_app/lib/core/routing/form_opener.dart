import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/assistant/domain/form_bridge.dart';
import '../../features/assistant/presentation/assistant_controller.dart';
import '../../features/home/presentation/home_providers.dart';
import '../di/providers.dart';
import '../webview/form_request.dart';
import 'app_router.dart';

// Opening the shared forms (docs/CONTRACT.md section 9). Each is the bank's own web page, with the session's link,
// in the locked WebView. Sample mode has no backend, so no forms.

Set<String> _bankOrigins(Ref ref, Uri origin) {
  final disputes = ref.read(homeSummaryProvider).value?.disputePagesUrl ?? '';
  final parsed = Uri.tryParse(disputes);
  return {originOf(origin), if (disputes.isNotEmpty && parsed != null && parsed.scheme == 'https') originOf(parsed)};
}

/// Mortgages › Start your application: the web app's own form page.
void openMortgageApplication(BuildContext context, WidgetRef ref) {
  final session = ref.read(sessionControllerProvider).session;
  if (session == null || session.isSample) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The application form needs your internet banking link.')));
    return;
  }
  final origin = session.origin!;
  ref.read(routerProvider).push('/form', extra: FormRequest(
    url: origin.replace(path: '/apply/about-you', fragment: 'k=${session.secret}'),
    title: 'Mortgage application',
    allowedOrigins: {originOf(origin)},
    mortgage: true,
  ));
}

/// The dispute form the assistant asked for: the exact link it posted (C9), or the app's own dispute page joined to
/// the form the dispute watch opened (needs web change W3).
void openAssistantForm(Ref ref, FormOpening opening) {
  final session = ref.read(sessionControllerProvider).session;
  if (session == null || session.isSample) return;
  final origin = session.origin!;
  final allowed = _bankOrigins(ref, origin);
  final FormRequest request;
  if (opening.link != null) {
    final url = Uri.tryParse(opening.link!);
    if (url == null || url.scheme != 'https' || !allowed.contains(originOf(url))) return;
    request = FormRequest(url: url, title: 'Your dispute', allowedOrigins: allowed);
  } else {
    request = FormRequest(
      url: origin.replace(path: '/cards/dispute', fragment: 'k=${session.secret}'),
      title: 'Your dispute',
      allowedOrigins: allowed,
      afterLoad: disputeOpenScript(opening.sessionId ?? ''),
    );
  }
  ref.read(routerProvider).push('/form', extra: request);
}
