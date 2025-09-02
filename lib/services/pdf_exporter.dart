import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:collection/collection.dart';

import '../data/item_model.dart';
import '../data/quarterly_budget_model.dart';
import '../data/sub_item_model.dart';
import '../presentation/core/app_currencies.dart';

class PdfExporter {
  static Future<Uint8List> generatePdfBytes(
    ItemModel parentItem,
    List<SubItemModel> topLevelSubItems,
    Map<int?, List<SubItemModel>> hierarchy,
    Map<int, Map<String, dynamic>> calculatedTotals,
    List<QuarterlyBudgetModel> quarterlyBudgets,
  ) async {
    final pdf = pw.Document();

    final fontData = await rootBundle.load("assets/fonts/Saysettha_OT.ttf");
    final ttf = pw.Font.ttf(fontData);
    final laoStyle = pw.TextStyle(font: ttf, fontSize: 10);
    final laoStyleBold = pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold);

    final grandTotalCosts = { for (var c in Currency.values) c.code : 0.0 };
    for (final topItem in topLevelSubItems) {
      final totals = calculatedTotals[topItem.id];
      if (totals != null) {
        (totals['costs'] as Map<String, double>).forEach((currency, cost) {
          grandTotalCosts[currency] = (grandTotalCosts[currency] ?? 0) + cost;
        });
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildPdfHeader(parentItem, quarterlyBudgets, grandTotalCosts, laoStyle, laoStyleBold),
            pw.SizedBox(height: 20),
            _buildPdfTable(topLevelSubItems, hierarchy, calculatedTotals, laoStyle, laoStyleBold),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateCombinedPdfBytes(
    List<ItemModel> items,
    List<SubItemModel> allSubItems,
    List<QuarterlyBudgetModel> allQuarterlyBudgets,
  ) async {
    final pdf = pw.Document();

    final fontData = await rootBundle.load("assets/fonts/Saysettha_OT.ttf");
    final ttf = pw.Font.ttf(fontData);
    final laoStyle = pw.TextStyle(font: ttf, fontSize: 10);
    final laoStyleBold = pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold);
    
    final allSubItemsGrouped = groupBy(allSubItems, (SubItemModel i) => i.parentId);
    final allBudgetsGrouped = groupBy(allQuarterlyBudgets, (QuarterlyBudgetModel i) => i.parentId);

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final subItemsForItem = allSubItemsGrouped[item.id] ?? [];
      final hierarchy = <int?, List<SubItemModel>>{};
      for (final subItem in subItemsForItem) {
        hierarchy.putIfAbsent(subItem.childOf, () => []).add(subItem);
      }
      hierarchy.forEach((key, value) {
        value.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      });
      
      final topLevelSubItems = hierarchy[null] ?? [];
      final calculatedTotals = <int, Map<String, dynamic>>{};
      for (final subItem in topLevelSubItems) {
         _calculateRecursiveTotals(subItem, hierarchy, calculatedTotals);
      }
      
      final grandTotalCosts = { for (var c in Currency.values) c.code : 0.0 };
      for (final topSubItem in topLevelSubItems) {
        final totals = calculatedTotals[topSubItem.id];
        if (totals != null) {
          (totals['costs'] as Map<String, double>).forEach((currency, cost) {
            grandTotalCosts[currency] = (grandTotalCosts[currency] ?? 0) + cost;
          });
        }
      }
      
      final budgetsForItem = allBudgetsGrouped[item.id] ?? [];

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              _buildPdfHeader(item, budgetsForItem, grandTotalCosts, laoStyle, laoStyleBold),
              pw.SizedBox(height: 20),
              _buildPdfTable(topLevelSubItems, hierarchy, calculatedTotals, laoStyle, laoStyleBold),
            ];
          },
        ),
      );
    }

    return pdf.save();
  }
  static pw.Widget _buildPdfHeader(
    ItemModel item, 
    List<QuarterlyBudgetModel> quarterlyBudgets,
    Map<String, double> totalCosts,
    pw.TextStyle style, 
    pw.TextStyle styleBold
  ) {
    final totalBudgetMap = { for (var c in Currency.values) c.code : 0.0 };
    for (var budget in quarterlyBudgets) {
      totalBudgetMap[Currency.KIP.code] = (totalBudgetMap[Currency.KIP.code] ?? 0) + budget.amountKip;
      totalBudgetMap[Currency.THB.code] = (totalBudgetMap[Currency.THB.code] ?? 0) + budget.amountThb;
      totalBudgetMap[Currency.USD.code] = (totalBudgetMap[Currency.USD.code] ?? 0) + budget.amountUsd;
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(item.title, style: styleBold.copyWith(fontSize: 24)),
        pw.SizedBox(height: 5),
        pw.Text(item.description, style: style.copyWith(fontSize: 12)),
        pw.Divider(height: 20),
        
        pw.Text('ລາຍລະອຽດງົບປະມານ:', style: styleBold.copyWith(fontSize: 14)),
        pw.SizedBox(height: 8),
        _buildBudgetsTable(quarterlyBudgets, style, styleBold),

        pw.SizedBox(height: 15),

        // pw.Text('ສະຫຼຸບລວມ:', style: styleBold.copyWith(fontSize: 14)),
        pw.SizedBox(height: 8),
        _buildSummaryTable(totalBudgetMap, totalCosts, style, styleBold), // เปลี่ยนมาใช้ฟังก์ชันตาราง
      ],
    );
  }
  static pw.Widget _buildBudgetsTable(List<QuarterlyBudgetModel> budgets, pw.TextStyle style, pw.TextStyle styleBold) {
    if (budgets.isEmpty) return pw.Text('ບໍ່ມີຂໍ້ມູນງົບປະມານ', style: style);

    final headers = ['ງວດທີ່', 'ຈຳນວນເງິນ', 'ວັນທີ/ໝາຍເຫດ'];
    
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(3),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: headers.map((header) => pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(header, style: styleBold, textAlign: pw.TextAlign.center),
          )).toList(),
        ),
        ...budgets.map((budget) {
          final amountWidgets = <pw.Widget>[];
          if (budget.amountKip > 0) amountWidgets.add(pw.Text('${NumberFormat("#,##0.##").format(budget.amountKip)} ${Currency.KIP.laoName}', style: style));
          if (budget.amountThb > 0) amountWidgets.add(pw.Text('${NumberFormat("#,##0.##").format(budget.amountThb)} ${Currency.THB.laoName}', style: style));
          if (budget.amountUsd > 0) amountWidgets.add(pw.Text('${NumberFormat("#,##0.##").format(budget.amountUsd)} ${Currency.USD.laoName}', style: style));

          final notesWidgets = <pw.Widget>[];
          if(budget.selectedDate != null) notesWidgets.add(pw.Text('ວັນທີ: ${DateFormat('dd/MM/yyyy').format(budget.selectedDate!)}', style: style));
          if(budget.notes != null && budget.notes!.isNotEmpty) notesWidgets.add(pw.Text(budget.notes!, style: style));


          return pw.TableRow(
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(budget.quarterNumber.toString(), style: style, textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: amountWidgets)),
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: notesWidgets)),
            ]
          );
        })
      ]
    );
  }

  /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
  // สร้าง Widget ใหม่สำหรับสร้าง "ตาราง" สรุปยอด
  static pw.Widget _buildSummaryTable(Map<String, double> totalBudget, Map<String, double> totalCosts, pw.TextStyle style, pw.TextStyle styleBold) {
    final currencies = [Currency.KIP, Currency.THB, Currency.USD];
    
    // Header Row
    final headerWidgets = <pw.Widget>[pw.Text('ລາຍການ', style: styleBold, textAlign: pw.TextAlign.center)];
    headerWidgets.addAll(
      currencies.map((c) => pw.Text(c.laoName, style: styleBold, textAlign: pw.TextAlign.center))
    );

    // Data Rows
    final rows = <pw.TableRow>[];
    final rowTitles = ['ງົບປະມານ', 'ລວມຄ່າໃຊ້ຈ່າຍ', 'ຍອດຄົງເຫຼືອ'];
    
    for (int i=0; i < rowTitles.length; i++) {
      final title = rowTitles[i];
      final rowCells = <pw.Widget>[pw.Text(title, style: i == 2 ? styleBold : style)];

      for (final currency in currencies) {
        final budget = totalBudget[currency.code] ?? 0.0;
        final cost = totalCosts[currency.code] ?? 0.0;
        double value;
        if (i == 0) { // Budget
          value = budget;
        } else if (i == 1) { // Cost
          value = cost;
        } else { // Remaining
          value = budget - cost;
        }
        rowCells.add(pw.Text(NumberFormat("#,##0.##").format(value), style: i == 2 ? styleBold : style, textAlign: pw.TextAlign.right));
      }
      rows.add(pw.TableRow(children: rowCells.map((cell) => pw.Padding(padding: const pw.EdgeInsets.all(4), child: cell)).toList()));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(1.5),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: headerWidgets.map((header) => pw.Padding(padding: const pw.EdgeInsets.all(4), child: header)).toList()
        ),
        ...rows
      ],
    );
  }
  
  static pw.Widget _buildPdfTable(
    List<SubItemModel> topLevelItems,
    Map<int?, List<SubItemModel>> hierarchy,
    Map<int, Map<String, dynamic>> calculatedTotals,
    pw.TextStyle style,
    pw.TextStyle styleBold,
  ) {
    final headers = ['ລາຍການ', 'ຈຳນວນ', 'ລາຍລະອຽດຄ່າໃຊ້ຈ່າຍ', 'ລາຄາລວມ', 'ໝາຍເຫດ'];

    // เราไม่จำเป็นต้องกำหนด border ใน header row อีกต่อไป เพราะจะกำหนดที่ Table หลัก
    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: List.generate(headers.length, (index) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(5),
          alignment: pw.Alignment.center,
          child: pw.Text(headers[index], style: styleBold),
        );
      }),
    );
 
    final dataRows = _buildPdfRowsRecursive(topLevelItems, hierarchy, calculatedTotals, 0, style, styleBold);

    return pw.Table(
      // กำหนดเส้นตารางทั้งหมดที่นี่ที่เดียว
      border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(2.5),
        3: pw.FlexColumnWidth(1.8),
        4: pw.FlexColumnWidth(1.5),
      },
      children: [headerRow, ...dataRows],
    );
  }

  static List<pw.TableRow> _buildPdfRowsRecursive(
    List<SubItemModel> items,
    Map<int?, List<SubItemModel>> hierarchy,
    Map<int, Map<String, dynamic>> calculatedTotals,
    int level,
    pw.TextStyle style,
    pw.TextStyle styleBold,
  ) {
    final List<pw.TableRow> rows = [];

    for (final item in items) {
      final totals = calculatedTotals[item.id] ?? {'quantity': 0.0, 'costs': {}};
      final totalCostsMap = totals['costs'] as Map<String, double>;
    
      final totalCostWidgets = <pw.Widget>[];
      totalCostsMap.forEach((currencyCode, cost) {
        if (cost > 0) {
          final currency = CurrencyExtension.fromCode(currencyCode);
          totalCostWidgets.add(
            pw.Text(
              '${NumberFormat("#,##0.##").format(cost)} ${currency.laoName}',
              style: style,
            )
          );
        }
      });
      
      final costDetailWidgets = item.costs.map((cost) {
        if (cost.amount <= 0) return pw.SizedBox.shrink();
        final currency = CurrencyExtension.fromCode(cost.currency);
        return pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('${cost.description}:', style: style.copyWith(fontSize: 9)),
            pw.Text(
              '${NumberFormat("#,##0.##").format(cost.amount)} ${currency.laoName}',
              style: style.copyWith(fontSize: 9),
            ),
          ],
        );
      }).toList();

      final cellAlignments = {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerLeft,
      };

      final List<pw.Widget> rowChildren = [
        _buildItemColumn(item, level, style, styleBold),
        pw.Text('${totals['quantity'] ?? '-'} ${item.unit ?? ''}', style: style),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: costDetailWidgets.isNotEmpty ? costDetailWidgets : [pw.Text('-', style: style)],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: totalCostWidgets.isNotEmpty ? totalCostWidgets : [pw.Text('-', style: style)],
        ),
        pw.Text('', style: style), // หมายเหตุ
      ];

      rows.add(
        pw.TableRow(
          // ไม่ต้องกำหนด border ที่นี่แล้ว
          children: List.generate(rowChildren.length, (colIndex) {
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              alignment: cellAlignments[colIndex],
              child: rowChildren[colIndex],
            );
          }),
        ),
      );

      final children = hierarchy[item.id] ?? [];
      if (children.isNotEmpty) {
        rows.addAll(_buildPdfRowsRecursive(children, hierarchy, calculatedTotals, level + 1, style, styleBold));
      }
    }
    return rows;
  }
  /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */

  static pw.Widget _buildItemColumn(SubItemModel item, int level, pw.TextStyle style, pw.TextStyle styleBold) {
    final descriptionLines = (item.description ?? '')
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => pw.Text('  o  $line', style: style.copyWith(fontSize: 9)))
        .toList();

    return pw.Padding(
      padding: pw.EdgeInsets.only(left: level * 15.0),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.start,
        children: [
          pw.Text(item.title, style: styleBold),
          if (descriptionLines.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2, left: 5),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: descriptionLines,
              ),
            ),
        ],
      ),
    );
  }
  
  static Map<String, dynamic> _calculateRecursiveTotals(
    SubItemModel item,
    Map<int?, List<SubItemModel>> hierarchy,
    Map<int, Map<String, dynamic>> calculatedTotals,
  ) {
    if (calculatedTotals.containsKey(item.id)) {
      return calculatedTotals[item.id]!;
    }

    double totalQuantity = item.quantity ?? 0;
    final totalCosts = { for (var c in Currency.values) c.code : 0.0 };

    for (final cost in item.costs) {
      totalCosts[cost.currency] = (totalCosts[cost.currency] ?? 0) + cost.amount;
    }

    final children = hierarchy[item.id] ?? [];
    for (final child in children) {
      final childTotals = _calculateRecursiveTotals(child, hierarchy, calculatedTotals);
      totalQuantity += childTotals['quantity'] as double;
      (childTotals['costs'] as Map<String, double>).forEach((currency, cost) {
        totalCosts[currency] = (totalCosts[currency] ?? 0) + cost;
      });
    }

    final result = {'quantity': totalQuantity, 'costs': totalCosts};
    calculatedTotals[item.id!] = result;
    return result;
  }
}
