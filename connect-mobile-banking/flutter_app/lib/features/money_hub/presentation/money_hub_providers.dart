import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/money_hub_repository_impl.dart';
import '../domain/money_hub.dart';

final moneyHubRepositoryProvider = Provider<MoneyHubRepository>((ref) => MoneyHubRepositoryImpl(ref.watch(transportProvider)));

final moneyHubProvider = FutureProvider<MoneyHub>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(moneyHubRepositoryProvider).hub();
});
