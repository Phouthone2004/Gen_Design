import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../data/item_model.dart';
import '../../logic/home_vm.dart';
import '../core/app_currencies.dart';

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

  bool showCalendar = existingItem?.selectedDate != null;
  DateTime? selectedDate = existingItem?.selectedDate;

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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                    CheckboxListTile(
                      title: const Text("ສະແດງວັນທີ"),
                      value: showCalendar,
                      onChanged: (bool? value) {
                        setState(() {
                          showCalendar = value!;
                          if (!showCalendar) {
                            selectedDate = null;
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (showCalendar)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: Text(selectedDate == null ? 'ເລືອກວັນທີ' : DateFormat('dd MMMM yyyy').format(selectedDate!)),
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2101),);
                          if (picked != null && picked != selectedDate) {
                            setState(() { selectedDate = picked; });
                          }
                        },
                      ),
                  ],
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
                      /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
                      // แก้ไขโดยการสร้าง Instance ใหม่ เพื่อให้ค่า null ถูกบันทึกได้ถูกต้อง
                      final updatedItem = ItemModel(
                        id: existingItem.id,
                        title: titleController.text,
                        description: descriptionController.text,
                        amount: amountKip,
                        amountThb: amountThb,
                        amountUsd: amountUsd,
                        selectedDate: selectedDate, // ส่งค่า null ไปได้เมื่อติ๊กออก
                        // คงค่าเดิมที่ไม่ถูกแก้ไขใน dialog
                        sortOrder: existingItem.sortOrder,
                        creationTimestamp: existingItem.creationTimestamp,
                        lastActivityTimestamp: existingItem.lastActivityTimestamp,
                      );
                      /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
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

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) return newValue;
    final String newText = newValue.text.replaceAll(',', '');
    if (newText.isEmpty) return newValue.copyWith(text: '');
    final double value = double.parse(newText);
    final formatter = NumberFormat("#,##0", "en_US");
    final String formattedText = formatter.format(value);
    return newValue.copyWith(text: formattedText, selection: TextSelection.collapsed(offset: formattedText.length));
  }
}
