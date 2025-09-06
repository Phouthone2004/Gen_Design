import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../core/app_styles.dart';

class PdfPreviewPage extends StatelessWidget {
  final Uint8List pdfBytes;
  final String fileName;

  const PdfPreviewPage({
    super.key,
    required this.pdfBytes,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ຕົວຢ່າງເອກະສານ'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => pdfBytes,
        /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
        // ปิดการแสดงผล Action และปุ่มตั้งค่าทั้งหมดที่อยู่ด้านล่าง
        allowPrinting: false,
        allowSharing: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
        /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
        canDebug: false,
        loadingWidget: const CircularProgressIndicator(),
        onError: (context, error) {
          debugPrint('PDF Preview error: $error');
          return const Center(child: Text('ບໍ່ສາມາດເບິ່ງ PDF ໄດ້'));
        },
      ),
    );
  }
}
