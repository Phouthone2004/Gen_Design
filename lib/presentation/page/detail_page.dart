import 'dart:async';
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

  List<SubItemModel> _subItems = [];
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
    await _loadSubItems();
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

  Future<void> _loadSubItems() async {
    setState(() {
      _isSubItemsLoading = true;
    });
    try {
      final subItems = await DBService.instance.readSubItemsForParent(
        widget.itemId,
      );
      subItems.sort((a, b) => a.id!.compareTo(b.id!));
      setState(() {
        _subItems = subItems;
      });
    } catch (e) {
      print('Error loading sub-items: $e');
    } finally {
      setState(() {
        _isSubItemsLoading = false;
      });
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
          decoration: const BoxDecoration(gradient: headerGradient),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: FloatingActionButton(
              onPressed: () async {
                final bool? result = await _showAddEditSubItemDialog(
                  context,
                  item.id!,
                );
                if (result == true) {
                  await _loadSubItems();
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
                    IconButton(
                      icon: Icon(
                        Icons.picture_as_pdf_outlined,
                        color: _isScrolled
                            ? AppColors.primary
                            : AppColors.textOnPrimary,
                      ),
                      onPressed: () async {
                        // PDF export logic
                      },
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
                      child: _isSubItemsLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _subItems.isEmpty
                          ? _buildEmptySubItems()
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _subItems.length,
                              itemBuilder: (context, index) {
                                final subItem = _subItems[index];
                                return SubItemCard(
                                  subItem: subItem,
                                  mainItem: item,
                                );
                              },
                            ),
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

  // --- CHANGE 1: คำนวณจำนวนหน้าทั้งหมด (ไตรมาส + ปุ่มเพิ่ม 1) ---
  final int pageCount = _quarterlyBudgets.length + 1;

  return Row(
    // crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      // Total Budget Display (ส่วนนี้ไม่ต้องแก้ไข)
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'ງົບໄຕມາດທັງໝົດ',
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
      // Scrollable Quarterly Cards
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
                      onPageChanged: (index) {
                        setState(() {
                          _currentPageIndex = index;
                        });
                      },
                      // --- CHANGE 2: ใช้ pageCount ที่คำนวณไว้ ---
                      itemCount: pageCount,
                      itemBuilder: (context, index) {
                        // --- CHANGE 3: เช็คว่าเป็นหน้าสุดท้ายหรือไม่ ---
                        // ถ้าเป็นหน้าสุดท้าย (index เท่ากับจำนวนไตรมาส) ให้แสดงปุ่มเพิ่ม
                        if (index == _quarterlyBudgets.length) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: _buildAddQuarterButton(item),
                            ),
                          );
                        }
                        // ถ้าไม่ใช่หน้าสุดท้าย ให้แสดงการ์ดไตรมาสตามปกติ
                        final budget = _quarterlyBudgets[index];
                        return _buildQuarterCard(item, budget, isVisible);
                      },
                    ),
            ),
            // --- CHANGE 4: อัปเดตตัว Indicators ให้ใช้ pageCount ---
            if (pageCount > 1) // แสดง Indicators ถ้ามีมากกว่า 1 หน้า
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(pageCount, (index) { // ใช้ pageCount
                    return Container(
                      width: 8.0,
                      height: 8.0,
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPageIndex == index
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                      ),
                    );
                  }),
                ),
              ),
            // --- CHANGE 5: ลบปุ่มเดิมที่อยู่ข้างล่างออก ---
            // const SizedBox(height: 12),
            // Center(child: _buildAddQuarterButton(item)),
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
          final updatedBudget = await _showAddEditQuarterDialog(
            context,
            item.id!,
            budget.quarterNumber,
            existingBudget: budget,
          );
          if (updatedBudget != null) {
            await DBService.instance.updateQuarterlyBudget(updatedBudget);
            await _loadQuarterlyBudgets(item);
            vm.loadItems();
          }
        },
        onLongPress: () async {
          final bool? confirmDelete = await _showDeleteQuarterConfirmation(
            context,
            budget.quarterNumber,
          );
          if (confirmDelete == true) {
            await DBService.instance.deleteQuarterlyBudget(budget.id!);
            await _loadQuarterlyBudgets(item);
            vm.loadItems();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ໄຕມາດ ${budget.quarterNumber}',
                style: AppTextStyles.subheading.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              _buildAmountText(Currency.KIP, budget.amountKip, isVisible),
              _buildAmountText(Currency.THB, budget.amountThb, isVisible),
              _buildAmountText(Currency.USD, budget.amountUsd, isVisible),
              if (budget.selectedDate != null) ...[
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd/MM/yyyy').format(budget.selectedDate!),
                  style: AppTextStyles.subText.copyWith(fontSize: 10),
                ),
              ],
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
        if (newBudget != null) {
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
        child: const Icon(Icons.add_circle_outline, color: Colors.white, size: 40),
      ),
    );
  }

  Widget _buildAmountText(Currency currency, double amount, bool isVisible) {
    if (amount == 0) return const SizedBox.shrink();
    return Text(
      isVisible
          ? '${NumberFormat("#,##0.##").format(amount)} ${currency.symbol}'
          : '*********** ${currency.symbol}',
      style: AppTextStyles.subText
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
          content: Text('ທ່ານຕ້ອງການລົບລາຍການ "${subItem.title}" ແມ່ນບໍ່?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('ຍົກເລີກ'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () async {
                await DBService.instance.deleteSubItem(subItem.id!);
                Navigator.of(dialogContext).pop();
                _loadSubItems();
                Provider.of<HomeViewModel>(context, listen: false).loadItems();
              },
              child: const Text('ລົບ'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showAddEditSubItemDialog(
    BuildContext context,
    int parentId, {
    SubItemModel? existingSubItem,
  }) {
    final bool isEditing = existingSubItem != null;
    final formKey = GlobalKey<FormState>();

    final titleController = TextEditingController(text: existingSubItem?.title);
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
    bool showCalendar = existingSubItem?.selectedDate != null;
    String selectedLaborCurrency =
        existingSubItem?.laborCostCurrency ?? Currency.KIP.code;
    String selectedMaterialCurrency =
        existingSubItem?.materialCostCurrency ?? Currency.KIP.code;

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
              title: Text(isEditing ? 'ແກ້ໄຂລາຍການຍ່ອຍ' : 'ເພິ້ມລາຍການຍ່ອຍ'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'ຫົວຂໍ້'),
                        validator: (v) =>
                            v!.isEmpty ? 'ກະລຸນາປ້ອນຫົວຂໍ້' : null,
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
                              onChanged: (newValue) {
                                setStateDialog(() {
                                  selectedUnit = newValue;
                                });
                              },
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
                              onChanged: (v) => setStateDialog(
                                () => selectedLaborCurrency = v!,
                              ),
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
                              onChanged: (v) => setStateDialog(
                                () => selectedMaterialCurrency = v!,
                              ),
                            ),
                          ),
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

                      if (isEditing) {
                        final updatedItem = SubItemModel(
                          id: existingSubItem!.id,
                          parentId: existingSubItem.parentId,
                          title: titleController.text,
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
                          parentId: parentId,
                          title: titleController.text,
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

  Future<QuarterlyBudgetModel?> _showAddEditQuarterDialog(
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

    return showDialog<QuarterlyBudgetModel>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                isEditing
                    ? 'ແກ້ໄຂງົບໄຕມາດ $quarterNumber'
                    : 'ເພີ່ມງົບໄຕມາດ $quarterNumber',
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
          content: Text('ທ່ານຕ້ອງການລົບງົບໄຕມາດ $quarterNumber ແມ່ນບໍ່?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('ຍົກເລີກ'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('ລົບ'),
            ),
          ],
        );
      },
    );
  }
}

