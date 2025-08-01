import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../services/pdf_exporter.dart';

ItemModel _processItemData(Map<String, Object?> itemMap) {
  return ItemModel.fromMap(itemMap);
}

// enum สำหรับจัดการตัวเลือกวันที่ในหน้านี้
enum DateSelectionOption { none, today, manual }

class DetailPage extends StatefulWidget {
  final int itemId;
  const DetailPage({super.key, required this.itemId});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late Future<ItemModel> _itemDetailFuture;
  final ScrollController _scrollController = ScrollController();
  late PageController _pageController;
  bool _isScrolled = false;

  List<SubItemModel> _subItemsTree = [];
  Map<int?, List<SubItemModel>> _hierarchy = {};
  Map<int, Map<String, dynamic>> _calculatedTotals = {};
  bool _isSubItemsLoading = true;

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
    final item = await (_itemDetailFuture = _loadItemDetails());
    await _loadAndStructureSubItems();
    await _loadQuarterlyBudgets(item);
  }

  Future<void> _loadQuarterlyBudgets(ItemModel item) async {
    setState(() => _isBudgetsLoading = true);
    var budgets = await DBService.instance.readQuarterlyBudgetsForParent(
      widget.itemId,
    );

    if (budgets.isEmpty) {
      final firstQuarter = QuarterlyBudgetModel(
        parentId: widget.itemId,
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

  Future<ItemModel> _loadItemDetails() async {
    final itemMap = await DBService.instance.readItemAsMap(widget.itemId);
    return await compute(_processItemData, itemMap);
  }

  Future<void> _loadAndStructureSubItems() async {
    setState(() => _isSubItemsLoading = true);
    try {
      final allSubItems = await DBService.instance.readSubItemsForParent(
        widget.itemId,
      );

      final hierarchy = <int?, List<SubItemModel>>{};
      for (final subItem in allSubItems) {
        hierarchy.putIfAbsent(subItem.childOf, () => []).add(subItem);
      }
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
    } finally {
      setState(() => _isSubItemsLoading = false);
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

    if (item.laborCost != null &&
        item.laborCost! > 0 &&
        item.laborCostCurrency != null) {
      totalCosts[item.laborCostCurrency!] =
          (totalCosts[item.laborCostCurrency!] ?? 0) + item.laborCost!;
    }
    if (item.materialCost != null &&
        item.materialCost! > 0 &&
        item.materialCostCurrency != null) {
      totalCosts[item.materialCostCurrency!] =
          (totalCosts[item.materialCostCurrency!] ?? 0) + item.materialCost!;
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

  Future<void> _updateSubItemOrder(int? childOf) async {
    final allSubItems = await DBService.instance.readSubItemsForParent(
      widget.itemId,
    );
    final siblings = allSubItems
        .where((item) => item.childOf == childOf)
        .toList();
    siblings.sort((a, b) => a.id!.compareTo(b.id!));

    final List<SubItemModel> itemsToUpdate = [];
    final item = await _itemDetailFuture;
    final parentPrefix =
        _hierarchy[childOf]?.first.title.split('.').first ??
        item.title.split('. ').first;

    for (int i = 0; i < siblings.length; i++) {
      final subItem = siblings[i];
      final newIndex = i + 1;

      String currentPrefix;
      String currentDescription;

      int firstSpaceIndex = subItem.title.indexOf(' ');
      if (firstSpaceIndex != -1) {
        currentPrefix = subItem.title.substring(0, firstSpaceIndex);
        currentDescription = subItem.title.substring(firstSpaceIndex + 1);
      } else {
        currentPrefix = subItem.title;
        currentDescription = '';
      }

      String newPrefix;
      if (childOf == null) {
        newPrefix = '${parentPrefix}.$newIndex';
      } else {
        final parent = allSubItems.firstWhere((it) => it.id == childOf);
        final parentTitlePrefix = parent.title.split(' ').first;
        newPrefix = '$parentTitlePrefix.$newIndex';
      }

      if (currentPrefix != newPrefix) {
        final newTitle = '$newPrefix $currentDescription'.trim();
        itemsToUpdate.add(subItem.copyWith(title: newTitle));
      }
    }

    if (itemsToUpdate.isNotEmpty) {
      await DBService.instance.updateSubItems(itemsToUpdate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ItemModel>(
      future: _itemDetailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        } else if (snapshot.hasError) {
          return _buildErrorScreen(snapshot.error);
        } else if (snapshot.hasData) {
          final item = snapshot.data!;
          return _buildDetailContent(context, item);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }

  Widget _buildErrorScreen(Object? error) {
    return Scaffold(
      backgroundColor: AppColors.danger,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'ເກີດຂໍ້ຜິດພາດໃນການໂຫຼດຂໍ້ມູນ:\n$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ),
    );
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
                  gradient: headerGradient, // ใช้ Gradient เป็น Fallback
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
                  await _loadAndStructureSubItems();
                  Provider.of<HomeViewModel>(
                    context,
                    listen: false,
                  ).loadItems();
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
                    /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
                    IconButton(
                      icon: Icon(
                        Icons.picture_as_pdf_outlined,
                        color: _isScrolled
                            ? AppColors.primary
                            : AppColors.textOnPrimary,
                      ),
                      onPressed: () async {
                        // เพิ่มการเรียกใช้ PDF Exporter
                        await PdfExporter.generateAndPrintPdf(
                          item,
                          _subItemsTree,
                          _hierarchy,
                          _calculatedTotals,
                        );
                      },
                    ),
                    /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
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
                      child: _isSubItemsLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _subItemsTree.isEmpty
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
                    parentTitlePrefix: subItem.title.split(' ').first,
                  );
                  if (result == true) {
                    await _loadAndStructureSubItems();
                    Provider.of<HomeViewModel>(
                      context,
                      listen: false,
                    ).loadItems();
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
                  Spacer(),
                  if (budget.selectedDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd/MM/yyyy').format(budget.selectedDate!),
                      style: AppTextStyles.subText.copyWith(fontSize: 12),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              _buildAmountText(Currency.KIP, budget.amountKip, isVisible),
              _buildAmountText(Currency.THB, budget.amountThb, isVisible),
              _buildAmountText(Currency.USD, budget.amountUsd, isVisible),
              
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
                await _updateSubItemOrder(parentId);
                Navigator.of(dialogContext).pop();
                _loadAndStructureSubItems();
                Provider.of<HomeViewModel>(context, listen: false).loadItems();
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
    String? parentTitlePrefix,
  }) {
    final bool isEditing = existingSubItem != null;
    final formKey = GlobalKey<FormState>();

    String titlePrefix = '';
    String descriptiveTitle = '';

    if (isEditing) {
      int firstSpaceIndex = existingSubItem!.title.indexOf(' ');
      if (firstSpaceIndex != -1) {
        titlePrefix = existingSubItem.title.substring(0, firstSpaceIndex);
        descriptiveTitle = existingSubItem.title.substring(firstSpaceIndex + 1);
      } else {
        titlePrefix = existingSubItem.title;
        descriptiveTitle = '';
      }
    } else {
      final siblings = _hierarchy[childOf] ?? [];
      siblings.sort((a, b) => a.id!.compareTo(b.id!));
      final newIndex = siblings.length + 1;
      final prefix = parentTitlePrefix ?? item.title.split('. ').first;
      titlePrefix = '$prefix.$newIndex';
    }

    final titleController = TextEditingController(text: descriptiveTitle);

    final descriptionController = TextEditingController(
      text: existingSubItem?.description,
    );
    final quantityController = TextEditingController(
      text: existingSubItem?.quantity?.toString() ?? '',
    );
    final laborCostController = TextEditingController(
      text: existingSubItem?.laborCost != null
          ? NumberFormat("#,##0").format(existingSubItem!.laborCost)
          : '',
    );
    final materialCostController = TextEditingController(
      text: existingSubItem?.materialCost != null
          ? NumberFormat("#,##0").format(existingSubItem!.materialCost)
          : '',
    );

    String? selectedUnit = existingSubItem?.unit;
    DateTime? selectedDate = existingSubItem?.selectedDate;

    // ประกาศ state variable สำหรับสกุลเงิน
    String selectedLaborCurrency =
        existingSubItem?.laborCostCurrency ?? Currency.KIP.code;
    String selectedMaterialCurrency =
        existingSubItem?.materialCostCurrency ?? Currency.KIP.code;

    // กำหนดค่าเริ่มต้นของตัวเลือกวันที่
    DateSelectionOption dateSelectionOption = DateSelectionOption.none;
    if (selectedDate != null) {
      dateSelectionOption = DateSelectionOption.manual;
    }

    final List<String> units = [
      'm',
      'm²',
      'm³',
      'kg',
      'unit',
      'No Unit',
      'ໂຕນ',
      'ອັນ',
      'ແກັດ',
      ' ',
    ];

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                isEditing ? 'ແກ້ໄຂ: $titlePrefix' : 'ເພີ່ມລາຍການຍ່ອຍ',
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isEditing)
                        Text(
                          "ຫົວຂໍ້: $titlePrefix",
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'ຫົວຂໍ້'),
                        validator: (v) =>
                            v!.isEmpty ? 'ກະລຸນາປ້ອນຫົວຂໍ້ກ່ອນ' : null,
                      ),
                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'ລາຍລະອຽດ (ລົງແຖວເພື່ອເພີ່ມລາຍການ)',
                        ),
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
                              controller: quantityController,
                              decoration: const InputDecoration(
                                labelText: 'ຈຳນວນ',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              value: selectedUnit,
                              hint: const Text('ໜ່ວຍ'),
                              items: units
                                  .map(
                                    (String unit) => DropdownMenuItem<String>(
                                      value: unit,
                                      child: Text(unit),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (newValue) =>
                                  setStateDialog(() => selectedUnit = newValue),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: laborCostController,
                              decoration: const InputDecoration(
                                labelText: 'ຄ່າແຮງ',
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                CurrencyInputFormatter(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: selectedLaborCurrency,
                              items: Currency.values
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c.code,
                                      child: Text(c.symbol),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                setStateDialog(() {
                                  selectedLaborCurrency = v!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: materialCostController,
                              decoration: const InputDecoration(
                                labelText: 'ຄ່າວັດສະດຸ',
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                CurrencyInputFormatter(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: selectedMaterialCurrency,
                              items: Currency.values
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c.code,
                                      child: Text(c.symbol),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                setStateDialog(() {
                                  selectedMaterialCurrency = v!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // UI ใหม่สำหรับเลือกวันที่ (พร้อมคำแปลภาษาลาว)
                      const Text('ຕັ້ງຄ່າວັນທີ', style: AppTextStyles.bodyBold),
                      Column(
                        children: [
                          RadioListTile<DateSelectionOption>(
                            title: const Text('ບໍ່ລະບຸວັນທີ'),
                            value: DateSelectionOption.none,
                            groupValue: dateSelectionOption,
                            onChanged: (value) {
                              setStateDialog(() {
                                dateSelectionOption = value!;
                                selectedDate = null;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                          RadioListTile<DateSelectionOption>(
                            title: const Text('ໃຊ້ວັນທີປັດຈຸບັນ'),
                            value: DateSelectionOption.today,
                            groupValue: dateSelectionOption,
                            onChanged: (value) {
                              setStateDialog(() {
                                dateSelectionOption = value!;
                                selectedDate = DateTime.now();
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                          RadioListTile<DateSelectionOption>(
                            title: const Text('ເລືອກດ້ວຍຕົວເອງ'),
                            value: DateSelectionOption.manual,
                            groupValue: dateSelectionOption,
                            onChanged: (value) {
                              setStateDialog(() {
                                dateSelectionOption = value!;
                                if (existingSubItem?.selectedDate == null) {
                                  selectedDate = null;
                                }
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      if (dateSelectionOption == DateSelectionOption.today &&
                          selectedDate != null)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 16.0,
                            bottom: 8.0,
                          ),
                          child: Text(
                            'ວັນທີທີ່ເລືອກ: ${DateFormat('dd MMMM yyyy', 'lo').format(selectedDate!)}',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      if (dateSelectionOption == DateSelectionOption.manual)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 16.0,
                            bottom: 8.0,
                          ),
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
                                    initialDate: selectedDate ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2101),
                                  );
                                  if (picked != null &&
                                      picked != selectedDate) {
                                    setStateDialog(() {
                                      selectedDate = picked;
                                    });
                                  }
                                },
                              ),
                              if (selectedDate != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'ວັນທີທີ່ເລືອກ: ${DateFormat('dd MMMM yyyy', 'lo').format(selectedDate!)}',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('ຍົກເລີກ'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final laborCost =
                          double.tryParse(
                            laborCostController.text.replaceAll(',', ''),
                          ) ??
                          0.0;
                      final materialCost =
                          double.tryParse(
                            materialCostController.text.replaceAll(',', ''),
                          ) ??
                          0.0;
                      final finalTitle = '$titlePrefix ${titleController.text}'
                          .trim();

                      if (isEditing) {
                        final updatedItem = SubItemModel(
                          id: existingSubItem!.id,
                          parentId: existingSubItem.parentId,
                          childOf: existingSubItem.childOf,
                          title: finalTitle,
                          description: descriptionController.text.isNotEmpty
                              ? descriptionController.text
                              : null,
                          quantity: double.tryParse(quantityController.text),
                          unit: selectedUnit,
                          laborCost: laborCost,
                          laborCostCurrency: laborCost > 0
                              ? selectedLaborCurrency
                              : null,
                          materialCost: materialCost,
                          materialCostCurrency: materialCost > 0
                              ? selectedMaterialCurrency
                              : null,
                          selectedDate: selectedDate,
                        );
                        await DBService.instance.updateSubItem(updatedItem);
                      } else {
                        final newSubItem = SubItemModel(
                          parentId: item.id!,
                          childOf: childOf,
                          title: finalTitle,
                          description: descriptionController.text.isNotEmpty
                              ? descriptionController.text
                              : null,
                          quantity: double.tryParse(quantityController.text),
                          unit: selectedUnit,
                          laborCost: laborCost,
                          laborCostCurrency: laborCost > 0
                              ? selectedLaborCurrency
                              : null,
                          materialCost: materialCost,
                          materialCostCurrency: materialCost > 0
                              ? selectedMaterialCurrency
                              : null,
                          selectedDate: selectedDate,
                        );
                        await DBService.instance.createSubItem(newSubItem);
                      }
                      Navigator.of(dialogContext).pop(true);
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
              content: Form(
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
              actions: [
                if (isEditing)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop('DELETE'),
                    child: const Text(
                      'ລົບ',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                const Spacer(),
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
              // ย้ายวันที่มาแสดงผลตรงนี้
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
                  (context.findAncestorStateOfType<_DetailPageState>())
                      ?._loadAndStructureSubItems();
                  vm.loadItems();
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
          // ลบวันที่ออกจากส่วนนี้ เพราะย้ายไปแสดงด้านบนแล้ว
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
