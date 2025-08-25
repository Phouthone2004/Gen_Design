// data/cost_model.dart

class CostModel {
  String description;
  double amount;
  String currency;

  CostModel({
    required this.description,
    this.amount = 0.0,
    required this.currency,
  });

  // Factory constructor for creating a new CostModel instance from a map.
  factory CostModel.fromMap(Map<String, dynamic> map) {
    return CostModel(
      description: map['description'] as String,
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'] as String,
    );
  }

  // Method for converting a CostModel instance to a map.
  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'amount': amount,
      'currency': currency,
    };
  }
}
