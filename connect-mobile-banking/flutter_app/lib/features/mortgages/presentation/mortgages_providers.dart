import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/mortgages_repository_impl.dart';
import '../domain/mortgages.dart';

final mortgageProductsProvider = FutureProvider<List<MortgageProduct>>(
    (ref) => MortgagesRepositoryImpl(ref.watch(transportProvider)).products());
