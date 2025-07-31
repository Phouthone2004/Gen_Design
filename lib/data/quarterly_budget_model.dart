// data/quarterly_budget_model.dart

class QuarterlyBudgetModel {
  final int? id;
  final int parentId; // ID ของ ItemModel หลัก
  final int quarterNumber;
  final double amountKip;
  final double amountThb;
  final double amountUsd;
  final DateTime? selectedDate;

  QuarterlyBudgetModel({
    this.id,
    required this.parentId,
    required this.quarterNumber,
    required this.amountKip,
    required this.amountThb,
    required this.amountUsd,
    this.selectedDate,
  });

  QuarterlyBudgetModel copyWith({
    int? id,
    int? parentId,
    int? quarterNumber,
    double? amountKip,
    double? amountThb,
    double? amountUsd,
    DateTime? selectedDate,
  }) {
    return QuarterlyBudgetModel(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      quarterNumber: quarterNumber ?? this.quarterNumber,
      amountKip: amountKip ?? this.amountKip,
      amountThb: amountThb ?? this.amountThb,
      amountUsd: amountUsd ?? this.amountUsd,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'parentId': parentId,
        'quarterNumber': quarterNumber,
        'amountKip': amountKip,
        'amountThb': amountThb,
        'amountUsd': amountUsd,
        'selectedDate': selectedDate?.toIso8601String(),
      };

  static QuarterlyBudgetModel fromMap(Map<String, Object?> json) =>
      QuarterlyBudgetModel(
        id: json['id'] as int?,
        parentId: json['parentId'] as int,
        quarterNumber: json['quarterNumber'] as int,
        amountKip: (json['amountKip'] as num?)?.toDouble() ?? 0.0,
        amountThb: (json['amountThb'] as num?)?.toDouble() ?? 0.0,
        amountUsd: (json['amountUsd'] as num?)?.toDouble() ?? 0.0,
        selectedDate: json['selectedDate'] != null
            ? DateTime.parse(json['selectedDate'] as String)
            : null,
      );
}
