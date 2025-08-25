import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../data/item_model.dart';
import '../../logic/home_vm.dart';
import '../core/app_currencies.dart';
import '../core/app_styles.dart';

enum DateSelectionOption { none, today, manual }

Future<void> showAddItemDialog(
  BuildContext context,
  HomeViewModel vm, {
  ItemModel? existingItem,
}) async {
  final formKey = GlobalKey<FormState>();

  String _getOriginalTitle(String? fullTitle) {
    if (fullTitle == null) return '';
    int dotIndex = fullTitle.indexOf('. ');
    if (dotIndex != -1 && dotIndex < 3) {
      return fullTitle.substring(dotIndex + 2);
    }
    return fullTitle;
  }

  final titleController = TextEditingController(text: _getOriginalTitle(existingItem?.title));
  final descriptionController = TextEditingController(text: existingItem?.description);

  final amountKipController = TextEditingController(
    text: existingItem != null && existingItem.amount > 0
        ? NumberFormat("#,##0").format(existingItem.amount)
        : '',
  );
  final amountThbController = TextEditingController(
    text: existingItem != null && existingItem.amountThb > 0
        ? NumberFormat("#,##0").format(existingItem.amountThb)
        : '',
  );
  final amountUsdController = TextEditingController(
    text: existingItem != null && existingItem.amountUsd > 0
        ? NumberFormat("#,##0").format(existingItem.amountUsd)
        : '',
  );

  DateTime? selectedDate = existingItem?.selectedDate;
  DateSelectionOption dateSelectionOption = DateSelectionOption.none;
  if (selectedDate != null) {
    dateSelectionOption = DateSelectionOption.manual;
  }

  return showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(existingItem == null ? 'ເພິ້ມລາຍການໃໝ່' : 'ແກ້ໄຂລາຍການ'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'ຫົວຂໍ້', icon: Icon(Icons.title)),
                        validator: (v) => v!.isEmpty ? 'ກະລຸນາໄສຫົວຂໍ້' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(labelText: 'ຄຳອະທິບາຍ', icon: Icon(Icons.description)),
                        validator: (v) => v!.isEmpty ? 'ກະລຸນາໄສຄຳອະທິບາຍ' : null,
                      ),
                      const Divider(height: 24),
                      TextFormField(
                        controller: amountKipController,
                        decoration: InputDecoration(labelText: 'ງົບປະມານ (${Currency.KIP.laoName})', icon: Text(Currency.KIP.symbol, style: const TextStyle(fontSize: 18))),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
                      ),
                      TextFormField(
                        controller: amountThbController,
                        decoration: InputDecoration(labelText: 'ງົບປະມານ (${Currency.THB.laoName})', icon: Text(Currency.THB.symbol, style: const TextStyle(fontSize: 18))),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
                      ),
                      TextFormField(
                        controller: amountUsdController,
                        decoration: InputDecoration(labelText: 'ງົບປະມານ (${Currency.USD.laoName})', icon: Text(Currency.USD.symbol, style: const TextStyle(fontSize: 18))),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
                      ),
                      const Divider(height: 24),
                      const Text('ຕັ້ງຄ່າວັນທີ', style: AppTextStyles.bodyBold),
                      Column(
                        children: [
                          RadioListTile<DateSelectionOption>(
                            title: const Text('ບໍ່ລະບຸວັນທີ'),
                            value: DateSelectionOption.none,
                            groupValue: dateSelectionOption,
                            onChanged: (value) {
                              setState(() {
                                dateSelectionOption = value!;
                                selectedDate = null;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                          RadioListTile<DateSelectionOption>(
                            title: const Text('ໃຊ້ວັນທີປັດຈຸບັນ'),
                            value: DateSelectionOption.today,
                            groupValue: dateSelectionOption,
                            onChanged: (value) {
                              setState(() {
                                dateSelectionOption = value!;
                                selectedDate = DateTime.now();
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                          RadioListTile<DateSelectionOption>(
                            title: const Text('ເລືອກດ້ວຍຕົວເອງ'),
                            value: DateSelectionOption.manual,
                            groupValue: dateSelectionOption,
                            onChanged: (value) {
                              setState(() {
                                dateSelectionOption = value!;
                                if (existingItem?.selectedDate == null) {
                                  selectedDate = null;
                                }
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      if (dateSelectionOption == DateSelectionOption.today && selectedDate != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                          child: Text(
                            'วันที่ที่เลือก: ${DateFormat('dd MMMM yyyy', 'lo').format(selectedDate!)}',
                            style: AppTextStyles.body.copyWith(color: AppColors.primary),
                          ),
                        ),
                      if (dateSelectionOption == DateSelectionOption.manual)
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.calendar_today),
                                label: const Text('ເລືອກວັນທີ'),
                                onPressed: () async {
                                  final DateTime? picked = await showDatePicker(
                                    context: context,
                                    locale: const Locale('lo'),
                                    initialDate: selectedDate ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2101),
                                  );
                                  if (picked != null && picked != selectedDate) {
                                    setState(() {
                                      selectedDate = picked;
                                    });
                                  }
                                },
                              ),
                              if (selectedDate != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'วันที่ที่เลือก: ${DateFormat('dd MMMM yyyy', 'lo').format(selectedDate!)}',
                                  style: AppTextStyles.body.copyWith(color: AppColors.primary),
                                ),
                              ]
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('ຍົກເລີກ'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final cleanAmountKip = amountKipController.text.replaceAll(',', '');
                    final cleanAmountThb = amountThbController.text.replaceAll(',', '');
                    final cleanAmountUsd = amountUsdController.text.replaceAll(',', '');

                    final double amountKip = double.tryParse(cleanAmountKip) ?? 0.0;
                    final double amountThb = double.tryParse(cleanAmountThb) ?? 0.0;
                    final double amountUsd = double.tryParse(cleanAmountUsd) ?? 0.0;
                  
                    if (existingItem == null) {
                      final newItem = ItemModel(
                        title: titleController.text,
                        description: descriptionController.text,
                        amount: amountKip,
                        amountThb: amountThb,
                        amountUsd: amountUsd,
                        selectedDate: selectedDate,
                        sortOrder: 0,
                      );
                      vm.addItem(newItem);
                    } else {
                      final updatedItem = ItemModel(
                        id: existingItem.id,
                        title: titleController.text,
                        description: descriptionController.text,
                        amount: amountKip,
                        amountThb: amountThb,
                        amountUsd: amountUsd,
                        selectedDate: selectedDate,
                        sortOrder: existingItem.sortOrder,
                        creationTimestamp: existingItem.creationTimestamp,
                        lastActivityTimestamp: existingItem.lastActivityTimestamp,
                      );
                      vm.updateItem(updatedItem);
                    }
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('ບັນທຶກ'),
              ),
            ],
          );
        },
      );
    },
  );
}

/* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข (ทั้งคลาส) ▼ ------------------ */
// แก้ไข Logic ของ Formatter ใหม่ทั้งหมดเพื่อแก้ปัญหาเคอร์เซอร์ดีด
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // ถ้าผู้ใช้ลบหมด ให้ return ค่าว่าง
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // แปลงค่าใหม่เป็นตัวเลขดิบ (ไม่มี comma)
    final String newText = newValue.text.replaceAll(',', '');

    // ถ้าค่าใหม่ไม่ใช่ตัวเลข หรือเป็นค่าว่างหลังจากลบ comma ให้ใช้ค่าเก่า
    if (newText.isEmpty || int.tryParse(newText) == null) {
      return oldValue;
    }

    // จัดรูปแบบตัวเลขใหม่
    final formatter = NumberFormat("#,##0", "en_US");
    final String newFormattedText = formatter.format(int.parse(newText));

    // --- ส่วนคำนวณตำแหน่งเคอร์เซอร์ใหม่ ---
    int selectionIndex = newValue.selection.end;
    
    // นับจำนวนตัวเลข (digits) ก่อนถึงตำแหน่งเคอร์เซอร์ในค่าใหม่ที่ผู้ใช้พิมพ์
    int numDigitsBeforeCursor = 0;
    for (int i = 0; i < selectionIndex; i++) {
      if (newValue.text[i] != ',') {
        numDigitsBeforeCursor++;
      }
    }

    // หาตำแหน่งเคอร์เซอร์ใหม่ในข้อความที่จัดรูปแบบแล้ว
    // โดยการวนลูปไปเรื่อยๆ จนกว่าจะเจอจำนวนตัวเลขที่เท่ากับที่เรานับไว้
    int newCursorPosition = 0;
    int digitCount = 0;
    while (newCursorPosition < newFormattedText.length && digitCount < numDigitsBeforeCursor) {
      if (newFormattedText[newCursorPosition] != ',') {
        digitCount++;
      }
      newCursorPosition++;
    }
    
    // กรณีพิเศษ: ถ้าเคอร์เซอร์อยู่ท้ายสุด ให้ย้ายไปท้ายสุดของข้อความใหม่ด้วย
    if (numDigitsBeforeCursor == newText.length) {
      newCursorPosition = newFormattedText.length;
    }

    return TextEditingValue(
      text: newFormattedText,
      selection: TextSelection.collapsed(
        // clamp() เพื่อป้องกันไม่ให้ index เกินขอบเขต
        offset: newCursorPosition.clamp(0, newFormattedText.length),
      ),
    );
  }
}
/* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
