import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/di/providers.dart';
import '../data/cards_repository_impl.dart';
import '../domain/cards.dart';

final cardsRepositoryProvider = Provider<CardsRepository>((ref) => CardsRepositoryImpl(ref.watch(transportProvider)));

final cardsViewProvider = FutureProvider<CardsView>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(cardsRepositoryProvider).cards();
});

final disputesProvider = FutureProvider<List<Dispute>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(cardsRepositoryProvider).disputes();
});

/// The card payment the customer chose to dispute, while it's the Cards screen's context. Shared, because a
/// transaction's details and a notification can choose it too.   [app.js shared.disputePayment]
class CardsSelection extends ChangeNotifier {
  CardPayment? chosen;

  void choose(CardPayment? payment) {
    chosen = payment;
    notifyListeners();
  }
}

final cardsSelectionProvider = ChangeNotifierProvider<CardsSelection>((ref) => CardsSelection());
