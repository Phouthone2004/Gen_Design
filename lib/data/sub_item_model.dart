class SubItemModel {
  final int? id;
  final int parentId;
  final String title;
  final String? description;
  final double? quantity;
  final String? unit;
  final double? laborCost;
  final String? laborCostCurrency; // สกุลเงินค่าแรง
  final double? materialCost;
  final String? materialCostCurrency; // สกุลเงินค่าวัสดุ
  final DateTime? selectedDate;

  SubItemModel({
    this.id,
    required this.parentId,
    required this.title,
    this.description,
    this.quantity,
    this.unit,
    this.laborCost,
    this.laborCostCurrency,
    this.materialCost,
    this.materialCostCurrency,
    this.selectedDate,
  });

  SubItemModel copyWith({
    int? id,
    int? parentId,
    String? title,
    String? description,
    double? quantity,
    String? unit,
    double? laborCost,
    String? laborCostCurrency,
    double? materialCost,
    String? materialCostCurrency,
    DateTime? selectedDate,
  }) {
    return SubItemModel(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      title: title ?? this.title,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      laborCost: laborCost ?? this.laborCost,
      laborCostCurrency: laborCostCurrency ?? this.laborCostCurrency,
      materialCost: materialCost ?? this.materialCost,
      materialCostCurrency: materialCostCurrency ?? this.materialCostCurrency,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'parentId': parentId,
        'title': title,
        'description': description,
        'quantity': quantity,
        'unit': unit,
        'laborCost': laborCost,
        'laborCostCurrency': laborCostCurrency,
        'materialCost': materialCost,
        'materialCostCurrency': materialCostCurrency,
        'selectedDate': selectedDate?.toIso8601String(),
      };

  static SubItemModel fromMap(Map<String, Object?> json) => SubItemModel(
        id: json['id'] as int?,
        parentId: json['parentId'] as int,
        title: json['title'] as String,
        description: json['description'] as String?,
        quantity: (json['quantity'] as num?)?.toDouble(),
        unit: json['unit'] as String?,
        laborCost: (json['laborCost'] as num?)?.toDouble(),
        laborCostCurrency: json['laborCostCurrency'] as String?,
        materialCost: (json['materialCost'] as num?)?.toDouble(),
        materialCostCurrency: json['materialCostCurrency'] as String?,
        selectedDate: json['selectedDate'] != null
            ? DateTime.parse(json['selectedDate'] as String)
            : null,
      );
}
