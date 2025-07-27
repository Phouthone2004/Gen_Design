import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../data/item_model.dart';
import '../../logic/home_vm.dart';

Future<void> showAddItemDialog(
  BuildContext context,
  HomeViewModel vm, {
  ItemModel? existingItem,
}) async {
  final formKey = GlobalKey<FormState>();
  
  final titleController = TextEditingController(text: existingItem?.title);
  final descriptionController = TextEditingController(text: existingItem?.description);
  final amountController = TextEditingController(
    text: existingItem != null 
          ? NumberFormat("#,##0").format(existingItem.amount) 
          : '',
  );

  bool showCalendar = existingItem?.selectedDate != null;
  bool showIcon = existingItem?.selectedIcon != null;
  DateTime? selectedDate = existingItem?.selectedDate;
  IconData? selectedIcon = existingItem?.selectedIcon;
  
  const List<IconData> constructionIcons = [
    Icons.foundation, Icons.house_siding, Icons.apartment, Icons.carpenter,
    Icons.construction, Icons.square_foot, Icons.architecture, Icons.engineering,
    Icons.design_services, Icons.plumbing, Icons.lightbulb,
    Icons.roofing, Icons.stairs, Icons.fence, Icons.meeting_room,
    Icons.handyman, Icons.gite, Icons.location_city, Icons.home_work,
  ];

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
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: amountController,
                      decoration: const InputDecoration(labelText: 'ຈຳນວນເງິນ (ກີບ)', icon: Icon(Icons.attach_money)),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        CurrencyInputFormatter(),
                      ],
                      validator: (v) => v!.isEmpty ? 'ກະລຸນາໄສຈຳນວນເງິນ' : null,
                    ),
                    const Divider(height: 24),
                    CheckboxListTile(
                      title: const Text("ສະແດງວັນທີ"),
                      value: showCalendar,
                      onChanged: (bool? value) {
                        setState(() {
                          showCalendar = value!;
                          if (!showCalendar) selectedDate = null;
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
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101),
                          );
                          if (picked != null && picked != selectedDate) {
                            setState(() { selectedDate = picked; });
                          }
                        },
                      ),
                    CheckboxListTile(
                      title: const Text("ແກ້ໄຂໄອຄ້ອນ"),
                      value: showIcon,
                      onChanged: (bool? value) {
                        setState(() {
                          showIcon = value!;
                          if (!showIcon) selectedIcon = null;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (showIcon)
                      ElevatedButton.icon(
                        icon: Icon(selectedIcon ?? Icons.add_reaction),
                        label: Text(selectedIcon == null ? 'ເລືອກໄອຄ້ອນ' : 'ປ່ຽນໄອຄອນ'),
                        onPressed: () async {
                          final IconData? pickedIcon = await _showIconPickerDialog(context, constructionIcons, selectedIcon);
                          if (pickedIcon != null) {
                            setState(() { selectedIcon = pickedIcon; });
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
                    final cleanAmountString = amountController.text.replaceAll(',', '');
                    
                    if (existingItem == null) {
                      /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
                      // เพิ่ม sortOrder เข้าไปเพื่อให้ constructor ทำงานได้
                      final newItem = ItemModel(
                        title: titleController.text,
                        description: descriptionController.text,
                        amount: double.parse(cleanAmountString),
                        selectedDate: selectedDate,
                        selectedIcon: selectedIcon,
                        isPinned: 0,
                        sortOrder: 0, // ใส่ค่าเริ่มต้นไปก่อน, ViewModel จะคำนวณค่าที่ถูกต้องให้อีกที
                      );
                      /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
                      vm.addItem(newItem);
                    } else {
                      final updatedItem = existingItem.copyWith(
                        title: titleController.text,
                        description: descriptionController.text,
                        amount: double.parse(cleanAmountString),
                        selectedDate: selectedDate,
                        selectedIcon: selectedIcon,
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

Future<IconData?> _showIconPickerDialog(BuildContext context, List<IconData> icons, IconData? currentIcon) {
  IconData? tempSelectedIcon = currentIcon;

  return showDialog<IconData>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('ເລືອກໄອຄອນ'),
            content: SizedBox(
              width: double.maxFinite,
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: icons.length,
                itemBuilder: (context, index) {
                  final icon = icons[index];
                  final isSelected = tempSelectedIcon == icon;
                  return GestureDetector(
                    onTap: () {
                      setState(() { tempSelectedIcon = icon; });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue.shade100 : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSelected ? Colors.blue.shade700 : Colors.grey.shade300),
                      ),
                      child: Icon(icon, color: isSelected ? Colors.blue.shade800 : Colors.grey.shade800, size: 28),
                    ),
                  );
                },
              ),
            ),
            actions: <Widget>[
              TextButton(child: const Text('ຍົກເລີກ'), onPressed: () => Navigator.of(context).pop()),
              ElevatedButton(child: const Text('ຕົກລົງ'), onPressed: () => Navigator.of(context).pop(tempSelectedIcon)),
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
