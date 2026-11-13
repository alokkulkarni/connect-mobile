// The mortgage products the application lists (the mortgage service's own illustrative catalogue: rates are
// examples, not offers), and the application form, which stays a web page (docs/CONTRACT.md section 9).

class MortgageProduct {
  const MortgageProduct({required this.id, required this.name, required this.rate, required this.fee, required this.maxLtv, required this.fixedTermYears});

  final String id, name;
  final double rate, fee;
  final int maxLtv, fixedTermYears;
}

abstract interface class MortgagesRepository {
  Future<List<MortgageProduct>> products();
}

/// The mortgage stages the form's bridge may name (connect-banking-app/bankapp/journeys.py MORTGAGE_STAGES).
const mortgageStages = {
  'about_you': 'About you',
  'property_loan': 'Property and loan',
  'dip_result': 'Decision in Principle',
  'product_selection': 'Choose a product',
  'documents': 'Documents',
  'review_submit': 'Review and submit',
};

/// The mortgage page's own application ID format.
final mortgageApplicationId = RegExp(r'^MA-[A-HJ-NP-Z2-9]{8}$');
