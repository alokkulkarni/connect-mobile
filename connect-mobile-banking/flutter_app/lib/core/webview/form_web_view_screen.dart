import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../features/assistant/domain/conversation.dart';
import '../../features/assistant/domain/form_bridge.dart';
import '../../features/assistant/presentation/assistant_providers.dart';
import '../../features/assistant/presentation/assistant_sheet.dart';
import '../theme/tokens.dart';
import 'form_request.dart';

// A shared form (the mortgage application, a dispute) in a WebView locked to the bank's own pages
// (docs/CONTRACT.md section 9, rule S6): only https pages from the allowed origins load here; anything else opens in
// the system browser. The only script the app adds is the bridge shim, and only on those pages. The form's own
// assistant helps here (the native launcher is hidden), until web changes W1 to W4 let the app's conversation join.
class FormWebViewScreen extends ConsumerStatefulWidget {
  const FormWebViewScreen({super.key, required this.request});

  final FormRequest? request;

  @override
  ConsumerState<FormWebViewScreen> createState() => _FormWebViewScreenState();
}

class _FormWebViewScreenState extends ConsumerState<FormWebViewScreen> {
  WebViewController? _controller;
  StreamSubscription<String>? _scripts;
  bool _loading = true;
  bool _ranAfterLoad = false;

  bool _allowed(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.scheme == 'https' && widget.request!.allowedOrigins.contains(originOf(uri));
  }

  @override
  void initState() {
    super.initState();
    final request = widget.request;
    if (request == null) return;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('NativeBridge', onMessageReceived: _bridge)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (nav) {
          if (_allowed(nav.url)) return NavigationDecision.navigate;
          final uri = Uri.tryParse(nav.url);
          if (uri != null && uri.scheme == 'https') launchUrl(uri, mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        },
        onPageFinished: (url) async {
          if (!mounted) return;
          setState(() => _loading = false);
          if (!_allowed(url)) return;
          await _controller?.runJavaScript(bridgeShim);
          if (!_ranAfterLoad && request.afterLoad.isNotEmpty) {
            _ranAfterLoad = true;
            await _controller?.runJavaScript(request.afterLoad);
          }
        },
      ));
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setAllowFileAccess(false);
    }
    controller.loadRequest(request.url);
    _controller = controller;
    // The app → page events (the form's call has started).
    _scripts = ref.read(assistantControllerProvider).formScripts.listen((script) async {
      final url = await _controller?.currentUrl();
      if (url != null && _allowed(url)) await _controller?.runJavaScript(script);
    });
  }

  // page → app: the mortgage form's "Call us". Only from the bank's own page, only a well-formed request.
  Future<void> _bridge(JavaScriptMessage message) async {
    if (!(widget.request?.mortgage ?? false)) return;
    final url = await _controller?.currentUrl();
    if (url == null || !_allowed(url)) return;
    final call = mortgageCallFromBridge(message.message);
    if (call == null) return;
    await ref.read(assistantControllerProvider).start(ConversationKind.call, from: call, fromForm: true);
  }

  @override
  void dispose() {
    _scripts?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return Scaffold(
      appBar: AppBar(title: Text(request?.title ?? 'Form')),
      body: Column(children: [
        Expanded(
          child: request == null || _controller == null
              ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Open the form again from its screen.')))
              : Stack(children: [
                  WebViewWidget(controller: _controller!),
                  if (_loading) const LinearProgressIndicator(),
                ]),
        ),
        const _LiveBar(),
      ]),
    );
  }
}

/// The launcher is hidden here, so a conversation going on still shows, to open or end it.
class _LiveBar extends ConsumerWidget {
  const _LiveBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(assistantControllerProvider.select((a) => a.kind));
    if (kind == null) return const SizedBox.shrink();
    final c = context.bank;
    return Material(
      color: c.brand,
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: () => showAssistantSheet(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              LiveDot(color: c.moneyIn),
              const SizedBox(width: 10),
              Expanded(
                child: Text(kind == ConversationKind.call ? 'On a call with us' : 'In a chat with us',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
              const Text('Open', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }
}
