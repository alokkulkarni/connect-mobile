import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/transactions_repository_impl.dart';
import '../domain/transactions.dart';

final transactionsRepositoryProvider =
    Provider<TransactionsRepository>((ref) => TransactionsRepositoryImpl(ref.watch(transportProvider)));

final merchantPlacesProvider = FutureProvider<List<MerchantPlaceRule>>(
    (ref) => BundledMerchantPlaces(ref.watch(fixtureLoaderProvider)).rules());

/// One transaction by its ID (for a notification, or a reopened screen).
final transactionByIdProvider = FutureProvider.family<Transaction?, String>((ref, id) {
  ref.watch(dataVersionProvider);
  return findTransaction(ref.watch(transactionsRepositoryProvider), id);
});
