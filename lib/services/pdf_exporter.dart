import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../data/item_model.dart';
import '../data/sub_item_model.dart';
import '../logic/home_vm.dart';
import '../presentation/core/app_currencies.dart';
import 'db_service.dart';

class PdfExporter {
  static Future<Uint8List> generatePdfBytes(
    ItemModel parentItem,
    List<SubItemModel> topLevelSubItems,
    Map<int?, List<SubItemModel>> hierarchy,
    Map<int, Map<String, dynamic>> calculatedTotals,
  ) async {
    final pdf = pw.Document();

    final fontData = await rootBundle.load("assets/fonts/NotoSansLao.ttf");
    final ttf = pw.Font.ttf(fontData);
    final laoStyle = pw.TextStyle(font: ttf, fontSize: 10);
    final laoStyleBold = pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold);

    // Calculate grand totals for the footer
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
            _buildPdfHeader(parentItem, laoStyle, laoStyleBold),
            pw.SizedBox(height: 20),
            _buildPdfTable(topLevelSubItems, hierarchy, calculatedTotals, laoStyle, laoStyleBold),
            pw.SizedBox(height: 20),
            _buildPdfFooter(parentItem, grandTotalCosts, laoStyle, laoStyleBold),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateCombinedPdfBytes(
    List<ItemModel> itemsToExport,
    HomeViewModel vm,
  ) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/Saysettha_OT.ttf");
    final ttf = pw.Font.ttf(fontData);
    final laoStyle = pw.TextStyle(font: ttf, fontSize: 10);
    final laoStyleBold = pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold);

    // ดึงข้อมูล sub-items ทั้งหมดมาครั้งเดียวเพื่อประสิทธิภาพ
    final allSubItems = await DBService.instance.readAllSubItems();
    final groupedSubItems = groupBy(allSubItems, (SubItemModel subItem) => subItem.parentId);

    for (final parentItem in itemsToExport) {
      final subItemsForThisParent = groupedSubItems[parentItem.id] ?? [];

      // สร้างโครงสร้าง hierarchy และคำนวณผลรวมสำหรับโปรเจกต์นี้
      final hierarchy = <int?, List<SubItemModel>>{};
      for (final subItem in subItemsForThisParent) {
        hierarchy.putIfAbsent(subItem.childOf, () => []).add(subItem);
      }
      hierarchy.forEach((key, value) {
        value.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      });

      final calculatedTotals = <int, Map<String, dynamic>>{};
      final topLevelSubItems = hierarchy[null] ?? [];
      for (final item in topLevelSubItems) {
        /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
        // เรียกใช้ฟังก์ชัน private ที่สร้างขึ้นใหม่ในคลาสนี้แทน
        _calculateRecursiveTotalsForPdf(item, hierarchy, calculatedTotals);
        /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
      }

      // คำนวณยอดรวมค่าใช้จ่ายทั้งหมดของโปรเจกต์นี้
      final grandTotalCosts = { for (var c in Currency.values) c.code : 0.0 };
      for (final topItem in topLevelSubItems) {
        final totals = calculatedTotals[topItem.id];
        if (totals != null) {
          (totals['costs'] as Map<String, double>).forEach((currency, cost) {
            grandTotalCosts[currency] = (grandTotalCosts[currency] ?? 0) + cost;
          });
        }
      }

      // เพิ่มหน้าใหม่สำหรับแต่ละโปรเจกต์
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              _buildPdfHeader(parentItem, laoStyle, laoStyleBold),
              pw.SizedBox(height: 20),
              _buildPdfTable(topLevelSubItems, hierarchy, calculatedTotals, laoStyle, laoStyleBold),
              pw.SizedBox(height: 20),
              _buildPdfFooter(parentItem, grandTotalCosts, laoStyle, laoStyleBold),
            ];
          },
        ),
      );
    }

    return pdf.save();
  }

  /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
  // ฟังก์ชันนี้ถูกคัดลอกมาจาก HomeViewModel เพื่อแก้ปัญหาการเข้าถึง private method
  static Map<String, dynamic> _calculateRecursiveTotalsForPdf(
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
      final childTotals = _calculateRecursiveTotalsForPdf(child, hierarchy, calculatedTotals);
      totalQuantity += childTotals['quantity'] as double;
      (childTotals['costs'] as Map<String, double>).forEach((currency, cost) {
        totalCosts[currency] = (totalCosts[currency] ?? 0) + cost;
      });
    }

    final result = {'quantity': totalQuantity, 'costs': totalCosts};
    calculatedTotals[item.id!] = result;
    return result;
  }
  /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */

  static pw.Widget _buildPdfHeader(ItemModel item, pw.TextStyle style, pw.TextStyle styleBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(item.title, style: styleBold.copyWith(fontSize: 24)),
        pw.SizedBox(height: 5),
        pw.Text(item.description, style: style.copyWith(fontSize: 12)),
        pw.Divider(height: 20),
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

    final headerRow = pw.TableRow(
      children: List.generate(headers.length, (index) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(5),
          alignment: pw.Alignment.center,
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(width: 1, color: PdfColors.black),
              bottom: pw.BorderSide(width: 1.5, color: PdfColors.black),
              left: pw.BorderSide(width: 0.5, color: PdfColors.grey700),
              right: pw.BorderSide(width: 0.5, color: PdfColors.grey700),
            ),
          ),
          child: pw.Text(headers[index], style: styleBold),
        );
      }),
    );
 
    final dataRows = _buildPdfRowsRecursive(topLevelItems, hierarchy, calculatedTotals, 0, style, styleBold);

    return pw.Table(
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
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey700),
            ),
          ),
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

  static pw.Widget _buildPdfFooter(ItemModel parentItem, Map<String, double> totalCosts, pw.TextStyle style, pw.TextStyle styleBold) {
   
    final budgetMap = {
      Currency.KIP.code: parentItem.amount,
      Currency.THB.code: parentItem.amountThb,
      Currency.USD.code: parentItem.amountUsd,
    };

    final footerContent = <pw.Widget>[];

    totalCosts.forEach((currencyCode, cost) {
      if (cost > 0 || (budgetMap[currencyCode] ?? 0) > 0) {
        final budget = budgetMap[currencyCode] ?? 0.0;
        final remaining = budget - cost;
        final currency = CurrencyExtension.fromCode(currencyCode);

        footerContent.add(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('ລວມຄ່າໃຊ້ຈ່າຍ (${currency.laoName}): ${NumberFormat("#,##0.##").format(cost)}', style: style),
              pw.Text('ງົບປະມານ (${currency.laoName}): ${NumberFormat("#,##0.##").format(budget)}', style: style),
              pw.Text('ຍອດຄົງເຫຼືອ (${currency.laoName}): ${NumberFormat("#,##0.##").format(remaining)}', style: styleBold.copyWith(fontSize: 11)),
              pw.SizedBox(height: 8),
            ]
          )
        );
      }
    });

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: footerContent,
        )
      ]
    );
  }
}
