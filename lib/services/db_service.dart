import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../data/cost_model.dart';
import '../data/item_model.dart';
import '../data/sub_item_model.dart';
import '../data/quarterly_budget_model.dart';
import '../presentation/core/app_currencies.dart';

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
      /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
      version: 17, // เพิ่มเวอร์ชัน DB เป็น 17
      /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
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

    await db.execute('''
      CREATE TABLE items (
        id $idType,
        title $textType,
        description $textType,
        amount $doubleType,
        amountThb $doubleType,
        amountUsd $doubleType,
        selectedDate $dateType,
        lastActivityTimestamp $integerType,
        creationTimestamp $integerType,
        sortOrder $integerType,
        isIncludedInTotals INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE sub_items (
        id $idType,
        parentId INTEGER NOT NULL,
        childOf INTEGER,
        title $textType,
        description TEXT,
        quantity REAL,
        unit TEXT,
        selectedDate $dateType,
        costs TEXT,
        /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
        sortOrder INTEGER NOT NULL,
        /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
        FOREIGN KEY (parentId) REFERENCES items(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE quarterly_budgets (
        id $idType,
        parentId INTEGER NOT NULL,
        quarterNumber INTEGER NOT NULL,
        amountKip REAL NOT NULL,
        amountThb REAL NOT NULL,
        amountUsd REAL NOT NULL,
        selectedDate TEXT,
        notes TEXT
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 12) {
      await db.execute("ALTER TABLE quarterly_budgets ADD COLUMN selectedDate TEXT");
    }
    if (oldVersion < 13) {
      await db.execute("ALTER TABLE sub_items ADD COLUMN childOf INTEGER");
    }
    if (oldVersion < 14) {
      await db.execute("ALTER TABLE items ADD COLUMN isIncludedInTotals INTEGER NOT NULL DEFAULT 1");
    }
    if (oldVersion < 15) {
      await db.execute("ALTER TABLE quarterly_budgets ADD COLUMN notes TEXT");
    }
    if (oldVersion < 16) {
      await db.execute('CREATE TABLE sub_items_new ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'parentId INTEGER NOT NULL, '
          'childOf INTEGER, '
          'title TEXT NOT NULL, '
          'description TEXT, '
          'quantity REAL, '
          'unit TEXT, '
          'selectedDate TEXT, '
          'costs TEXT, '
          'FOREIGN KEY (parentId) REFERENCES items(id) ON DELETE CASCADE)');

      final List<Map<String, dynamic>> oldData = await db.query('sub_items');
      final batch = db.batch();

      for (final row in oldData) {
        final List<CostModel> costs = [];
        if (row['laborCost'] != null && (row['laborCost'] as double) > 0) {
          costs.add(CostModel(
            description: 'ຄ່າແຮງ',
            amount: row['laborCost'] as double,
            currency: row['laborCostCurrency'] as String? ?? Currency.KIP.code,
          ));
        }
        if (row['materialCost'] != null && (row['materialCost'] as double) > 0) {
          costs.add(CostModel(
            description: 'ຄ່າວັດສະດຸ',
            amount: row['materialCost'] as double,
            currency: row['materialCostCurrency'] as String? ?? Currency.KIP.code,
          ));
        }

        batch.insert('sub_items_new', {
          'id': row['id'],
          'parentId': row['parentId'],
          'childOf': row['childOf'],
          'title': row['title'],
          'description': row['description'],
          'quantity': row['quantity'],
          'unit': row['unit'],
          'selectedDate': row['selectedDate'],
          'costs': json.encode(costs.map((c) => c.toMap()).toList()),
        });
      }
      await batch.commit(noResult: true);

      await db.execute('DROP TABLE sub_items');
      await db.execute('ALTER TABLE sub_items_new RENAME TO sub_items');
    }
    /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
    if (oldVersion < 17) {
      await db.execute("ALTER TABLE sub_items ADD COLUMN sortOrder INTEGER NOT NULL DEFAULT 0");
      // สำหรับข้อมูลเก่า ให้ใช้ id เป็นค่า sortOrder เริ่มต้นไปก่อน
      await db.execute("UPDATE sub_items SET sortOrder = id");
    }
    /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
  }

  // --- CRUD for Items ---
  Future<ItemModel> create(ItemModel item) async {
    final db = await instance.database;
    final id = await db.insert('items', item.toMap());
    return item.copyWith(id: id);
  }

  Future<List<ItemModel>> readAllItems() async {
    final db = await instance.database;
    final result = await db.query('items', orderBy: 'id ASC');
    return result.map((json) => ItemModel.fromMap(json)).toList();
  }

  Future<int> update(ItemModel item) async {
    final db = await instance.database;
    return db.update('items', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> updateItems(List<ItemModel> items) async {
    final db = await instance.database;
    final batch = db.batch();
    for (final item in items) {
      batch.update('items', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
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
        /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
        where: 'parentId = ?', whereArgs: [parentId], orderBy: 'sortOrder ASC'); // เปลี่ยนมาเรียงตาม sortOrder
        /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
    return result.map((json) => SubItemModel.fromMap(json)).toList();
  }

  Future<List<SubItemModel>> readAllSubItems() async {
    final db = await instance.database;
    final result = await db.query('sub_items');
    return result.map((json) => SubItemModel.fromMap(json)).toList();
  }

  Future<int> updateSubItem(SubItemModel subItem) async {
    final db = await instance.database;
    return db.update('sub_items', subItem.toMap(), where: 'id = ?', whereArgs: [subItem.id]);
  }

  Future<void> updateSubItems(List<SubItemModel> subItems) async {
    final db = await instance.database;
    final batch = db.batch();
    for (final subItem in subItems) {
      batch.update('sub_items', subItem.toMap(), where: 'id = ?', whereArgs: [subItem.id]);
    }
    await batch.commit(noResult: true);
  }

  Future<int> deleteSubItem(int id) async {
    final db = await instance.database;
    return await db.delete('sub_items', where: 'id = ?', whereArgs: [id]);
  }

  // --- CRUD for QuarterlyBudgets ---
  Future<QuarterlyBudgetModel> createQuarterlyBudget(QuarterlyBudgetModel budget) async {
    final db = await instance.database;
    final id = await db.insert('quarterly_budgets', budget.toMap());
    return budget.copyWith(id: id);
  }

  Future<List<QuarterlyBudgetModel>> readQuarterlyBudgetsForParent(int parentId) async {
    final db = await instance.database;
    final result = await db.query('quarterly_budgets',
        where: 'parentId = ?', whereArgs: [parentId], orderBy: 'quarterNumber ASC');
    return result.map((json) => QuarterlyBudgetModel.fromMap(json)).toList();
  }

  Future<List<QuarterlyBudgetModel>> readAllQuarterlyBudgets() async {
    final db = await instance.database;
    final result = await db.query('quarterly_budgets');
    return result.map((json) => QuarterlyBudgetModel.fromMap(json)).toList();
  }

  Future<int> updateQuarterlyBudget(QuarterlyBudgetModel budget) async {
    final db = await instance.database;
    return db.update('quarterly_budgets', budget.toMap(), where: 'id = ?', whereArgs: [budget.id]);
  }

  Future<int> deleteQuarterlyBudget(int id) async {
    final db = await instance.database;
    return await db.delete('quarterly_budgets', where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
