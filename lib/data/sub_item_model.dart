// data/sub_item_model.dart

import 'dart:convert';
import 'cost_model.dart';

class SubItemModel {
  final int? id;
  final int parentId; // ID ของ ItemModel (โปรเจกต์หลัก)
  final int? childOf; // ID ของ SubItemModel ที่เป็นแม่
  final String title;
  final String? description;
  final double? quantity;
  final String? unit;
  final DateTime? selectedDate;
  final List<CostModel> costs;
  /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
  final int sortOrder; // เพิ่ม field สำหรับจัดลำดับ
  /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */

  SubItemModel({
    this.id,
    required this.parentId,
    this.childOf,
    required this.title,
    this.description,
    this.quantity,
    this.unit,
    this.selectedDate,
    List<CostModel>? costs,
    /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
    required this.sortOrder,
    /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
  }) : costs = costs ?? [];

  SubItemModel copyWith({
    int? id,
    int? parentId,
    int? childOf,
    String? title,
    String? description,
    double? quantity,
    String? unit,
    DateTime? selectedDate,
    List<CostModel>? costs,
    /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
    int? sortOrder,
    /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
  }) {
    return SubItemModel(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      childOf: childOf ?? this.childOf,
      title: title ?? this.title,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      selectedDate: selectedDate ?? this.selectedDate,
      costs: costs ?? this.costs,
      /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
      sortOrder: sortOrder ?? this.sortOrder,
      /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'parentId': parentId,
        'childOf': childOf,
        'title': title,
        'description': description,
        'quantity': quantity,
        'unit': unit,
        'selectedDate': selectedDate?.toIso8601String(),
        'costs': json.encode(costs.map((cost) => cost.toMap()).toList()),
        /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
        'sortOrder': sortOrder,
        /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
      };

  static SubItemModel fromMap(Map<String, Object?> json) {
    List<CostModel> costs = [];
    if (json['costs'] != null) {
      final List<dynamic> decodedCosts = jsonDecode(json['costs'] as String);
      costs = decodedCosts.map((costMap) => CostModel.fromMap(costMap)).toList();
    }

    return SubItemModel(
      id: json['id'] as int?,
      parentId: json['parentId'] as int,
      childOf: json['childOf'] as int?,
      title: json['title'] as String,
      description: json['description'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      selectedDate: json['selectedDate'] != null
          ? DateTime.parse(json['selectedDate'] as String)
          : null,
      costs: costs,
      /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
      // ถ้าข้อมูลเก่าไม่มี sortOrder ให้ใช้ id แทนไปก่อน
      sortOrder: json['sortOrder'] as int? ?? (json['id'] as int? ?? 0),
      /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
    );
  }
}
