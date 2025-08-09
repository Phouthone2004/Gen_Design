import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../data/item_model.dart';
import '../data/sub_item_model.dart';
import '../data/quarterly_budget_model.dart';
import '../services/db_service.dart';
import '../presentation/core/app_currencies.dart';
import '../data/settings_model.dart';
import '../services/settings_service.dart';

class HomeViewModel extends ChangeNotifier {
  List<ItemModel> _allItems = [];
  List<ItemModel> items = [];
  bool isLoading = false;
  String _searchQuery = '';

  bool areAmountsVisible = true;

  Map<String, double> grandTotalBudget = {};
  Map<String, double> grandTotalCost = {};
  Map<String, double> grandTotalRemaining = {};
  Map<int, Map<String, double>> subItemsTotalCosts = {};

  int? selectedYearFilter;
  List<int> availableYears = [];

  late SettingsModel settings;
  bool isSettingsLoading = true;

  HomeViewModel() {
    selectedYearFilter = DateTime.now().year;
    _initialize();
  }

  Future<void> _initialize() async {
    await loadSettings();
    await loadItems();
  }

  Future<void> loadSettings() async {
    isSettingsLoading = true;
    notifyListeners();
    settings = await SettingsService.instance.loadSettings();
    isSettingsLoading = false;
    notifyListeners();
  }

  Future<void> saveSettings(SettingsModel newSettings) async {
    await SettingsService.instance.saveSettings(newSettings);
    await loadSettings(); // Reload to update the UI
  }

  void toggleAmountVisibility() {
    areAmountsVisible = !areAmountsVisible;
    notifyListeners();
  }

  void filterByYear(int? year) {
    selectedYearFilter = year;
    _filterItems();
    notifyListeners();
  }

  Map<String, dynamic> _calculateRecursiveTotals(
    SubItemModel item,
    Map<int?, List<SubItemModel>> hierarchy,
    Map<int, Map<String, dynamic>> calculatedTotals,
  ) {
    if (calculatedTotals.containsKey(item.id)) {
      return calculatedTotals[item.id]!;
    }

    double totalQuantity = item.quantity ?? 0;
    final totalCosts = { for (var c in Currency.values) c.code : 0.0 };

    if (item.laborCost != null && item.laborCost! > 0 && item.laborCostCurrency != null) {
      totalCosts[item.laborCostCurrency!] = (totalCosts[item.laborCostCurrency!] ?? 0) + item.laborCost!;
    }
    if (item.materialCost != null && item.materialCost! > 0 && item.materialCostCurrency != null) {
      totalCosts[item.materialCostCurrency!] = (totalCosts[item.materialCostCurrency!] ?? 0) + item.materialCost!;
    }

    final children = hierarchy[item.id] ?? [];
    for (final child in children) {
      final childTotals = _calculateRecursiveTotals(child, hierarchy, calculatedTotals);
      totalQuantity += childTotals['quantity'] as double;
      (childTotals['costs'] as Map<String, double>).forEach((currency, cost) {
        totalCosts[currency] = (totalCosts[currency] ?? 0) + cost;
      });
    }

    final result = {'quantity': totalQuantity, 'costs': totalCosts};
    calculatedTotals[item.id!] = result;
    return result;
  }

