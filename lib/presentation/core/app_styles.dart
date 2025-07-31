import 'package:flutter/material.dart';

// --- คลาสสำหรับเก็บค่าสีหลักของแอป ---
class AppColors {
  /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
  static const Color primaryDark = Color(0xFF081c15); // เขียวเข้มเกือบดำ
  static const Color primary = Color(0xFF1B4332); // เขียวเข้ม (Old Money)
  static const Color primaryLight = Color(0xFF2d6a4f); // เขียวสว่าง
  /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */

  static const Color accent = Color(0xFFD4AF37); // ทอง (สำหรับปักหมุด)
  static const Color background = Color(0xFFF8F9FA); // ขาวนวล
  static const Color textPrimary = Color(0xFF333333); // เทาเข้ม
  static const Color textSecondary = Color(0xFF6c757d); // เทา
  static const Color textOnPrimary = Colors.white; // ขาว
  static const Color danger = Colors.red;
}

/* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
// --- ไล่ระดับสีสำหรับ Header ---
const LinearGradient headerGradient = LinearGradient(
  colors: [
    AppColors.primaryDark,
    AppColors.primary,
    AppColors.primaryLight,
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
/* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */


// --- คลาสสำหรับเก็บสไตล์ตัวอักษร ---
class AppTextStyles {
  static const String fontFamily = 'Saysettha OT';

  static const TextStyle subText = TextStyle(
    fontFamily: fontFamily,
    color: Color.fromARGB(122, 255, 255, 255),
    fontSize: 14,
    // fontWeight: FontWeight.bold,
  );

  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.textOnPrimary,
    fontSize: 36,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle subheading = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.textOnPrimary,
    fontSize: 18,
    fontWeight: FontWeight.normal,
  );
  
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.textSecondary,
    fontSize: 14,
  );

   static const TextStyle bodyBold = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );
}

// --- คลาสสำหรับสร้าง Theme หลักของแอป ---
class AppTheme {
  static ThemeData getTheme() {
    return ThemeData(
      useMaterial3: true,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppTextStyles.fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        background: AppColors.background,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
      ),
    );
  }
}
