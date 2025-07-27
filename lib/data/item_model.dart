import 'package:flutter/material.dart';

class ItemModel {
  final int? id;
  final String title;
  final String description;
  final double amount;
  final IconData? selectedIcon;
  final DateTime? selectedDate;
  final int isPinned;
  final int? pinTimestamp;
  final int? lastActivityTimestamp;
  /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
  final int sortOrder; // เพิ่มเข้ามาเพื่อเก็บลำดับการจัดเรียง
  /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */

  ItemModel({
    this.id,
    required this.title,
    required this.description,
    required this.amount,
    this.selectedIcon,
    this.selectedDate,
    required this.isPinned,
    this.pinTimestamp,
    this.lastActivityTimestamp,
    /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
    required this.sortOrder,
    /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
  });

  ItemModel copyWith({
    int? id,
    String? title,
    String? description,
    double? amount,
    IconData? selectedIcon,
    DateTime? selectedDate,
    int? isPinned,
    int? pinTimestamp,
    int? lastActivityTimestamp,
    /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
    int? sortOrder,
    /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
  }) =>
      ItemModel(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        amount: amount ?? this.amount,
        selectedIcon: selectedIcon ?? this.selectedIcon,
        selectedDate: selectedDate ?? this.selectedDate,
        isPinned: isPinned ?? this.isPinned,
        pinTimestamp: pinTimestamp ?? this.pinTimestamp,
        lastActivityTimestamp: lastActivityTimestamp ?? this.lastActivityTimestamp,
        /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
        sortOrder: sortOrder ?? this.sortOrder,
        /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'amount': amount,
        'selectedIcon': selectedIcon?.codePoint,
        'selectedDate': selectedDate?.toIso8601String(),
        'isPinned': isPinned,
        'pinTimestamp': pinTimestamp,
        'lastActivityTimestamp': lastActivityTimestamp,
        /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
        'sortOrder': sortOrder,
        /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
      };

  static ItemModel fromMap(Map<String, Object?> json) => ItemModel(
        id: json['id'] as int?,
        title: json['title'] as String,
        description: json['description'] as String,
        amount: json['amount'] as double,
        selectedIcon: json['selectedIcon'] != null
            ? IconData(json['selectedIcon'] as int, fontFamily: 'MaterialIcons')
            : null,
        selectedDate: json['selectedDate'] != null
            ? DateTime.parse(json['selectedDate'] as String)
            : null,
        isPinned: json['isPinned'] as int,
        pinTimestamp: json['pinTimestamp'] as int?,
        lastActivityTimestamp: json['lastActivityTimestamp'] as int?,
        /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
        sortOrder: json['sortOrder'] as int,
        /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
      );
}
