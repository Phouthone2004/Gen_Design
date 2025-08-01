import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../data/item_model.dart';
import '../data/sub_item_model.dart';
import '../data/quarterly_budget_model.dart';

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
      version: 13,
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
        sortOrder $integerType
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
        laborCost REAL,
        laborCostCurrency TEXT,
        materialCost REAL,
        materialCostCurrency TEXT,
        selectedDate $dateType,
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
        selectedDate TEXT
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
        where: 'parentId = ?', whereArgs: [parentId], orderBy: 'id ASC');
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

  /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
  Future<void> updateSubItems(List<SubItemModel> subItems) async {
    final db = await instance.database;
    final batch = db.batch();
    for (final subItem in subItems) {
      batch.update('sub_items', subItem.toMap(), where: 'id = ?', whereArgs: [subItem.id]);
    }
    await batch.commit(noResult: true);
  }
  /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */

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
