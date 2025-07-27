import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io'; 
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // สำหรับ Desktop
import 'logic/home_vm.dart';
import 'presentation/page/app_shell.dart';
import 'presentation/core/app_styles.dart'; // <-- Import ไฟล์สไตล์ใหม่

Future<void> main() async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => HomeViewModel(),
      child: MaterialApp(
        title: 'Money Manager',
        /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
        theme: AppTheme.getTheme(), // <-- ใช้ Theme จากไฟล์กลาง
        /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
        debugShowCheckedModeBanner: false,
        home: const AppShell(),
      ),
    );
  }
}
