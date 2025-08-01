// presentation/widget/settings_dialog.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/settings_model.dart';
import '../../logic/home_vm.dart';
import '../core/app_styles.dart';

void showSettingsDialog(BuildContext context, HomeViewModel vm) {
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return SettingsDialog(vm: vm);
    },
  );
}

class SettingsDialog extends StatefulWidget {
  final HomeViewModel vm;
  const SettingsDialog({super.key, required this.vm});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late SettingsModel _currentSettings;
  late TextEditingController _mainTitleController;
  late TextEditingController _subTitleController;
  
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _currentSettings = widget.vm.settings;
    _mainTitleController = TextEditingController(text: _currentSettings.mainTitle);
    _subTitleController = TextEditingController(text: _currentSettings.subTitle);
  }

  Future<void> _pickLogoImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _currentSettings = _currentSettings.copyWith(logoImagePath: image.path);
      });
    }
  }

  Future<void> _pickBackgroundImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _currentSettings = _currentSettings.copyWith(backgroundImagePath: image.path, useDefaultBackground: false);
      });
    }
  }

  void _saveSettings() {
    final newSettings = _currentSettings.copyWith(
      mainTitle: _mainTitleController.text,
      subTitle: _subTitleController.text,
    );
    widget.vm.saveSettings(newSettings);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ຕັ້ງຄ່າ'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo Section
            const Text('ໂລໂກ້ແລະຂໍ້ຄວາມ', style: AppTextStyles.bodyBold),
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: _pickLogoImage,
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _currentSettings.logoImagePath != null
                        ? FileImage(File(_currentSettings.logoImagePath!))
                        : null,
                    child: _currentSettings.logoImagePath == null
                        ? const Icon(Icons.add_a_photo, color: Colors.grey)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                if (_currentSettings.logoImagePath != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                    onPressed: () {
                      setState(() {
                        _currentSettings = _currentSettings.copyWith(setLogoToNull: true);
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _mainTitleController,
                    decoration: const InputDecoration(labelText: 'ຂໍ້ຄວາມຫຼັກ'),
                    enabled: _currentSettings.isMainTitleVisible,
                  ),
                ),
                IconButton(
                  icon: Icon(_currentSettings.isMainTitleVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _currentSettings = _currentSettings.copyWith(isMainTitleVisible: !_currentSettings.isMainTitleVisible);
                    });
                  },
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _subTitleController,
                    decoration: const InputDecoration(labelText: 'ຂໍ້ຄວາມຣອງ'),
                    enabled: _currentSettings.isSubTitleVisible,
                  ),
                ),
                IconButton(
                  icon: Icon(_currentSettings.isSubTitleVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _currentSettings = _currentSettings.copyWith(isSubTitleVisible: !_currentSettings.isSubTitleVisible);
                    });
                  },
                ),
              ],
            ),
            /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
            const Divider(height: 32),

            // Background Section
            const Text('ພື້ນຫຼັງສ່ວນຫົວ', style: AppTextStyles.bodyBold),
            SwitchListTile(
              title: const Text('ໃຊ້ພື້ນຫຼັງເລີ້ມຕົ້ນ (ສີຂຽວ)', style: TextStyle(fontSize: 14)),
              value: _currentSettings.useDefaultBackground,
              onChanged: (value) {
                setState(() {
                  _currentSettings = _currentSettings.copyWith(useDefaultBackground: value);
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            if (!_currentSettings.useDefaultBackground) ...[
              const SizedBox(height: 8),
              const Text('ເລືອກຮູບພາບເບື້ອງຫຼັງ:'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickBackgroundImage,
                child: Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                    image: _currentSettings.backgroundImagePath != null
                        ? DecorationImage(
                            image: FileImage(File(_currentSettings.backgroundImagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _currentSettings.backgroundImagePath == null
                      ? const Center(child: Icon(Icons.add_photo_alternate, color: Colors.grey, size: 40))
                      : null,
                ),
              ),
              if (_currentSettings.backgroundImagePath != null)
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  label: const Text('ລົບຮູປພື້ນຫຼັງ', style: TextStyle(color: AppColors.danger)),
                  onPressed: () {
                    setState(() {
                      _currentSettings = _currentSettings.copyWith(setBackgroundToNull: true, useDefaultBackground: true);
                    });
                  },
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ຍົກເລີກ'),
        ),
        ElevatedButton(
          onPressed: _saveSettings,
          child: const Text('ບັນທຶກ'),
        ),
      ],
    );
  }
}
