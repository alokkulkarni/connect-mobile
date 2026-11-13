import 'package:flutter/material.dart';

import '../format/money.dart';
import '../network/api_transport.dart';
import '../theme/tokens.dart';

// Building blocks every screen shares: the demo banner, cards, merchant tiles, payment rows, and loading and error
// states.

/// "Demo · sample data", as on every page of the web app. In Sample mode, [onSignIn] offers the way back to the
/// sign-in screen to paste the internet banking link.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key, this.sample = false, this.onSignIn});

  final bool sample;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final c = context.bank;
    final words = Text(
      sample ? 'Demo · sample data on this phone only' : 'Demo · sample data',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.ink),
    );
    return Container(
      width: double.infinity,
      color: c.flexible.withValues(alpha: 0.16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: onSignIn == null
          ? Semantics(label: 'Demo app with sample data', child: words)
          : Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
              words,
              TextButton(
                onPressed: onSignIn,
                style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8), foregroundColor: c.brand2),
                child: const Text('Sign in with your link ›', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ]),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.trailing, required this.child, this.padding = const EdgeInsets.all(16)});

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  Expanded(child: Text(title!, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                  ?trailing,
                ]),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

/// A merchant's initials on a soft tile.   [lib.js initialsTile]
class MerchantTile extends StatelessWidget {
  const MerchantTile(this.name, {super.key, this.moneyIn = false, this.size = 40});

  final String name;
  final bool moneyIn;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.bank;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: moneyIn ? c.moneyInSoft : c.brand2.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(size / 3.2),
        ),
        child: Text(initials(name), style: TextStyle(fontWeight: FontWeight.w700, fontSize: size * 0.36, color: moneyIn ? c.moneyIn : c.brand2)),
      ),
    );
  }
}

/// An amount in green with + when money comes in, − when it goes out.
class AmountText extends StatelessWidget {
  const AmountText(this.amount, {super.key, required this.moneyIn, this.style});

  final double amount;
  final bool moneyIn;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final c = context.bank;
    return Text(
      signed(amount, moneyIn: moneyIn),
      style: (style ?? const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))
          .copyWith(color: moneyIn ? c.moneyIn : c.ink, fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}

/// One payment: the merchant's tile, its name, category and date, and the amount.   [home.js paymentRow]
class PaymentRow extends StatelessWidget {
  const PaymentRow({
    super.key,
    required this.merchantName,
    required this.category,
    required this.date,
    required this.amount,
    required this.moneyIn,
    this.onTap,
    this.trailing,
  });

  final String merchantName, category, date;
  final double amount;
  final bool moneyIn;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.bank;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Row(children: [
          MerchantTile(merchantName, moneyIn: moneyIn),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(merchantName, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('$category · ${day(date)}', style: TextStyle(color: c.muted, fontSize: 13)),
            ]),
          ),
          const SizedBox(width: 8),
          trailing ?? AmountText(amount.abs(), moneyIn: moneyIn),
        ]),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
}

class ErrorView extends StatelessWidget {
  const ErrorView(this.error, {super.key, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final words = error is ApiException ? (error as ApiException).message : 'Something went wrong. Try again.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_outlined, size: 40, color: context.bank.muted),
          const SizedBox(height: 12),
          Text(words, textAlign: TextAlign.center),
          if (onRetry != null) ...[const SizedBox(height: 16), OutlinedButton(onPressed: onRetry, child: const Text('Try again'))],
        ]),
      ),
    );
  }
}

/// Room at the bottom of scrolling screens for the assistant launcher.
const launcherClearance = SizedBox(height: 96);
