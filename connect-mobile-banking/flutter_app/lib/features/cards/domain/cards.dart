// The customer's cards, their recent card payments (the card dispute service's own list, so the payment chosen is
// the one the dispute assistant finds) and their disputes. connect-banking-app/web/pages/cards.js.

class BankCard {
  const BankCard({required this.type, required this.ending, required this.name});

  final String type; // debit or credit
  final String ending;
  final String name;

  bool get isDebit => type == 'debit';
}

class CardPayment {
  const CardPayment({
    required this.id,
    required this.date,
    required this.merchant,
    required this.amount,
    required this.card,
    required this.ending,
  });

  final String id; // TXN-<card ending>-<yyyymmdd>-<pence>
  final String date;
  final String merchant;
  final double amount; // positive
  final String card; // debit or credit
  final String ending;
}

class CardsView {
  const CardsView({required this.cards, required this.payments});

  final List<BankCard> cards;
  final List<CardPayment> payments;

  CardPayment? payment(String id) => payments.where((p) => p.id == id).firstOrNull;
}

class Dispute {
  const Dispute({
    required this.disputeId,
    required this.status,
    required this.statusWords,
    required this.merchant,
    required this.amount,
    required this.transactionDate,
    required this.cardType,
    required this.cardLastFour,
    required this.missing,
    required this.open,
    required this.canSubmit,
    required this.transactionId,
  });

  final String disputeId;
  final String status;
  final String statusWords;
  final String merchant;
  final double amount;
  final String transactionDate;
  final String cardType;
  final String cardLastFour;
  final List<String> missing;
  final bool open;
  final bool canSubmit;
  final String transactionId;
}

abstract interface class CardsRepository {
  Future<CardsView> cards();
  Future<List<Dispute>> disputes();

  /// The customer submits their own complete draft (the dispute service's rule R11).
  Future<void> submitDispute(String disputeId);
}
