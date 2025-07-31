import 'package:flutter/material.dart';

enum Currency { KIP, THB, USD }

extension CurrencyExtension on Currency {
  
  String get symbol {
    switch (this) {
      case Currency.KIP:
        return '₭';
      case Currency.THB:
        return '฿';
      case Currency.USD:
        return '\$';
    }
  }

  String get code {
    return toString().split('.').last;
  }

  String get laoName {
     switch (this) {
      case Currency.KIP:
        return 'ກີບ';
      case Currency.THB:
        return 'ບາດ';
      case Currency.USD:
        return 'ໂດລ້າ';
    }
  }

  Color get progressColor {
    switch (this) {
      case Currency.KIP:
        return Colors.red.shade400;
      case Currency.THB:
        return Colors.blue.shade400;
      case Currency.USD:
        return Colors.green.shade400;
    }
  }

  static Currency fromCode(String code) {
    return Currency.values.firstWhere((c) => c.code == code, orElse: () => Currency.KIP);
  }
}
