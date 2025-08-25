import 'dart:async';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gen_design/data/cost_model.dart';
import 'package:gen_design/presentation/widget/add_edit_item_dialog.dart';
import 'package:gen_design/presentation/widget/home_content.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/item_model.dart';
import '../../data/sub_item_model.dart';
import '../../data/quarterly_budget_model.dart';
import '../../logic/home_vm.dart';
import '../../services/db_service.dart';
import '../core/app_styles.dart';
import '../core/app_currencies.dart';
import 'pdf_preview_page.dart';
import '../../services/pdf_exporter.dart';

// enum สำหรับจัดการตัวเลือกวันที่ในหน้านี้
enum DateSelectionOption { none, today, manual }

class DetailPage extends StatefulWidget {
  final ItemModel item;
  const DetailPage({super.key, required this.item});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final ScrollController _scrollController = ScrollController();
  late PageController _pageController;
  bool _isScrolled = false;

  List<SubItemModel> _subItemsTree = [];
  Map<int?, List<SubItemModel>> _hierarchy = {};
  Map<int, Map<String, dynamic>> _calculatedTotals = {};

  List<QuarterlyBudgetModel> _quarterlyBudgets = [];
  bool _isBudgetsLoading = true;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _pageController = PageController();
    _loadAllData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final isScrolled =
        _scrollController.hasClients &&
        _scrollController.offset > (550 - 70 - kToolbarHeight);
    if (isScrolled != _isScrolled) {
      setState(() {
        _isScrolled = isScrolled;
      });
    }
  }

  Future<void> _loadAllData() async {
    await _loadAndStructureSubItems();
    await _loadQuarterlyBudgets(widget.item);
  }

  Future<void> _loadQuarterlyBudgets(ItemModel item) async {
    setState(() => _isBudgetsLoading = true);
    var budgets = await DBService.instance.readQuarterlyBudgetsForParent(
      widget.item.id!,
    );

    if (budgets.isEmpty) {
      final firstQuarter = QuarterlyBudgetModel(
        parentId: widget.item.id!,
        quarterNumber: 1,
        amountKip: item.amount,
        amountThb: item.amountThb,
        amountUsd: item.amountUsd,
      );
      final createdBudget = await DBService.instance.createQuarterlyBudget(
        firstQuarter,
      );
      budgets = [createdBudget];
    }

    setState(() {
      _quarterlyBudgets = budgets;
      _isBudgetsLoading = false;
      _currentPageIndex = budgets.isNotEmpty ? budgets.length - 1 : 0;
      _pageController = PageController(initialPage: _currentPageIndex);
    });
  }

  Future<void> _loadAndStructureSubItems() async {
    try {
      final allSubItems = await DBService.instance.readSubItemsForParent(
        widget.item.id!,
      );

      final hierarchy = <int?, List<SubItemModel>>{};
      for (final subItem in allSubItems) {
        hierarchy.putIfAbsent(subItem.childOf, () => []).add(subItem);
      }
      
      // จัดเรียงทุกระดับชั้นด้วย sortOrder
      hierarchy.forEach((key, value) {
        value.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      });

      _hierarchy = hierarchy;

      final calculatedTotals = <int, Map<String, dynamic>>{};
      final topLevelItems = hierarchy[null] ?? [];
      for (final item in topLevelItems) {
        _calculateRecursiveTotals(item, hierarchy, calculatedTotals);
      }
      _calculatedTotals = calculatedTotals;

      setState(() {
        _subItemsTree = topLevelItems;
      });
    } catch (e) {
      print('Error loading and structuring sub-items: $e');
    }
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
    final totalCosts = {for (var c in Currency.values) c.code: 0.0};

    for (final cost in item.costs) {
      totalCosts[cost.currency] = (totalCosts[cost.currency] ?? 0) + cost.amount;
    }

    final children = hierarchy[item.id] ?? [];
    for (final child in children) {
      final childTotals = _calculateRecursiveTotals(
        child,
        hierarchy,
        calculatedTotals,
      );
      totalQuantity += childTotals['quantity'] as double;
      (childTotals['costs'] as Map<String, double>).forEach((currency, cost) {
        totalCosts[currency] = (totalCosts[currency] ?? 0) + cost;
      });
    }

    final result = {'quantity': totalQuantity, 'costs': totalCosts};
    calculatedTotals[item.id!] = result;
    return result;
  }
  
  /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
  // ฟังก์ชันนี้จะมาแทนที่ _renameSiblingItems และ _cascadeRenameChildren ทั้งหมด
  // โดยจะทำการอัปเดตชื่อของไอเท็มและลูกๆ ทั้งหมดในระดับเดียวกันให้ถูกต้อง
  Future<void> _updateAllTitlesAfterReorder(int? parentId) async {
    final db = DBService.instance;
    // ดึงไอเท็มทั้งหมดในโปรเจกต์นี้มา เพื่อให้มีข้อมูลล่าสุดสำหรับการคำนวณ
    final allProjectItems = await db.readSubItemsForParent(widget.item.id!);

    // Queue หรือ "คิว" สำหรับเก็บ ID ของไอเท็มแม่ที่ต้องประมวลผลลูกๆ ของมัน
    // เราจะเริ่มจาก parentId ที่ได้รับมา (ถ้าเป็น null คือระดับบนสุด)
    final processingQueue = <int?>[parentId];
    final processedIds = <int?>{}; // Set สำหรับเก็บ ID ที่ประมวลผลไปแล้ว ป้องกันการทำงานซ้ำซ้อน

    while (processingQueue.isNotEmpty) {
      final currentParentId = processingQueue.removeAt(0);

      if (processedIds.contains(currentParentId)) continue;
      processedIds.add(currentParentId);

      // ค้นหาไอเท็มแม่จากในลิสต์ เพื่อเอา Prefix (เช่น "A.1") มาใช้
      final parentItem = currentParentId == null
          ? null
          : allProjectItems.firstWhereOrNull((item) => item.id == currentParentId);

      // กำหนด Prefix สำหรับลูกๆ ในระดับนี้
      final parentPrefix = currentParentId == null
          ? widget.item.title.split('. ').first // ถ้าเป็นระดับบนสุด ให้ใช้ Prefix ของโปรเจกต์หลัก
          : parentItem!.title.split(' ').first; // ถ้าไม่ใช่ ให้ใช้ Prefix ของแม่มัน

      // ค้นหาลูกๆ ทั้งหมดของแม่ตัวนี้
      final siblings = allProjectItems.where((item) => item.childOf == currentParentId).toList();
      if (siblings.isEmpty) continue;

      // เรียงลำดับลูกๆ ตาม sortOrder ที่ถูกต้อง
      siblings.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      final List<SubItemModel> itemsToUpdate = [];

      // วนลูปเพื่อสร้างชื่อใหม่ให้กับลูกๆ ทุกตัว
      for (int i = 0; i < siblings.length; i++) {
        final sibling = siblings[i];
        final newIndex = i + 1;
        final newPrefix = '$parentPrefix.$newIndex';
        
        // แยกเอาเฉพาะส่วนของ "คำอธิบาย" (ที่อยู่หลัง Prefix และเว้นวรรค) ออกมา
        final descriptionPart = sibling.title.contains(' ')
            ? sibling.title.substring(sibling.title.indexOf(' ') + 1)
            : '';
        
        final newTitle = '$newPrefix $descriptionPart';

        // ถ้าชื่อใหม่ไม่ตรงกับชื่อเก่า ก็เตรียมอัปเดต
        if (sibling.title != newTitle) {
          final updatedItem = sibling.copyWith(title: newTitle);
          itemsToUpdate.add(updatedItem);

          // อัปเดตข้อมูลในลิสต์ allProjectItems ใน memory ไปด้วยเลย
          // เพื่อให้การทำงานในรอบถัดไป (สำหรับหลานๆ) ได้ Prefix ที่ถูกต้อง
          final indexInAllItems = allProjectItems.indexWhere((item) => item.id == updatedItem.id);
          if (indexInAllItems != -1) {
            allProjectItems[indexInAllItems] = updatedItem;
          }
        }
        
        // เพิ่ม ID ของลูกตัวนี้เข้าไปในคิว เพื่อที่รอบหน้าจะได้เข้าไปอัปเดต "หลาน" ของมันต่อไป
        processingQueue.add(sibling.id);
      }

      // ถ้ามีรายการที่ต้องอัปเดตในระดับนี้ ก็สั่งอัปเดตลง DB
      if (itemsToUpdate.isNotEmpty) {
        await db.updateSubItems(itemsToUpdate);
      }
    }
  }

  Future<void> _saveSubItemAndReorder({
    required SubItemModel itemToSave,
    int? oldSortOrder, 
  }) async {
    final db = DBService.instance;
    final isEditing = itemToSave.id != null;
    final newSortOrder = itemToSave.sortOrder;

    List<SubItemModel> allItems = await db.readSubItemsForParent(widget.item.id!);
    List<SubItemModel> siblings = allItems.where((i) => i.childOf == itemToSave.childOf).toList();

    List<SubItemModel> itemsToUpdate = [];

    if (isEditing) {
      if (oldSortOrder != newSortOrder) {
        // Remove the item being edited from siblings list to avoid re-shifting itself
        final originalItem = siblings.firstWhereOrNull((i) => i.id == itemToSave.id);
        if(originalItem != null) siblings.remove(originalItem);

        if (newSortOrder < oldSortOrder!) {
          // Moving item up
          for (final sibling in siblings) {
            if (sibling.sortOrder >= newSortOrder && sibling.sortOrder < oldSortOrder) {
              itemsToUpdate.add(sibling.copyWith(sortOrder: sibling.sortOrder + 1));
            }
          }
        } else { // Moving item down
          for (final sibling in siblings) {
            if (sibling.sortOrder > oldSortOrder && sibling.sortOrder <= newSortOrder) {
              itemsToUpdate.add(sibling.copyWith(sortOrder: sibling.sortOrder - 1));
            }
          }
        }
      }
    } else { // This is a new item
      for (final sibling in siblings) {
        if (sibling.sortOrder >= newSortOrder) {
          itemsToUpdate.add(sibling.copyWith(sortOrder: sibling.sortOrder + 1));
        }
      }
    }

    // Commit sort order changes for other items
    if (itemsToUpdate.isNotEmpty) {
      await db.updateSubItems(itemsToUpdate);
    }
    
    // Create or update the main item
    if (isEditing) {
      await db.updateSubItem(itemToSave);
    } else {
      await db.createSubItem(itemToSave);
    }

    // Call the new single function to fix all titles in the hierarchy
    await _updateAllTitlesAfterReorder(itemToSave.childOf);
    
    // Reload data for the UI
    await _loadAndStructureSubItems();
    if (mounted) {
      Provider.of<HomeViewModel>(context, listen: false).loadItems();
    }
  }
  /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */

  @override
  Widget build(BuildContext context) {
    return _buildDetailContent(context, widget.item);
  }

  Future<void> _showPdfPreview(ItemModel item) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pdfBytes = await PdfExporter.generatePdfBytes(
        item,
        _subItemsTree,
        _hierarchy,
        _calculatedTotals,
      );
      final String fileName = '${item.title.replaceAll(RegExp(r'[^\w\s]+'), '')}.pdf';

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfPreviewPage(
              pdfBytes: pdfBytes,
              fileName: fileName,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດໃນການສ້າງ PDF: $e')),
        );
      }
    }
  }

  Widget _buildDetailContent(BuildContext context, ItemModel item) {
    return Consumer<HomeViewModel>(
      builder: (context, vm, child) {
        final projectCosts = vm.subItemsTotalCosts[item.id] ?? {};

        return Container(
          decoration: vm.settings.useDefaultBackground
              ? const BoxDecoration(gradient: headerGradient)
              : BoxDecoration(
                  image:
                      vm.settings.backgroundImagePath != null &&
                              vm.settings.backgroundImagePath!.isNotEmpty
                          ? DecorationImage(
                              image: FileImage(
                                File(vm.settings.backgroundImagePath!),
                              ),
                              fit: BoxFit.cover,
                              colorFilter: ColorFilter.mode(
                                Colors.black.withOpacity(0.3),
                                BlendMode.darken,
                              ),
                            )
                          : null,
                  gradient: headerGradient,
                ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: FloatingActionButton(
              onPressed: () async {
                final bool? result = await _showAddEditSubItemDialog(
                  context,
                  item: item,
                  childOf: null,
                );
                if (result == true) {
                  // การโหลดข้อมูลใหม่จะถูกจัดการในฟังก์ชัน save แล้ว
                }
              },
              child: Ink(
                decoration: const BoxDecoration(
                  gradient: headerGradient,
                  borderRadius: BorderRadius.all(Radius.circular(16.0)),
                ),
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 56.0,
                    minHeight: 56.0,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.add, color: AppColors.textOnPrimary),
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4.0,
            ),
            body: CustomScrollView(
              controller: _scrollController,
              slivers: <Widget>[
                SliverAppBar(
                  backgroundColor: _isScrolled
                      ? AppColors.background
                      : Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  expandedHeight: 550.0,
                  collapsedHeight: 70.0,
                  pinned: true,
                  leading: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: _isScrolled
                          ? AppColors.primary
                          : AppColors.textOnPrimary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        vm.areAmountsVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: _isScrolled
                            ? AppColors.primary
                            : AppColors.textOnPrimary,
                      ),
                      onPressed: () {
                        vm.toggleAmountVisibility();
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.share_outlined,
                        color: _isScrolled
                            ? AppColors.primary
                            : AppColors.textOnPrimary,
                      ),
                      onPressed: () => _showPdfPreview(item),
                    ),
                  ],
                  title: _isScrolled
                      ? Text(
                          item.title,
                          style: const TextStyle(
                            fontFamily: AppTextStyles.fontFamily,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  centerTitle: true,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(
                      bottom: 12,
                      left: 60,
                      right: 60,
                    ),
                    centerTitle: true,
                    background: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              item.title,
                              style: AppTextStyles.display.copyWith(
                                fontSize: 32,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.description,
                              style: AppTextStyles.subheading.copyWith(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            _buildQuarterlyBudgetSection(
                              item,
                              vm.areAmountsVisible,
                            ),
                            const SizedBox(height: 16),
                            _buildDetailHeaderFinancials(
                              item,
                              projectCosts,
                              vm.areAmountsVisible,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: _isScrolled
                          ? null
                          : const BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
                      child: _subItemsTree.isEmpty
                          ? _buildEmptySubItems()
                          : _buildSubItemTree(_subItemsTree, 0, item),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubItemTree(
    List<SubItemModel> subItems,
    double indentationLevel,
    ItemModel mainItem,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: subItems.map((subItem) {
        final children = _hierarchy[subItem.id] ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(left: indentationLevel),
              child: SubItemCard(
                subItem: subItem,
                mainItem: mainItem,
                calculatedTotals:
                    _calculatedTotals[subItem.id] ??
                    {'quantity': 0.0, 'costs': {}},
                onAddChild: () async {
                  final bool? result = await _showAddEditSubItemDialog(
                    context,
                    item: mainItem,
                    childOf: subItem.id,
                  );
                  if (result == true) {
                    // การโหลดข้อมูลใหม่จะถูกจัดการในฟังก์ชัน save แล้ว
                  }
                },
              ),
            ),
            if (children.isNotEmpty)
              _buildSubItemTree(children, indentationLevel + 20.0, mainItem),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildQuarterlyBudgetSection(ItemModel item, bool isVisible) {
    double totalKip = _quarterlyBudgets.fold(
      0.0,
      (sum, q) => sum + q.amountKip,
    );
    double totalThb = _quarterlyBudgets.fold(
      0.0,
      (sum, q) => sum + q.amountThb,
    );
    double totalUsd = _quarterlyBudgets.fold(
      0.0,
      (sum, q) => sum + q.amountUsd,
    );
    final int pageCount = _quarterlyBudgets.length + 1;

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'ລວມມູນຄ່າທັງໝົດ',
              style: AppTextStyles.subheading.copyWith(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            _buildAmountText(Currency.KIP, totalKip, isVisible),
            _buildAmountText(Currency.THB, totalThb, isVisible),
            _buildAmountText(Currency.USD, totalUsd, isVisible),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              SizedBox(
                height: 120,
                child: _isBudgetsLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) =>
                            setState(() => _currentPageIndex = index),
                        itemCount: pageCount,
                        itemBuilder: (context, index) {
                          if (index == _quarterlyBudgets.length) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4.0,
                                ),
                                child: _buildAddQuarterButton(item),
                              ),
                            );
                          }
                          final budget = _quarterlyBudgets[index];
                          return _buildQuarterCard(item, budget, isVisible);
                        },
                      ),
              ),
              if (pageCount > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      pageCount,
                      (index) => Container(
                        width: 8.0,
                        height: 8.0,
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPageIndex == index
                              ? Colors.white
                              : Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuarterCard(
    ItemModel item,
    QuarterlyBudgetModel budget,
    bool isVisible,
  ) {
    final vm = Provider.of<HomeViewModel>(context, listen: false);
    return Card(
      color: AppColors.primaryLight,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await _showAddEditQuarterDialog(
            context,
            item.id!,
            budget.quarterNumber,
            existingBudget: budget,
          );
          if (result is QuarterlyBudgetModel) {
            await DBService.instance.updateQuarterlyBudget(result);
            await _loadQuarterlyBudgets(item);
            vm.loadItems();
          } else if (result == 'DELETE') {
            final bool? confirmDelete = await _showDeleteQuarterConfirmation(
              context,
              budget.quarterNumber,
            );
            if (confirmDelete == true) {
              await DBService.instance.deleteQuarterlyBudget(budget.id!);
              await _loadQuarterlyBudgets(item);
              vm.loadItems();
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Text(
                    'ງວດທີ່ ${budget.quarterNumber}',
                    style: AppTextStyles.subheading.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (budget.notes != null && budget.notes!.isNotEmpty)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.info_outline, color: Colors.white70, size: 20),
                      onPressed: () => _showNotesDialog(context, budget.notes!),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              _buildAmountText(Currency.KIP, budget.amountKip, isVisible),
              _buildAmountText(Currency.THB, budget.amountThb, isVisible),
              _buildAmountText(Currency.USD, budget.amountUsd, isVisible),
              const Spacer(),
              if (budget.selectedDate != null)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(budget.selectedDate!),
                    style: AppTextStyles.subText.copyWith(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddQuarterButton(ItemModel item) {
    final vm = Provider.of<HomeViewModel>(context, listen: false);
    return InkWell(
      onTap: () async {
        final newQuarterNumber = _quarterlyBudgets.length + 1;
        final newBudget = await _showAddEditQuarterDialog(
          context,
          item.id!,
          newQuarterNumber,
        );
        if (newBudget is QuarterlyBudgetModel) {
          await DBService.instance.createQuarterlyBudget(newBudget);
          await _loadQuarterlyBudgets(item);
          vm.loadItems();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.primaryLight.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.add_circle_outline,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildAmountText(Currency currency, double amount, bool isVisible) {
    if (amount == 0) return const SizedBox.shrink();
    return Text(
      isVisible
          ? '${NumberFormat("#,##0.##").format(amount)} ${currency.symbol}'
          : '*********** ${currency.symbol}',
      style: AppTextStyles.subText,
    );
  }

  Widget _buildDetailHeaderFinancials(
    ItemModel item,
    Map<String, double> projectCosts,
    bool isVisible,
  ) {
    double totalKip = _quarterlyBudgets.fold(
      0.0,
      (sum, q) => sum + q.amountKip,
    );
    double totalThb = _quarterlyBudgets.fold(
      0.0,
      (sum, q) => sum + q.amountThb,
    );
    double totalUsd = _quarterlyBudgets.fold(
      0.0,
      (sum, q) => sum + q.amountUsd,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ຍອດຄົງເຫຼືອ',
          style: AppTextStyles.subheading.copyWith(
            fontSize: 14,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        _buildFinancialDetailRow(
          currency: Currency.KIP,
          budget: totalKip,
          cost: projectCosts[Currency.KIP.code] ?? 0.0,
          isVisible: isVisible,
          isHeader: true,
        ),
        _buildFinancialDetailRow(
          currency: Currency.THB,
          budget: totalThb,
          cost: projectCosts[Currency.THB.code] ?? 0.0,
          isVisible: isVisible,
          isHeader: true,
        ),
        _buildFinancialDetailRow(
          currency: Currency.USD,
          budget: totalUsd,
          cost: projectCosts[Currency.USD.code] ?? 0.0,
          isVisible: isVisible,
          isHeader: true,
        ),
      ],
    );
  }

  Widget _buildFinancialDetailRow({
    required Currency currency,
    required double budget,
    required double cost,
    required bool isVisible,
    bool isHeader = false,
  }) {
    if (budget == 0 && cost == 0) return const SizedBox.shrink();
    final remaining = budget - cost;
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isVisible
                ? '${NumberFormat("#,##0.##").format(remaining)} ${currency.symbol}'
                : '****** ${currency.symbol}',
            style: isHeader
                ? AppTextStyles.display.copyWith(fontSize: 24)
                : AppTextStyles.subheading.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
          ),
          const SizedBox(height: 4),
          AnimatedProgressBar(
            value: cost,
            total: budget,
            currency: currency,
            isHeader: isHeader,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySubItems() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.list_alt_outlined, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('ຍັງບໍ່ມີລາຍການຍ່ອຍ', style: AppTextStyles.heading),
          const Text(
            'ກົດປຸ່ມ + ເພື່ອເພິ້ມລາຍການໃໝ່',
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }

  void _showDeleteSubItemConfirmation(
    BuildContext context,
    SubItemModel subItem,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('ຢືນຢັນການລົບ'),
          content: Text(
            'ທ່ານຕ້ອງການລົບລາຍການ "${subItem.title}" ແລະລາຍການຍ່ອຍທັງໝົດຂອງມັນແມ່ນບໍ່?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('ຍົກເລີກ'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () async {
                final parentId = subItem.childOf;
                await _deleteSubItemAndChildren(subItem.id!);
                /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
                // หลังจากลบแล้ว ให้เรียกฟังก์ชันอัปเดตชื่อใหม่
                await _updateAllTitlesAfterReorder(parentId);
                /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
                await _loadAndStructureSubItems(); // โหลดใหม่
                if (mounted) {
                  Provider.of<HomeViewModel>(context, listen: false).loadItems();
                }
                Navigator.of(dialogContext).pop();
              },
              child: const Text('ລົບ'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteSubItemAndChildren(int subItemId) async {
    final children = _hierarchy[subItemId] ?? [];
    for (final child in children) {
      await _deleteSubItemAndChildren(child.id!);
    }
    await DBService.instance.deleteSubItem(subItemId);
  }

  Future<dynamic> _showAddEditSubItemDialog(
    BuildContext context, {
    required ItemModel item,
    SubItemModel? existingSubItem,
    int? childOf,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => _AddEditSubItemDialog(
        mainItem: item,
        existingSubItem: existingSubItem,
        childOf: childOf,
        hierarchy: _hierarchy,
        onSave: ({required itemToSave, oldSortOrder}) async {
          await _saveSubItemAndReorder(
            itemToSave: itemToSave,
            oldSortOrder: oldSortOrder,
          );
        },
      ),
    );
  }

  Future<dynamic> _showAddEditQuarterDialog(
    BuildContext context,
    int parentId,
    int quarterNumber, {
    QuarterlyBudgetModel? existingBudget,
  }) {
    final bool isEditing = existingBudget != null;
    final formKey = GlobalKey<FormState>();
    final amountKipController = TextEditingController(
      text: isEditing && existingBudget.amountKip > 0
          ? NumberFormat("#,##0").format(existingBudget.amountKip)
          : '',
    );
    final amountThbController = TextEditingController(
      text: isEditing && existingBudget.amountThb > 0
          ? NumberFormat("#,##0").format(existingBudget.amountThb)
          : '',
    );
    final amountUsdController = TextEditingController(
      text: isEditing && existingBudget.amountUsd > 0
          ? NumberFormat("#,##0").format(existingBudget.amountUsd)
          : '',
    );
    final notesController = TextEditingController(text: existingBudget?.notes);
    DateTime? selectedDate = existingBudget?.selectedDate;
    bool showCalendar = existingBudget?.selectedDate != null;

    return showDialog<dynamic>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                isEditing
                    ? 'ແກ້ໄຂງວດທີ່ $quarterNumber'
                    : 'ເພີ່ມງວດທີ່ $quarterNumber',
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: amountKipController,
                          decoration: InputDecoration(
                            labelText: 'ງົບປະມານ (${Currency.KIP.laoName})',
                            icon: Text(
                              Currency.KIP.symbol,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            CurrencyInputFormatter(),
                          ],
                        ),
                        TextFormField(
                          controller: amountThbController,
                          decoration: InputDecoration(
                            labelText: 'ງົບປະມານ (${Currency.THB.laoName})',
                            icon: Text(
                              Currency.THB.symbol,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            CurrencyInputFormatter(),
                          ],
                        ),
                        TextFormField(
                          controller: amountUsdController,
                          decoration: InputDecoration(
                            labelText: 'ງົບປະມານ (${Currency.USD.laoName})',
                            icon: Text(
                              Currency.USD.symbol,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            CurrencyInputFormatter(),
                          ],
                        ),
                        const Divider(height: 24),
                        TextFormField(
                          controller: notesController,
                          decoration: const InputDecoration(
                            labelText: 'ໝາຍເຫດ',
                            icon: Icon(Icons.note_alt_outlined),
                          ),
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                        ),
                        const Divider(height: 24),
                        CheckboxListTile(
                          title: const Text("ສະແດງວັນທີ"),
                          value: showCalendar,
                          onChanged: (bool? value) async {
                            if (value == true) {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                locale: const Locale('lo'),
                                initialDate: selectedDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2101),
                              );
                              if (picked != null) {
                                setStateDialog(() {
                                  showCalendar = true;
                                  selectedDate = picked;
                                });
                              }
                            } else {
                              setStateDialog(() {
                                showCalendar = false;
                                selectedDate = null;
                              });
                            }
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          subtitle: showCalendar && selectedDate != null
                              ? Text(
                                  DateFormat(
                                    'dd MMMM yyyy',
                                    'lo',
                                  ).format(selectedDate!),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                if (isEditing)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop('DELETE'),
                    child: const Text(
                      'ລົບ',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('ຍົກເລີກ'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final budget = QuarterlyBudgetModel(
                        id: existingBudget?.id,
                        parentId: parentId,
                        quarterNumber: quarterNumber,
                        amountKip:
                            double.tryParse(
                              amountKipController.text.replaceAll(',', ''),
                            ) ??
                            0.0,
                        amountThb:
                            double.tryParse(
                              amountThbController.text.replaceAll(',', ''),
                            ) ??
                            0.0,
                        amountUsd:
                            double.tryParse(
                              amountUsdController.text.replaceAll(',', ''),
                            ) ??
                            0.0,
                        selectedDate: selectedDate,
                        notes: notesController.text.isNotEmpty ? notesController.text : null,
                      );
                      Navigator.of(context).pop(budget);
                    }
                  },
                  child: const Text('ບັນທຶກ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool?> _showDeleteQuarterConfirmation(
    BuildContext context,
    int quarterNumber,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('ຢືນຢັນການລົບ'),
          content: Text('ທ່ານຕ້ອງການລົບງວດທີ່ $quarterNumber ແມ່ນບໍ່?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('ຍົກເລີກ'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('ລົບ'),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _showNotesDialog(BuildContext context, String notes) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ໝາຍເຫດ'),
          content: SingleChildScrollView(
            child: Text(notes),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('ປິດ'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class _AddEditSubItemDialog extends StatefulWidget {
  final ItemModel mainItem;
  final SubItemModel? existingSubItem;
  final int? childOf;
  final Map<int?, List<SubItemModel>> hierarchy;
  final Future<void> Function({required SubItemModel itemToSave, int? oldSortOrder}) onSave;

  const _AddEditSubItemDialog({
    required this.mainItem,
    this.existingSubItem,
    this.childOf,
    required this.hierarchy,
    required this.onSave,
  });

  @override
  State<_AddEditSubItemDialog> createState() => _AddEditSubItemDialogState();
}

class _AddEditSubItemDialogState extends State<_AddEditSubItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _titlePrefix;
  late TextEditingController _sortOrderController;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _quantityController;
  String? _selectedUnit;
  DateTime? _selectedDate;
  DateSelectionOption _dateSelectionOption = DateSelectionOption.none;
  int? _oldSortOrder;

  late List<CostModel> _costs;
  final List<TextEditingController> _costDescControllers = [];
  final List<TextEditingController> _costAmountControllers = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    final isEditing = widget.existingSubItem != null;
    final siblings = widget.hierarchy[widget.childOf] ?? [];

    if (isEditing) {
      final subItem = widget.existingSubItem!;
      final titleParts = subItem.title.split(' ');
      _titlePrefix = titleParts.first;
      _titleController = TextEditingController(text: titleParts.skip(1).join(' '));
      _sortOrderController = TextEditingController(text: subItem.sortOrder.toString());
      _oldSortOrder = subItem.sortOrder;

      _descriptionController = TextEditingController(text: subItem.description);
      _quantityController = TextEditingController(text: subItem.quantity?.toString() ?? '');
      _selectedUnit = subItem.unit;
      _selectedDate = subItem.selectedDate;
      if (_selectedDate != null) {
        _dateSelectionOption = DateSelectionOption.manual;
      }
      _costs = List<CostModel>.from(subItem.costs.map((c) => CostModel(description: c.description, amount: c.amount, currency: c.currency)));
      if (_costs.isEmpty) {
        _costs.addAll([
          CostModel(description: 'ຄ່າແຮງ', currency: Currency.KIP.code),
          CostModel(description: 'ຄ່າວັດສະດຸ', currency: Currency.KIP.code),
        ]);
      }
    } else {
      if (widget.childOf == null) {
        _titlePrefix = widget.mainItem.title.split('. ').first;
      } else {
        // This logic needs all items, not just hierarchy, to be safe.
        // However, for dialog init, this should be okay as hierarchy is passed in.
        final parentItem = widget.hierarchy.values.expand((list) => list).firstWhere((item) => item.id == widget.childOf);
        _titlePrefix = parentItem.title.split(' ').first;
      }
      
      final nextSortOrder = (siblings.isNotEmpty ? siblings.map((s) => s.sortOrder).reduce((a, b) => a > b ? a : b) : 0) + 1;
      _sortOrderController = TextEditingController(text: nextSortOrder.toString());
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _quantityController = TextEditingController();
      _costs = [
        CostModel(description: 'ຄ່າແຮງ', currency: Currency.KIP.code),
        CostModel(description: 'ຄ່າວັດສະດຸ', currency: Currency.KIP.code),
      ];
    }

    for (var cost in _costs) {
      _addControllersForCost(cost);
    }
  }

  void _addControllersForCost(CostModel cost) {
    _costDescControllers.add(TextEditingController(text: cost.description));
    _costAmountControllers.add(TextEditingController(
      text: cost.amount > 0 ? NumberFormat("#,##0").format(cost.amount) : '',
    ));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _sortOrderController.dispose();
    for (var controller in _costDescControllers) {
      controller.dispose();
    }
    for (var controller in _costAmountControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addNewCostItem() {
    setState(() {
      final newCost = CostModel(description: '', currency: Currency.KIP.code);
      _costs.add(newCost);
      _addControllersForCost(newCost);
    });
  }

  void _removeCostItem(int index) {
    setState(() {
      _costs.removeAt(index);
      _costDescControllers.removeAt(index).dispose();
      _costAmountControllers.removeAt(index).dispose();
    });
  }

  void _saveForm() async {
    if (_formKey.currentState!.validate()) {
      for (int i = 0; i < _costs.length; i++) {
        _costs[i].description = _costDescControllers[i].text;
        _costs[i].amount = double.tryParse(_costAmountControllers[i].text.replaceAll(',', '')) ?? 0.0;
      }

      // Title will be constructed by the backend logic, we just need to pass the description part
      final descriptionPart = _titleController.text.trim();
      // We pass a temporary title, the real one is set in _saveSubItemAndReorder
      final tempTitle = '${_titlePrefix}.x $descriptionPart';

      final subItemToSave = SubItemModel(
        id: widget.existingSubItem?.id,
        parentId: widget.mainItem.id!,
        childOf: widget.childOf,
        title: widget.existingSubItem?.title ?? tempTitle, // Use old title to preserve description part
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        quantity: double.tryParse(_quantityController.text),
        unit: _selectedUnit,
        selectedDate: _selectedDate,
        costs: _costs.where((c) => c.description.isNotEmpty && c.amount > 0).toList(),
        sortOrder: int.tryParse(_sortOrderController.text) ?? 999,
      );

      await widget.onSave(itemToSave: subItemToSave, oldSortOrder: _oldSortOrder);
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingSubItem != null;
    final List<String> units = ['m', 'm²', 'm³', 'kg', 'unit', 'No Unit', 'ໂຕນ', 'ອັນ', 'ແກັດ', ' '];

    return AlertDialog(
      title: Text(isEditing ? 'ແກ້ໄຂລາຍການ' : 'ເພີ່ມລາຍການຍ່ອຍ'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$_titlePrefix.', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 40,
                      child: TextFormField(
                        controller: _sortOrderController,
                        decoration: const InputDecoration(labelText: 'ລຳດັບ'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) => v!.isEmpty ? 'ใส่' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'ຫົວຂໍ້'),
                        validator: (v) => v!.isEmpty ? 'ກະລຸນາປ້ອນຫົວຂໍ້ກ່ອນ' : null,
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'ລາຍລະອຽດ (ລົງແຖວເພື່ອເພີ່ມລາຍການ)'),
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(labelText: 'ຈຳນວນ'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _selectedUnit,
                        hint: const Text('ໜ່ວຍ'),
                        items: units.map((String unit) => DropdownMenuItem<String>(value: unit, child: Text(unit))).toList(),
                        onChanged: (newValue) => setState(() => _selectedUnit = newValue),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text('ລາຍການຄ່າໃຊ້ຈ່າຍ', style: AppTextStyles.bodyBold),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _costs.length,
                  itemBuilder: (context, index) {
                    return _buildCostRow(index);
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('ເພີ່ມລາຍການ'),
                    onPressed: _addNewCostItem,
                  ),
                ),
                const Divider(height: 24),
                const Text('ຕັ້ງຄ່າວັນທີ', style: AppTextStyles.bodyBold),
                Column(
                  children: [
                    RadioListTile<DateSelectionOption>(
                      title: const Text('ບໍ່ລະບຸວັນທີ'),
                      value: DateSelectionOption.none,
                      groupValue: _dateSelectionOption,
                      onChanged: (value) {
                        setState(() {
                          _dateSelectionOption = value!;
                          _selectedDate = null;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<DateSelectionOption>(
                      title: const Text('ໃຊ້ວັນທີປັດຈຸບັນ'),
                      value: DateSelectionOption.today,
                      groupValue: _dateSelectionOption,
                      onChanged: (value) {
                        setState(() {
                          _dateSelectionOption = value!;
                          _selectedDate = DateTime.now();
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<DateSelectionOption>(
                      title: const Text('ເລືອກດ້ວຍຕົວເອງ'),
                      value: DateSelectionOption.manual,
                      groupValue: _dateSelectionOption,
                      onChanged: (value) {
                        setState(() {
                          _dateSelectionOption = value!;
                          if (widget.existingSubItem?.selectedDate == null) {
                            _selectedDate = null;
                          }
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
                if (_dateSelectionOption == DateSelectionOption.today && _selectedDate != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                    child: Text(
                      'ວັນທີທີ່ເລືອກ: ${DateFormat('dd MMMM yyyy', 'lo').format(_selectedDate!)}',
                      style: AppTextStyles.body.copyWith(color: AppColors.primary),
                    ),
                  ),
                if (_dateSelectionOption == DateSelectionOption.manual)
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: const Text('ເລືອກວັນທີ'),
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              locale: const Locale('lo'),
                              initialDate: _selectedDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2101),
                            );
                            if (picked != null && picked != _selectedDate) {
                              setState(() {
                                _selectedDate = picked;
                              });
                            }
                          },
                        ),
                        if (_selectedDate != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'ວັນທີທີ່ເລືອກ: ${DateFormat('dd MMMM yyyy', 'lo').format(_selectedDate!)}',
                            style: AppTextStyles.body.copyWith(color: AppColors.primary),
                          ),
                        ]
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('ຍົກເລີກ')),
        ElevatedButton(onPressed: _saveForm, child: const Text('ບັນທຶກ')),
      ],
    );
  }

  Widget _buildCostRow(int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            flex: 4,
            child: TextFormField(
              controller: _costDescControllers[index],
              decoration: InputDecoration(labelText: 'ລາຍການ ${index + 1}'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: _costAmountControllers[index],
              decoration: const InputDecoration(labelText: 'ຈຳນວນເງິນ'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: _costs[index].currency,
              items: Currency.values.map((c) => DropdownMenuItem(value: c.code, child: Text(c.symbol))).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _costs[index].currency = v;
                  });
                }
              },
            ),
          ),
          if (_costs.length > 1)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
              onPressed: () => _removeCostItem(index),
            )
          else 
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class SubItemCard extends StatefulWidget {
  final SubItemModel subItem;
  final ItemModel mainItem;
  final Map<String, dynamic> calculatedTotals;
  final VoidCallback onAddChild;

  const SubItemCard({
    super.key,
    required this.subItem,
    required this.mainItem,
    required this.calculatedTotals,
    required this.onAddChild,
  });

  @override
  State<SubItemCard> createState() => _SubItemCardState();
}

class _SubItemCardState extends State<SubItemCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              if (widget.subItem.selectedDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat(
                          'dd/MM/yyyy',
                        ).format(widget.subItem.selectedDate!),
                        style: AppTextStyles.body.copyWith(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: widget.subItem.selectedDate != null ? 8 : 0),
              _buildFinancials(context),
              const Divider(height: 24),
              _buildShowMoreButton(),
              if (_isExpanded) _buildExpandedContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final vm = Provider.of<HomeViewModel>(context, listen: false);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(widget.subItem.title, style: AppTextStyles.heading),
        ),
        SizedBox(
          width: 24,
          height: 24,
          child: PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            onSelected: (value) async {
              if (value == 'edit') {
                final bool? result =
                    await (context.findAncestorStateOfType<_DetailPageState>())
                        ?._showAddEditSubItemDialog(
                          context,
                          item: widget.mainItem,
                          existingSubItem: widget.subItem,
                          childOf: widget.subItem.childOf,
                        );
                if (result == true) {
                  // No need to reload here, it's handled by the onSave callback
                }
              } else if (value == 'delete') {
                (context.findAncestorStateOfType<_DetailPageState>())
                    ?._showDeleteSubItemConfirmation(context, widget.subItem);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'edit', child: Text('ແກ້ໄຂ')),
              const PopupMenuItem<String>(value: 'delete', child: Text('ລົບ')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinancials(BuildContext context) {
    final vm = Provider.of<HomeViewModel>(context);
    final Map<String, double> costs = widget.calculatedTotals['costs'] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ຄ່າໃຊ້ຈ່າຍທັງໝົດ:', style: AppTextStyles.body),
        _buildCardFinancialDetailRow(
          currency: Currency.KIP,
          cost: costs[Currency.KIP.code] ?? 0.0,
          totalBudget: _getRelevantBudget(Currency.KIP.code),
          isVisible: vm.areAmountsVisible,
        ),
        _buildCardFinancialDetailRow(
          currency: Currency.THB,
          cost: costs[Currency.THB.code] ?? 0.0,
          totalBudget: _getRelevantBudget(Currency.THB.code),
          isVisible: vm.areAmountsVisible,
        ),
        _buildCardFinancialDetailRow(
          currency: Currency.USD,
          cost: costs[Currency.USD.code] ?? 0.0,
          totalBudget: _getRelevantBudget(Currency.USD.code),
          isVisible: vm.areAmountsVisible,
        ),
      ],
    );
  }

  double _getRelevantBudget(String currencyCode) {
    switch (currencyCode) {
      case 'KIP':
        return widget.mainItem.amount;
      case 'THB':
        return widget.mainItem.amountThb;
      case 'USD':
        return widget.mainItem.amountUsd;
      default:
        return 0.0;
    }
  }

  Widget _buildCardFinancialDetailRow({
    required Currency currency,
    required double cost,
    required double totalBudget,
    required bool isVisible,
  }) {
    if (cost == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4.0, left: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isVisible
                ? '${NumberFormat("#,##0.##").format(cost)} ${currency.symbol}'
                : '*********** ${currency.symbol}',
            style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 4),
          AnimatedProgressBar(
            value: cost,
            total: totalBudget,
            currency: currency,
          ),
        ],
      ),
    );
  }

  Widget _buildShowMoreButton() {
    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isExpanded ? 'ສະແດງໜ້ອຍລົງ' : 'ສະແດງເພີ່ມເຕີມ',
              style: AppTextStyles.body.copyWith(color: AppColors.primary),
            ),
            Icon(
              _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: AppColors.primary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent() {
    final descriptionWidgets = (widget.subItem.description ?? '')
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map(
          (line) => Padding(
            padding: const EdgeInsets.only(left: 8.0, top: 2.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('o ', style: AppTextStyles.body),
                Expanded(child: Text(line, style: AppTextStyles.body)),
              ],
            ),
          ),
        )
        .toList();

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (descriptionWidgets.isNotEmpty) ...[
            Text(
              'ລາຍລະອຽດ:',
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            ...descriptionWidgets,
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ຈຳນວນທັງໝົດ:',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${NumberFormat.decimalPattern().format(widget.calculatedTotals['quantity'] ?? 0)} ${widget.subItem.unit ?? ""}',
                style: AppTextStyles.bodyBold,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: widget.onAddChild,
              icon: const Icon(Icons.add),
              label: const Text('ເພີ່ມລາຍການຍ່ອຍ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
