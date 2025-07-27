import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/home_vm.dart';
import '../core/app_styles.dart';
import '../widget/add_edit_item_dialog.dart';
import '../widget/home_content.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<HomeViewModel>(context);

    /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
    // รื้อโครงสร้างใหม่ทั้งหมด
    return Scaffold(
      // เอา AppBar และ BottomAppBar ออก
      body: const HomeContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showAddItemDialog(context, vm);
        },
        // ใช้ Gradient กับปุ่มบวก
        child: Ink(
          decoration: const BoxDecoration(
            gradient: headerGradient,
            borderRadius: BorderRadius.all(Radius.circular(16.0)),
          ),
          child: Container(
            constraints: const BoxConstraints(minWidth: 56.0, minHeight: 56.0),
            alignment: Alignment.center,
            child: const Icon(Icons.add, color: AppColors.textOnPrimary),
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4.0,
      ),
    );
    /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
  }
}
