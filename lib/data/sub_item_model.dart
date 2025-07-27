// data/sub_item_model.dart

class SubItemModel {
  final int? id;
  final int parentId; // ID ของรายการหลัก
  final String title;
  final String? description;
  final double? quantity;
  final String? unit;
  final double? laborCost;
  final double? materialCost;
  final DateTime? selectedDate;

  SubItemModel({
    this.id,
    required this.parentId,
    required this.title,
    this.description,
    this.quantity,
    this.unit,
    this.laborCost,
    this.materialCost,
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
    double? materialCost,
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
      materialCost: materialCost ?? this.materialCost,
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
        'materialCost': materialCost,
        'selectedDate': selectedDate?.toIso8601String(),
      };

  static SubItemModel fromMap(Map<String, Object?> json) => SubItemModel(
        id: json['id'] as int?,
        parentId: json['parentId'] as int,
        title: json['title'] as String,
        description: json['description'] as String?,
        quantity: json['quantity'] as double?,
        unit: json['unit'] as String?,
        laborCost: json['laborCost'] as double?,
        materialCost: json['materialCost'] as double?,
        selectedDate: json['selectedDate'] != null
            ? DateTime.parse(json['selectedDate'] as String)
            : null,
      );
}