  Future<void> loadItems() async {
    isLoading = true;
    notifyListeners();
  
    _initializeMaps();

    List<ItemModel> originalItems = await DBService.instance.readAllItems();
    final allSubItems = await DBService.instance.readAllSubItems();
    final allQuarterlyBudgets = await DBService.instance.readAllQuarterlyBudgets();

    final groupedQuarterlyBudgets = groupBy(allQuarterlyBudgets, (QuarterlyBudgetModel qb) => qb.parentId);

    _allItems = originalItems.map((item) {
      final quarters = groupedQuarterlyBudgets[item.id];
      if (quarters != null && quarters.isNotEmpty) {
        double totalKip = quarters.fold(0.0, (sum, q) => sum + q.amountKip);
        double totalThb = quarters.fold(0.0, (sum, q) => sum + q.amountThb);
        double totalUsd = quarters.fold(0.0, (sum, q) => sum + q.amountUsd);
        return item.copyWith(amount: totalKip, amountThb: totalThb, amountUsd: totalUsd);
      }
      return item;
    }).toList();


    final years = _allItems
        .where((item) => item.creationTimestamp != null)
        .map((item) => DateTime.fromMillisecondsSinceEpoch(item.creationTimestamp!).year)
        .toSet();
    years.add(DateTime.now().year);
  
    availableYears = years.toList();
    availableYears.sort((a, b) => b.compareTo(a));

    for (var item in _allItems) {
      grandTotalBudget[Currency.KIP.code] = (grandTotalBudget[Currency.KIP.code] ?? 0) + item.amount;
      grandTotalBudget[Currency.THB.code] = (grandTotalBudget[Currency.THB.code] ?? 0) + item.amountThb;
      grandTotalBudget[Currency.USD.code] = (grandTotalBudget[Currency.USD.code] ?? 0) + item.amountUsd;
    }

    final allSubItemsGroupedByParentProject = groupBy(allSubItems, (SubItemModel subItem) => subItem.parentId);
    final newSubItemsTotalCosts = <int, Map<String, double>>{};

    allSubItemsGroupedByParentProject.forEach((projectId, subItemsForProject) {
        final hierarchy = <int?, List<SubItemModel>>{};
        for (final subItem in subItemsForProject) {
            hierarchy.putIfAbsent(subItem.childOf, () => []).add(subItem);
        }

        final calculatedTotals = <int, Map<String, dynamic>>{};
        final topLevelItems = hierarchy[null] ?? [];
        for (final item in topLevelItems) {
            _calculateRecursiveTotals(item, hierarchy, calculatedTotals);
        }
      
        final projectTotalCost = { for (var c in Currency.values) c.code : 0.0 };
        for (final topLevelItem in topLevelItems) {
            final totals = calculatedTotals[topLevelItem.id];
            if (totals != null) {
                (totals['costs'] as Map<String, double>).forEach((currency, cost) {
                    projectTotalCost[currency] = (projectTotalCost[currency] ?? 0) + cost;
                });
            }
        }
        newSubItemsTotalCosts[projectId] = projectTotalCost;
    });

    subItemsTotalCosts = newSubItemsTotalCosts;

    subItemsTotalCosts.values.forEach((costMap) {
      grandTotalCost.forEach((currencyCode, total) {
        grandTotalCost[currencyCode] = total + (costMap[currencyCode] ?? 0);
      });
    });
  
    grandTotalBudget.forEach((currency, budget) {
      grandTotalRemaining[currency] = budget - (grandTotalCost[currency] ?? 0);
    });

    _filterItems();
    isLoading = false;
    notifyListeners();
  }

  void _initializeMaps() {
    grandTotalBudget = { for (var c in Currency.values) c.code : 0.0 };
    grandTotalCost = { for (var c in Currency.values) c.code : 0.0 };
    grandTotalRemaining = { for (var c in Currency.values) c.code : 0.0 };
    subItemsTotalCosts = {};
  }

