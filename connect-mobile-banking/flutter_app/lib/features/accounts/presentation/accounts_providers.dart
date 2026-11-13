import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/accounts_repository_impl.dart';
import '../domain/accounts.dart';

final accountsRepositoryProvider = Provider<AccountsRepository>((ref) => AccountsRepositoryImpl(ref.watch(transportProvider)));

/// app/accounts for one account (`current` or `savings`).
final accountsViewProvider = FutureProvider.family<AccountsView, String>((ref, account) {
  ref.watch(dataVersionProvider);
  return ref.watch(accountsRepositoryProvider).accounts(account);
});
