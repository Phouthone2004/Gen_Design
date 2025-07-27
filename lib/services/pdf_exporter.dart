import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../data/item_model.dart';
import '../data/sub_item_model.dart';

class PdfExporter {
  static Future<void> generateAndPrintPdf(ItemModel parentItem, List<SubItemModel> subItems) async {
    final pdf = pw.Document();

    final fontData = await rootBundle.load("assets/fonts/Saysettha_OT.ttf");
    final ttf = pw.Font.ttf(fontData);
    final laoStyle = pw.TextStyle(font: ttf, fontSize: 10);
    final laoStyleBold = pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildPdfHeader(parentItem, laoStyle, laoStyleBold),
            pw.SizedBox(height: 20),
            _buildPdfTable(subItems, laoStyle, laoStyleBold), // <-- ส่วนที่แก้ไข
            pw.SizedBox(height: 20),
            _buildPdfFooter(parentItem, subItems, laoStyle, laoStyleBold),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

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

  /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข (ทั้งฟังก์ชัน) ▼ ------------------ */
  // สร้างตารางข้อมูลหลัก (เวอร์ชันแก้ไข)
  static pw.Widget _buildPdfTable(List<SubItemModel> items, pw.TextStyle style, pw.TextStyle styleBold) {
    final headers = ['ລາຍການ', 'ຈຳນວນ', 'ຄ່າແຮງ', 'ຄ່າວັດສະດຸ', 'ລາຄາລວມ', 'ໝາຍເຫດ'];

    // 1. สร้าง Header Row
    final headerRow = pw.TableRow(
      children: List.generate(headers.length, (index) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(5),
          alignment: pw.Alignment.center,
          // กำหนดเส้นขอบของ Header ให้มีครบทุกด้าน
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

    // 2. สร้าง Data Rows
    final dataRows = items.asMap().entries.map<pw.TableRow>((entry) {
      final rowIndex = entry.key;
      final item = entry.value;
      final totalCost = (item.laborCost ?? 0) + (item.materialCost ?? 0);

      // จัดตำแหน่งของแต่ละคอลัมน์
      final cellAlignments = {
        0: pw.Alignment.centerLeft,   // ລາຍການ
        1: pw.Alignment.center,       // ຈຳນວນ
        2: pw.Alignment.centerRight,  // ຄ່າແຮງ
        3: pw.Alignment.centerRight,  // ຄ່າວັດສະດຸ
        4: pw.Alignment.centerRight,  // ລາຄາລວມ
        5: pw.Alignment.centerLeft,   // ໝາຍເຫດ
      };

      // สร้าง Widget ของข้อมูลแต่ละช่อง
      final List<pw.Widget> rowChildren = [
        _buildItemColumn(rowIndex + 1, item, style, styleBold),
        pw.Text('${item.quantity ?? '-'} ${item.unit ?? ''}', style: style),
        pw.Text(item.laborCost != null ? NumberFormat("#,##0").format(item.laborCost) : '-', style: style),
        pw.Text(item.materialCost != null ? NumberFormat("#,##0").format(item.materialCost) : '-', style: style),
        pw.Text(NumberFormat("#,##0").format(totalCost), style: style),
        pw.Text('', style: style),
      ];

      return pw.TableRow(
        // กำหนดเส้นขอบของแถวข้อมูล
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            // มีแค่เส้นแนวนอนคั่นระหว่างรายการเท่านั้น
            bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey700),
          ),
        ),
        children: List.generate(rowChildren.length, (colIndex) {
          // หุ้มแต่ละช่องด้วย Container เพื่อจัดตำแหน่งและ Padding
          // โดยไม่มีเส้นขอบแนวตั้ง
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            alignment: cellAlignments[colIndex],
            child: rowChildren[colIndex],
          );
        }),
      );
    }).toList();

    // 3. ประกอบร่างเป็น Table
    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(1.2),
        5: pw.FlexColumnWidth(1.5),
      },
      children: [headerRow, ...dataRows],
    );
  }
  /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */

  static pw.Widget _buildItemColumn(int index, SubItemModel item, pw.TextStyle style, pw.TextStyle styleBold) {
    final descriptionLines = (item.description ?? '')
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => pw.Text('  o  $line', style: style.copyWith(fontSize: 9)))
        .toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.start,
      children: [
        pw.Text('$index. ${item.title}', style: styleBold),
        if (descriptionLines.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2, left: 5),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: descriptionLines,
            ),
          ),
      ],
    );
  }

  static pw.Widget _buildPdfFooter(ItemModel parentItem, List<SubItemModel> subItems, pw.TextStyle style, pw.TextStyle styleBold) {
    final totalSubItemsCost = subItems.fold(0.0, (sum, e) => sum + (e.laborCost ?? 0) + (e.materialCost ?? 0));
    final remainingAmount = parentItem.amount - totalSubItemsCost;

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('ລວມຄ່າໃຊ້ຈ່າຍທັງໝົດ: ${NumberFormat("#,##0.##").format(totalSubItemsCost)} ກີບ', style: style),
            pw.Text('ງົບປະມານ: ${NumberFormat("#,##0.##").format(parentItem.amount)} ກີບ', style: style),
            pw.Divider(height: 8),
            pw.Text('ຍອດຄົງເຫຼືອ: ${NumberFormat("#,##0.##").format(remainingAmount)} ກີບ', style: styleBold.copyWith(fontSize: 12)),
          ]
        )
      ]
    );
  }
}