  void _filterItems() {
    List<ItemModel> tempItems = List.from(_allItems);

    if (selectedYearFilter != null) {
      tempItems = tempItems.where((item) {
        if (item.creationTimestamp == null) return false;
        final itemYear = DateTime.fromMillisecondsSinceEpoch(item.creationTimestamp!).year;
        return itemYear == selectedYearFilter;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      tempItems = tempItems.where((item) {
        final titleLower = item.title.toLowerCase();
        final descriptionLower = item.description.toLowerCase();
        final queryLower = _searchQuery.toLowerCase();
        return titleLower.contains(queryLower) || descriptionLower.contains(queryLower);
      }).toList();
    }

    items = tempItems;
  }

  void search(String query) {
    _searchQuery = query;
    _filterItems();
    notifyListeners();
  }

  String _getOriginalTitle(String fullTitle) {
    int dotIndex = fullTitle.indexOf('. ');
    if (dotIndex != -1 && dotIndex < 3) {
      return fullTitle.substring(dotIndex + 2);
    }
    return fullTitle;
  }

  Future<void> _updateAlphabeticalOrder() async {
    final allItems = await DBService.instance.readAllItems();

    final itemsGroupedByYear = groupBy(allItems, (ItemModel item) {
      final timestamp = item.creationTimestamp ?? item.lastActivityTimestamp ?? 0;
      return DateTime.fromMillisecondsSinceEpoch(timestamp).year;
    });

    final List<ItemModel> itemsToUpdate = [];

    itemsGroupedByYear.forEach((year, itemsInYear) {
      for (int i = 0; i < itemsInYear.length; i++) {
        final item = itemsInYear[i];
        if (i < 26) {
          final newLetter = String.fromCharCode('A'.codeUnitAt(0) + i);
          final originalTitle = _getOriginalTitle(item.title);
          final newPrefixedTitle = '$newLetter. $originalTitle';

          if (item.title != newPrefixedTitle) {
            itemsToUpdate.add(item.copyWith(title: newPrefixedTitle));
          }
        }
      }
    });

    if (itemsToUpdate.isNotEmpty) {
      await DBService.instance.updateItems(itemsToUpdate);
    }
  }

  Future<void> addItem(ItemModel item) async {
    final allItems = await DBService.instance.readAllItems();
  
    final currentSystemYear = DateTime.now().year;

    final itemsInCurrentYear = allItems.where((i) {
      final timestamp = i.creationTimestamp ?? i.lastActivityTimestamp ?? 0;
      final itemYear = DateTime.fromMillisecondsSinceEpoch(timestamp).year;
      return itemYear == currentSystemYear;
    }).toList();

    String prefixedTitle = item.title;
    if (itemsInCurrentYear.length < 26) {
      final newLetter = String.fromCharCode('A'.codeUnitAt(0) + itemsInCurrentYear.length);
      prefixedTitle = '$newLetter. ${item.title}';
    }

    final newItem = item.copyWith(
      title: prefixedTitle,
      creationTimestamp: DateTime.now().millisecondsSinceEpoch,
      lastActivityTimestamp: DateTime.now().millisecondsSinceEpoch,
      sortOrder: 0,
    );
    final createdItem = await DBService.instance.create(newItem);

    if (createdItem.id != null) {
      final firstQuarter = QuarterlyBudgetModel(
        parentId: createdItem.id!,
        quarterNumber: 1,
        amountKip: createdItem.amount,
        amountThb: createdItem.amountThb,
        amountUsd: createdItem.amountUsd,
      );
      await DBService.instance.createQuarterlyBudget(firstQuarter);
    }
  
    await loadItems();
  }

  Future<void> updateItem(ItemModel item) async {
    final originalItem = _allItems.firstWhere((i) => i.id == item.id);
    final originalTitle = _getOriginalTitle(originalItem.title);
    final newTitleFromDialog = item.title;

    String finalTitle = newTitleFromDialog;
    int dotIndex = originalItem.title.indexOf('. ');
     if (dotIndex != -1 && dotIndex < 3) {
       String prefix = originalItem.title.substring(0, dotIndex + 2);
       if (newTitleFromDialog != originalTitle) {
         finalTitle = prefix + newTitleFromDialog;
       } else {
         finalTitle = originalItem.title;
       }
     }

    final updatedItem = item.copyWith(
      title: finalTitle,
      lastActivityTimestamp: DateTime.now().millisecondsSinceEpoch
    );
    await DBService.instance.update(updatedItem);
    
    /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
    // Logic แก้ไขบั๊ก: อัปเดตงบประมาณงวดที่ 1 ตามงบใหม่
    final budgets = await DBService.instance.readQuarterlyBudgetsForParent(item.id!);
    if (budgets.isNotEmpty) {
      // ใช้ firstWhereOrNull จาก package:collection เพื่อความปลอดภัย
      final firstQuarter = budgets.firstWhereOrNull((b) => b.quarterNumber == 1);
      if (firstQuarter != null) {
        final updatedQuarter = firstQuarter.copyWith(
          amountKip: item.amount,
          amountThb: item.amountThb,
          amountUsd: item.amountUsd,
        );
        await DBService.instance.updateQuarterlyBudget(updatedQuarter);
      }
    }
    /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */

    await loadItems();
  }

  Future<void> deleteItem(int id) async {
    await DBService.instance.delete(id);
    await _updateAlphabeticalOrder();
    await loadItems();
  }
}
