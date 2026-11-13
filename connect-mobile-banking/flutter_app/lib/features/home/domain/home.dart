import '../../accounts/domain/accounts.dart';
import '../../cards/domain/cards.dart';

// Everything Home shows, in one call (app/home), and what the rest of the app needs from it: whether chat and
// calls are on, whether the link is verified, and the dispute pages' address to recognise in a chat.

class HomeSummary {
  const HomeSummary({
    required this.firstName,
    required this.asOf,
    required this.accounts,
    required this.recent,
    required this.cards,
    required this.talk,
    required this.verified,
    required this.disputePagesUrl,
  });

  final String firstName;
  final String asOf;
  final List<Account> accounts;
  final List<Movement> recent;
  final List<BankCard> cards;
  final bool talk;
  final bool verified;
  final String disputePagesUrl;
}

abstract interface class HomeRepository {
  Future<HomeSummary> home();
}

/// "Good morning", "Good afternoon" or "Good evening", with the customer's name when known.   [home.js]
String greeting(DateTime now, String firstName) {
  final words = now.hour < 12 ? 'Good morning' : now.hour < 18 ? 'Good afternoon' : 'Good evening';
  return firstName.isEmpty ? words : '$words, $firstName';
}
