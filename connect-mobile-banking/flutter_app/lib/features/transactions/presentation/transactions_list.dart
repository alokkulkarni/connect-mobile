import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/widgets/common.dart';
import '../../assistant/domain/screen_context.dart';
import '../../assistant/presentation/screen_context_scope.dart';
import '../domain/transactions.dart';
import 'transactions_providers.dart';

// The current account's transactions, newest first, 25 at a time: search by merchant, money in or out. Each opens
// its details at [detailPath]. Used on its own (Home › Transactions) and as the Money Hub's Transactions tab.
class TransactionsList extends ConsumerStatefulWidget {
  const TransactionsList({super.key, required this.detailPath});

  final String Function(String id) detailPath;

  @override
  ConsumerState<TransactionsList> createState() => _TransactionsListState();
}

class _TransactionsListState extends ConsumerState<TransactionsList> {
  final _rows = <Transaction>[];
  final _search = TextEditingController();
  String _direction = '';
  int _page = 0;
  bool _more = true, _loading = false;
  Object? _error;
  Timer? _debounce;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _reload() {
    _generation++;
    _rows.clear();
    _page = 0;
    _more = true;
    _error = null;
    _loading = false;
    scheduleMicrotask(_next);
  }

  Future<void> _next() async {
    if (!mounted || _loading || !_more) return;
    final generation = _generation;
    setState(() => _loading = true);
    try {
      final page = await ref.read(transactionsRepositoryProvider).list(
            TransactionFilter(merchant: _search.text.trim(), direction: _direction),
            page: _page + 1,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _rows.addAll(page.transactions);
        _page = page.page;
        _more = page.hasMore;
      });
    } catch (e) {
      if (mounted && generation == _generation) setState(() => _error = e);
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(dataVersionProvider, (_, _) => _reload()); // the assistant may have moved a payment
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) _next();
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: _rows.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) return _filters();
          if (i == _rows.length + 1) {
            if (_error != null) return ErrorView(_error!, onRetry: _next);
            if (_loading) return const LoadingView();
            if (_rows.isEmpty) return const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No transactions match.')));
            return const SizedBox(height: 16);
          }
          final t = _rows[i - 1];
          return PaymentRow(
            merchantName: t.merchantName,
            category: t.categoryWords,
            date: t.date,
            amount: t.amount,
            moneyIn: t.moneyIn,
            onTap: () => context.go(widget.detailPath(t.id), extra: t),
          );
        },
      ),
    );
  }

  Widget _filters() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(children: [
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by merchant', isDense: true),
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), () => setState(_reload));
            },
          ),
          const SizedBox(height: 8),
          Row(children: [
            for (final (key, label) in [('', 'All'), ('in', 'Money in'), ('out', 'Money out')]) ...[
              ChoiceChip(
                label: Text(label),
                selected: _direction == key,
                onSelected: (_) => setState(() {
                  _direction = key;
                  _reload();
                }),
              ),
              const SizedBox(width: 8),
            ],
          ]),
        ]),
      );
}

/// Home › Transactions.
class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) => ScreenContextScope(
        screen: const ScreenContext(page: 'money_hub', view: 'transactions', label: 'Transactions', launcher: 'Ask about your money'),
        child: Scaffold(
          appBar: AppBar(title: const Text('Transactions')),
          body: TransactionsList(detailPath: (id) => '/home/transactions/$id'),
        ),
      );
}
