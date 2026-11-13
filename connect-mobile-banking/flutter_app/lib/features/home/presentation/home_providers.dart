import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/home_repository_impl.dart';
import '../domain/home.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) => HomeRepositoryImpl(ref.watch(transportProvider)));

/// app/home: the greeting, accounts, latest payments, and whether chat and calls are on.
final homeSummaryProvider = FutureProvider<HomeSummary>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(homeRepositoryProvider).home();
});
