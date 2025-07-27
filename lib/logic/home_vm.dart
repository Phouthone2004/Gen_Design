import 'package:flutter/material.dart';
import '../data/item_model.dart';
import '../services/db_service.dart';

class HomeViewModel extends ChangeNotifier {
  List<ItemModel> _allItems = [];
  List<ItemModel> items = []; // รายการที่จะแสดงผล (หลังจากการค้นหา)
  bool isLoading = false;
  String _searchQuery = '';

  /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
  // State สำหรับเก็บยอดรวมค่าใช้จ่ายของแต่ละรายการหลัก
  Map<int, double> subItemsTotalCosts = {};
  /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */

  HomeViewModel() {
    loadItems();
  }

  /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
  // ยอดรวมงบประมาณทั้งหมด (จากทุกโปรเจกต์)
  double get grandTotalBudget {
    return _allItems.fold(0.0, (sum, item) => sum + item.amount);
  }

  // ยอดรวมค่าใช้จ่ายทั้งหมด (จากทุกโปรเจกต์)
  double get grandTotalCost {
    return subItemsTotalCosts.values.fold(0.0, (sum, cost) => sum + cost);
  }

  // ยอดคงเหลือทั้งหมด
  double get grandTotalRemaining {
    return grandTotalBudget - grandTotalCost;
  }
  /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */

  Future<void> loadItems() async {
    isLoading = true;
    notifyListeners();

    _allItems = await DBService.instance.readAllItems();
    
    /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
    // โหลดค่าใช้จ่ายทั้งหมดของ sub-items มาเก็บไว้ใน Map
    subItemsTotalCosts = await DBService.instance.getAllSubItemsTotalCost();
    /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */

    items = List.from(_allItems);
    _filterItems(); // เรียกใช้ฟังก์ชันกรองหลังโหลดข้อมูล
    isLoading = false;
    notifyListeners();
  }

  /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
  // แยก Logic การค้นหาออกมาเป็นฟังก์ชันส่วนตัว
  void _filterItems() {
    if (_searchQuery.isEmpty) {
      items = List.from(_allItems);
    } else {
      items = _allItems.where((item) {
        final titleLower = item.title.toLowerCase();
        final descriptionLower = item.description.toLowerCase();
        final queryLower = _searchQuery.toLowerCase();
        return titleLower.contains(queryLower) || descriptionLower.contains(queryLower);
      }).toList();
    }
  }

  // ฟังก์ชันสำหรับการค้นหา
  void search(String query) {
    _searchQuery = query;
    _filterItems(); // กรองรายการ
    notifyListeners();
  }
  /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */

  Future<void> addItem(ItemModel item) async {
    final maxSortOrder = _allItems.isEmpty ? -1 : _allItems.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b);
    final newItem = item.copyWith(
      lastActivityTimestamp: DateTime.now().millisecondsSinceEpoch,
      sortOrder: maxSortOrder + 1,
    );
    await DBService.instance.create(newItem);
    await loadItems(); // โหลดข้อมูลใหม่ทั้งหมด
  }

  Future<void> updateItem(ItemModel item) async {
    final updatedItem = item.copyWith(
      lastActivityTimestamp: DateTime.now().millisecondsSinceEpoch
    );
    await DBService.instance.update(updatedItem);
    await loadItems(); // โหลดข้อมูลใหม่ทั้งหมด
  }

  Future<void> deleteItem(int id) async {
    await DBService.instance.delete(id);
    await loadItems(); // โหลดข้อมูลใหม่ทั้งหมด
  }

  Future<void> togglePinStatus(ItemModel item) async {
    final isCurrentlyPinned = item.isPinned == 1;
    final updatedItem = item.copyWith(
      isPinned: isCurrentlyPinned ? 0 : 1,
      pinTimestamp: isCurrentlyPinned ? null : DateTime.now().millisecondsSinceEpoch,
    );
    await DBService.instance.update(updatedItem);
    await loadItems(); // โหลดข้อมูลใหม่ทั้งหมด
  }

  Future<void> reorderItems(int oldIndex, int newIndex) async {
    // ต้องจัดการกับ index ของรายการที่กรองอยู่ (items)
    // ไม่ใช่ _allItems
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final ItemModel item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    notifyListeners(); // อัปเดต UI ทันที
    
    // สร้าง list ใหม่ตามลำดับของ `items` แต่เอาเฉพาะรายการที่ไม่ได้ปักหมุด
    final reorderableItems = _allItems.where((i) => i.isPinned == 0).toList();
    
    // หา item ที่ถูกย้ายใน reorderableItems
    final movedItem = reorderableItems.firstWhere((i) => i.id == item.id);
    reorderableItems.remove(movedItem);
    
    // หา index ที่ถูกต้องใน reorderableItems
    // newIndex คือ index ใน `items`, เราต้องแปลงเป็น index ใน `reorderableItems`
    final targetItemInFiltered = items[newIndex];
    int targetIndexInReorderable = reorderableItems.indexWhere((i) => i.id == targetItemInFiltered.id);
    
    // ถ้าไม่เจอ (อาจจะเป็นรายการสุดท้าย) ให้เพิ่มท้ายสุด
    if(targetIndexInReorderable == -1) {
       reorderableItems.add(movedItem);
    } else {
       reorderableItems.insert(targetIndexInReorderable, movedItem);
    }

    await DBService.instance.updateSortOrder(reorderableItems);
    await loadItems(); // โหลดข้อมูลใหม่ทั้งหมด
  }
}