// --- Sub Item Card Widget ---
class SubItemCard extends StatefulWidget {
  final SubItemModel subItem;
  final ItemModel mainItem;
  const SubItemCard({super.key, required this.subItem, required this.mainItem});

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
              const SizedBox(height: 8),
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
                          widget.subItem.parentId,
                          existingSubItem: widget.subItem,
                        );
                if (result == true) {
                  (context.findAncestorStateOfType<_DetailPageState>())
                      ?._loadSubItems();
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
    final laborCost = widget.subItem.laborCost ?? 0.0;
    final materialCost = widget.subItem.materialCost ?? 0.0;

    final subItemCosts = {for (var c in Currency.values) c.code: 0.0};
    if (laborCost > 0 && widget.subItem.laborCostCurrency != null) {
      subItemCosts[widget.subItem.laborCostCurrency!] =
          (subItemCosts[widget.subItem.laborCostCurrency!] ?? 0) + laborCost;
    }
    if (materialCost > 0 && widget.subItem.materialCostCurrency != null) {
      subItemCosts[widget.subItem.materialCostCurrency!] =
          (subItemCosts[widget.subItem.materialCostCurrency!] ?? 0) +
          materialCost;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ຄ່າໃຊ້ຈ່າຍ:', style: AppTextStyles.body),
        _buildCardFinancialDetailRow(
          currency: Currency.KIP,
          budget: widget.mainItem.amount,
          cost: subItemCosts[Currency.KIP.code] ?? 0.0,
          isVisible: vm.areAmountsVisible,
        ),
        _buildCardFinancialDetailRow(
          currency: Currency.THB,
          budget: widget.mainItem.amountThb,
          cost: subItemCosts[Currency.THB.code] ?? 0.0,
          isVisible: vm.areAmountsVisible,
        ),
        _buildCardFinancialDetailRow(
          currency: Currency.USD,
          budget: widget.mainItem.amountUsd,
          cost: subItemCosts[Currency.USD.code] ?? 0.0,
          isVisible: vm.areAmountsVisible,
        ),
      ],
    );
  }

  Widget _buildCardFinancialDetailRow({
    required Currency currency,
    required double budget,
    required double cost,
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
          AnimatedProgressBar(value: cost, total: budget, currency: currency),
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
                'ຈຳນວນ:',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${widget.subItem.quantity ?? "-"} ${widget.subItem.unit ?? ""}',
                style: AppTextStyles.bodyBold,
              ),
            ],
          ),
          if (widget.subItem.selectedDate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat(
                    'dd MMMM yyyy',
                    'lo',
                  ).format(widget.subItem.selectedDate!),
                  style: AppTextStyles.body,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
