// data/settings_model.dart

import 'dart:convert';

class SettingsModel {
  final String? logoImagePath;
  final String mainTitle;
  final String subTitle;
  final String? backgroundImagePath;
  final bool useDefaultBackground;
  /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
  final bool isMainTitleVisible;
  final bool isSubTitleVisible;
  /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */

  SettingsModel({
    this.logoImagePath,
    this.mainTitle = 'My Project',
    this.subTitle = 'Budget Overview',
    this.backgroundImagePath,
    this.useDefaultBackground = true,
    /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
    this.isMainTitleVisible = true,
    this.isSubTitleVisible = true,
    /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
  });

  SettingsModel copyWith({
    String? logoImagePath,
    String? mainTitle,
    String? subTitle,
    String? backgroundImagePath,
    bool? useDefaultBackground,
    /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
    bool? isMainTitleVisible,
    bool? isSubTitleVisible,
    /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
    bool setLogoToNull = false,
    bool setBackgroundToNull = false,
  }) {
    return SettingsModel(
      logoImagePath: setLogoToNull ? null : logoImagePath ?? this.logoImagePath,
      mainTitle: mainTitle ?? this.mainTitle,
      subTitle: subTitle ?? this.subTitle,
      backgroundImagePath: setBackgroundToNull ? null : backgroundImagePath ?? this.backgroundImagePath,
      useDefaultBackground: useDefaultBackground ?? this.useDefaultBackground,
      /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
      isMainTitleVisible: isMainTitleVisible ?? this.isMainTitleVisible,
      isSubTitleVisible: isSubTitleVisible ?? this.isSubTitleVisible,
      /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'logoImagePath': logoImagePath,
      'mainTitle': mainTitle,
      'subTitle': subTitle,
      'backgroundImagePath': backgroundImagePath,
      'useDefaultBackground': useDefaultBackground,
      /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
      'isMainTitleVisible': isMainTitleVisible,
      'isSubTitleVisible': isSubTitleVisible,
      /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
    };
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      logoImagePath: map['logoImagePath'],
      mainTitle: map['mainTitle'] ?? 'My Project',
      subTitle: map['subTitle'] ?? 'Budget Overview',
      backgroundImagePath: map['backgroundImagePath'],
      useDefaultBackground: map['useDefaultBackground'] ?? true,
      /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
      isMainTitleVisible: map['isMainTitleVisible'] ?? true,
      isSubTitleVisible: map['isSubTitleVisible'] ?? true,
      /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
    );
  }

  String toJson() => json.encode(toMap());

  factory SettingsModel.fromJson(String source) => SettingsModel.fromMap(json.decode(source));
}
