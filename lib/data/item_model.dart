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
      );
}
