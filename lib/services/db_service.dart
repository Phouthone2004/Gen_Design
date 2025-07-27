import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../data/item_model.dart';
import '../data/sub_item_model.dart';

class DBService {
  static final DBService instance = DBService._init();
  static Database? _database;
  DBService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('items.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 5, 
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onConfigure: _onConfigure,
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const doubleType = 'REAL NOT NULL';
    const integerType = 'INTEGER';
    const dateType = 'TEXT';
    const boolType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE items (
        id $idType,
        title $textType,
        description $textType,
        amount $doubleType,
        selectedIcon $integerType,
        selectedDate $dateType,
        isPinned $boolType,
        pinTimestamp $integerType,
        lastActivityTimestamp $integerType,
        sortOrder $integerType
      )
    ''');
    
    await db.execute('''
      CREATE TABLE sub_items (
        id $idType,
        parentId INTEGER NOT NULL,
        title $textType,
        description TEXT,
        quantity REAL,
        unit TEXT,
        laborCost REAL,
        materialCost REAL,
        selectedDate $dateType,
        FOREIGN KEY (parentId) REFERENCES items(id) ON DELETE CASCADE
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE items ADD COLUMN isPinned INTEGER NOT NULL DEFAULT 0");
      await db.execute("ALTER TABLE items ADD COLUMN pinTimestamp INTEGER");
    }
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE items ADD COLUMN lastActivityTimestamp INTEGER");
    }
    if (oldVersion < 4) {
      await db.execute("ALTER TABLE items ADD COLUMN sortOrder INTEGER NOT NULL DEFAULT 0");
      final items = await db.query('items', columns: ['id']);
      final batch = db.batch();
      for (var i = 0; i < items.length; i++) {
        batch.update('items', {'sortOrder': i}, where: 'id = ?', whereArgs: [items[i]['id']]);
      }
      await batch.commit(noResult: true);
    }
    if (oldVersion < 5) {
      const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
      const textType = 'TEXT NOT NULL';
      const dateType = 'TEXT';
      await db.execute('''
        CREATE TABLE sub_items (
          id $idType,
          parentId INTEGER NOT NULL,
          title $textType,
          description TEXT,
          quantity REAL,
          unit TEXT,
          laborCost REAL,
          materialCost REAL,
          selectedDate $dateType,
          FOREIGN KEY (parentId) REFERENCES items(id) ON DELETE CASCADE
        )
      ''');
    }
  }

  // --- CRUD for Items ---
  Future<ItemModel> create(ItemModel item) async {
    final db = await instance.database;
    final id = await db.insert('items', item.toMap());
    return item.copyWith(id: id);
  }

  Future<List<ItemModel>> readAllItems() async {
    final db = await instance.database;
    final result = await db.query('items', orderBy: 'isPinned DESC, sortOrder ASC');
    return result.map((json) => ItemModel.fromMap(json)).toList();
  }

  Future<int> update(ItemModel item) async {
    final db = await instance.database;
    return db.update('items', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }
  
  Future<void> updateSortOrder(List<ItemModel> items) async {
    final db = await instance.database;
    final batch = db.batch();
    for (int i = 0; i < items.length; i++) {
      if (items[i].isPinned == 0) {
        batch.update('items', {'sortOrder': i}, where: 'id = ?', whereArgs: [items[i].id]);
      }
    }
    await batch.commit(noResult: true);
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, Object?>> readItemAsMap(int id) async {
    final db = await instance.database;
    final maps = await db.query('items', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isNotEmpty) {
      return maps.first;
    } else {
      throw Exception('ID $id not found');
    }
  }

  // --- CRUD for SubItems ---
  Future<SubItemModel> createSubItem(SubItemModel subItem) async {
    final db = await instance.database;
    final id = await db.insert('sub_items', subItem.toMap());
    return subItem.copyWith(id: id);
  }

  Future<List<SubItemModel>> readSubItemsForParent(int parentId) async {
    final db = await instance.database;
    final result = await db.query('sub_items',
        where: 'parentId = ?', whereArgs: [parentId], orderBy: 'id ASC');
    return result.map((json) => SubItemModel.fromMap(json)).toList();
  }

  Future<int> updateSubItem(SubItemModel subItem) async {
    final db = await instance.database;
    return db.update('sub_items', subItem.toMap(), where: 'id = ?', whereArgs: [subItem.id]);
  }

  Future<int> deleteSubItem(int id) async {
    final db = await instance.database;
    return await db.delete('sub_items', where: 'id = ?', whereArgs: [id]);
  }

  /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
  // ฟังก์ชันใหม่สำหรับคำนวณยอดรวมของ sub-items ทั้งหมดในครั้งเดียว
  Future<Map<int, double>> getAllSubItemsTotalCost() async {
    final db = await instance.database;
    // ใช้ rawQuery เพื่อคำนวณผลรวมของค่าใช้จ่ายโดยจัดกลุ่มตาม parentId
    final List<Map<String, Object?>> result = await db.rawQuery('''
      SELECT 
        parentId, 
        SUM(COALESCE(laborCost, 0) + COALESCE(materialCost, 0)) as total
      FROM sub_items
      GROUP BY parentId
    ''');

    // แปลงผลลัพธ์เป็น Map<int, double>
    final Map<int, double> costs = {
      for (var row in result)
        (row['parentId'] as int): (row['total'] as double? ?? 0.0)
    };
    return costs;
  }
  /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
