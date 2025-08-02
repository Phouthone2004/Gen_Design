import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../data/item_model.dart';
import '../data/sub_item_model.dart';
import '../presentation/core/app_currencies.dart';

class PdfExporter {
  /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข (ทั้งฟังก์ชัน) ▼ ------------------ */
  // เปลี่ยนชื่อฟังก์ชันจาก generateAndPrintPdf เป็น generateAndSharePdf
  static Future<void> generateAndSharePdf(
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

    // สร้างชื่อไฟล์จากหัวข้อโปรเจกต์
    final String fileName = '${parentItem.title.replaceAll(RegExp(r'[^\w\s]+'), '')}.pdf';

    // เปลี่ยนจาก layoutPdf เป็น sharePdf
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: fileName,
    );
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
    final headers = ['ລາຍການ', 'ຈຳນວນ', 'ຄ່າແຮງ', 'ຄ່າວັດສະດຸ', 'ລາຄາລວມ', 'ໝາຍເຫດ'];

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
        2: pw.FlexColumnWidth(1.5), 
        3: pw.FlexColumnWidth(1.5), 
        4: pw.FlexColumnWidth(1.5), 
        5: pw.FlexColumnWidth(1.5),
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

      final cellAlignments = {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerLeft,
      };

      final List<pw.Widget> rowChildren = [
        _buildItemColumn(item, level, style, styleBold),
        pw.Text('${totals['quantity'] ?? '-'} ${item.unit ?? ''}', style: style),
        item.laborCost != null && item.laborCost! > 0
            ? pw.Text('${NumberFormat("#,##0").format(item.laborCost)} ${CurrencyExtension.fromCode(item.laborCostCurrency!).laoName}', style: style)
            : pw.Text('-', style: style),
        item.materialCost != null && item.materialCost! > 0
            ? pw.Text('${NumberFormat("#,##0").format(item.materialCost)} ${CurrencyExtension.fromCode(item.materialCostCurrency!).laoName}', style: style)
            : pw.Text('-', style: style),
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
