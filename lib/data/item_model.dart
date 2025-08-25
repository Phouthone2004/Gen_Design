import 'package:flutter/material.dart';

class ItemModel {
  final int? id;
  final String title;
  final String description;
  final double amount; // KIP (Initial Budget)
  final double amountThb; // THB (Initial Budget)
  final double amountUsd; // USD (Initial Budget)
  final DateTime? selectedDate;
  final int? lastActivityTimestamp;
  final int sortOrder;
  final int? creationTimestamp;
  /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
  final bool isIncludedInTotals; // true = โครงการร่วม, false = โครงการเดี่ยว
  /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */

  ItemModel({
    this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.amountThb,
    required this.amountUsd,
    this.selectedDate,
    this.lastActivityTimestamp,
    required this.sortOrder,
    this.creationTimestamp,
    /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
    this.isIncludedInTotals = true, // กำหนดค่าเริ่มต้นเป็น true
    /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
  });

  ItemModel copyWith({
    int? id,
    String? title,
    String? description,
    double? amount,
    double? amountThb,
    double? amountUsd,
    DateTime? selectedDate,
    int? lastActivityTimestamp,
    int? sortOrder,
    int? creationTimestamp,
    /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
    bool? isIncludedInTotals,
    /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
  }) =>
      ItemModel(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        amount: amount ?? this.amount,
        amountThb: amountThb ?? this.amountThb,
        amountUsd: amountUsd ?? this.amountUsd,
        selectedDate: selectedDate ?? this.selectedDate,
        lastActivityTimestamp: lastActivityTimestamp ?? this.lastActivityTimestamp,
        sortOrder: sortOrder ?? this.sortOrder,
        creationTimestamp: creationTimestamp ?? this.creationTimestamp,
        /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
        isIncludedInTotals: isIncludedInTotals ?? this.isIncludedInTotals,
        /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'amount': amount,
        'amountThb': amountThb,
        'amountUsd': amountUsd,
        'selectedDate': selectedDate?.toIso8601String(),
        'lastActivityTimestamp': lastActivityTimestamp,
        'sortOrder': sortOrder,
        'creationTimestamp': creationTimestamp,
        /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
        'isIncludedInTotals': isIncludedInTotals ? 1 : 0, // แปลง boolean เป็น integer
        /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
      };

  static ItemModel fromMap(Map<String, Object?> json) => ItemModel(
        id: json['id'] as int?,
        title: json['title'] as String,
        description: json['description'] as String,
        amount: json['amount'] as double,
        amountThb: (json['amountThb'] as num?)?.toDouble() ?? 0.0,
        amountUsd: (json['amountUsd'] as num?)?.toDouble() ?? 0.0,
        selectedDate: json['selectedDate'] != null
            ? DateTime.parse(json['selectedDate'] as String)
            : null,
        lastActivityTimestamp: json['lastActivityTimestamp'] as int?,
        sortOrder: json['sortOrder'] as int,
        creationTimestamp: json['creationTimestamp'] as int?,
        /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
        // แปลง integer กลับเป็น boolean (ถ้าไม่มีข้อมูล ให้ถือว่าเป็น true)
        isIncludedInTotals: json['isIncludedInTotals'] == null ? true : json['isIncludedInTotals'] == 1,
        /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
      );
}
