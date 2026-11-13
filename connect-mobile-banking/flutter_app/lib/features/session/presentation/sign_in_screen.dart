import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/tokens.dart';

// Sign-in for the demo: the customer's internet banking link stands for them signed in, as on the web
// (docs/CONTRACT.md section 1). Or explore with sample data, with no backend at all.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _link = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) setState(() => _link.text = data!.text!.trim());
  }

  Future<void> _open() async {
    setState(() => _busy = true);
    final error = await ref.read(sessionControllerProvider).signInWithLink(_link.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bank;
    final notice = ref.watch(sessionControllerProvider.select((s) => s.notice));
    return Scaffold(
      backgroundColor: c.brand,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 32, 24, 24), children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Icon(Icons.account_balance, color: c.brand),
            ),
            const SizedBox(width: 12),
            const Text('Nationwide', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          ]),
          const SizedBox(height: 40),
          const Text('Your banking,\nwith help on every screen',
              style: TextStyle(color: Colors.white, fontSize: 30, height: 1.15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text('Chat or call our assistant from anywhere in the app. It knows which screen you\'re on.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 16)),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Open your internet banking', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Paste the link we gave you. It stays on this phone, in its secure storage.', style: TextStyle(color: c.muted)),
                if (notice != null) ...[
                  const SizedBox(height: 12),
                  Text(notice, style: TextStyle(color: c.moneyOut)),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _link,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Your internet banking link',
                    hintText: 'https://…#k=…',
                    errorText: _error,
                    errorMaxLines: 3,
                    suffixIcon: IconButton(tooltip: 'Paste', icon: const Icon(Icons.content_paste), onPressed: _paste),
                  ),
                  onSubmitted: (_) => _open(),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _busy ? null : _open, child: Text(_busy ? 'Opening…' : 'Open my banking')),
                const SizedBox(height: 20),
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(color: c.muted))),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => ref.read(sessionControllerProvider).exploreSample(),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Explore with sample data'),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Demo. Sample data only (James, a fictional customer). Anyone holding the link is treated as James. '
            'Chat and calls need the link; the sample data works without it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
          ),
        ]),
      ),
    );
  }
}
