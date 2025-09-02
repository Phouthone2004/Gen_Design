import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import '../../data/item_model.dart';
import '../../data/quarterly_budget_model.dart';
import '../../data/sub_item_model.dart';
import '../../logic/home_vm.dart';
import '../../services/db_service.dart';
import '../../services/pdf_exporter.dart';
import '../core/app_styles.dart';
import '../core/app_currencies.dart';
import '../page/detail_page.dart';
import '../page/pdf_preview_page.dart';
import 'add_edit_item_dialog.dart';
import 'settings_dialog.dart';

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final ScrollController _scrollController = ScrollController();
  bool _isAppBarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    final isCollapsed = _scrollController.hasClients &&
        _scrollController.offset > 250.0;
    if (isCollapsed != _isAppBarCollapsed) {
      setState(() {
        _isAppBarCollapsed = isCollapsed;
      });
    }
  }

  /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
  // ฟังก์ชันสำหรับสร้างและแสดง PDF ฉบับรวม
  Future<void> _showCombinedPdfPreview(BuildContext context, HomeViewModel vm) async {
    // แสดง loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. คัดกรองเอาเฉพาะ "โครงการร่วม"
      final itemsToExport = vm.items.where((item) => item.isIncludedInTotals).toList();
      if (itemsToExport.isEmpty) {
        if(mounted) Navigator.of(context, rootNavigator: true).pop(); // ปิด loading
        if(mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ບໍ່ມີ "ໂຄງການຮ່ວມ" ໃຫ້ສົ່ງອອກ')),
          );
        }
        return;
      }
      
      // 2. ดึงข้อมูล sub-items และ quarterly budgets ทั้งหมดจากฐานข้อมูล
      final allSubItems = await DBService.instance.readAllSubItems();
      final allQuarterlyBudgets = await DBService.instance.readAllQuarterlyBudgets();
      
      // 3. เรียกใช้ฟังก์ชันสร้าง PDF โดยส่งข้อมูล 3 ส่วนเข้าไป
      final pdfBytes = await PdfExporter.generateCombinedPdfBytes(
        itemsToExport, 
        allSubItems,
        allQuarterlyBudgets,
      );
      
      final String fileName = 'Combined_Projects_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // ปิด loading

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
      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // ปิด loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດໃນການສ້າງ PDF: $e')),
        );
      }
    }
  }
  /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Consumer<HomeViewModel>(
        builder: (context, vm, child) {
          if (vm.isSettingsLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return Scaffold(
            backgroundColor: Colors.transparent,
            body: CustomScrollView(
              controller: _scrollController,
              slivers: <Widget>[
                SliverAppBar(
                  backgroundColor: AppColors.primaryDark,
                  surfaceTintColor: Colors.transparent,
                  expandedHeight: 480.0,
                  pinned: true,
                  collapsedHeight: 80.0,
                  actions: [
                    IconButton(
                      icon: Icon(
                        vm.areAmountsVisible ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.textOnPrimary,
                      ),
                      onPressed: vm.toggleAmountVisibility,
                    ),
                    /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
                    IconButton(
                      icon: const Icon(Icons.share_outlined, color: AppColors.textOnPrimary),
                      onPressed: () => _showCombinedPdfPreview(context, vm),
                    ),
                    /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: AppColors.textOnPrimary),
                      onPressed: () => showSettingsDialog(context, vm),
                    ),
                  ],
                  title: AnimatedOpacity(
                    opacity: _isAppBarCollapsed ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: _buildCollapsedHeader(vm),
                  ),
                  centerTitle: false,
                  titleSpacing: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: vm.settings.useDefaultBackground
                          ? const BoxDecoration(gradient: headerGradient)
                          : BoxDecoration(
                              image: vm.settings.backgroundImagePath != null && vm.settings.backgroundImagePath!.isNotEmpty
                                  ? DecorationImage(
                                      image: FileImage(File(vm.settings.backgroundImagePath!)),
                                      fit: BoxFit.cover,
                                      colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken),
                                    )
                                  : null,
                              gradient: headerGradient,
                            ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                          child: _buildExpandedHeader(vm),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - 80),
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: vm.isLoading
                        ? const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()))
                        : vm.items.isEmpty
                            ? _buildEmptyState()
                            : _buildItemsList(context, vm),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCollapsedHeader(HomeViewModel vm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (vm.settings.logoImagePath != null && vm.settings.logoImagePath!.isNotEmpty)
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.transparent,
              backgroundImage: FileImage(File(vm.settings.logoImagePath!)),
            ),
          if (vm.settings.logoImagePath != null && vm.settings.logoImagePath!.isNotEmpty)
            const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (vm.settings.isMainTitleVisible)
                  Text(
                    vm.settings.mainTitle,
                    style: AppTextStyles.heading.copyWith(color: Colors.white, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                if (vm.settings.isSubTitleVisible)
                  Text(
                    vm.settings.subTitle,
                    style: AppTextStyles.body.copyWith(color: Colors.white.withOpacity(0.8), fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedHeader(HomeViewModel vm) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildHeaderContent(vm),
        const SizedBox(height: 5,),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 30,
                child: TextField(
                  onChanged: vm.search,
                  style: const TextStyle(color: AppColors.textOnPrimary, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'ຄົ້ນຫາ...',
                    hintStyle: TextStyle(color: AppColors.textOnPrimary.withOpacity(0.5)),
                    prefixIcon: Icon(Icons.search, size: 15, color: AppColors.textOnPrimary.withOpacity(0.7)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.15),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildYearDropdownFilter(vm),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderContent(HomeViewModel vm) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (vm.settings.logoImagePath != null && vm.settings.logoImagePath!.isNotEmpty)
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.transparent,
                backgroundImage: FileImage(File(vm.settings.logoImagePath!)),
              ),
            if (vm.settings.logoImagePath != null && vm.settings.logoImagePath!.isNotEmpty)
              const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (vm.settings.isMainTitleVisible)
                    Text(
                      vm.settings.mainTitle,
                      style: AppTextStyles.heading.copyWith(color: Colors.white, fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (vm.settings.isSubTitleVisible)
                    Text(
                      vm.settings.subTitle,
                      style: AppTextStyles.body.copyWith(color: Colors.white.withOpacity(0.8), fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'ລວມມູນຄ່າທັງໝົດ',
                  style: AppTextStyles.subheading.copyWith(fontSize: 14, color: Colors.white.withOpacity(1)),
                ),
                _buildBudgetRow(Currency.KIP, vm.grandTotalBudget[Currency.KIP.code] ?? 0.0, vm.areAmountsVisible),
                _buildBudgetRow(Currency.THB, vm.grandTotalBudget[Currency.THB.code] ?? 0.0, vm.areAmountsVisible),
                _buildBudgetRow(Currency.USD, vm.grandTotalBudget[Currency.USD.code] ?? 0.0, vm.areAmountsVisible),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ຍອດຄົງເຫຼືອລວມ',
                    style: AppTextStyles.subheading.copyWith(fontSize: 14, color: Colors.white.withOpacity(0.8)),
                  ),
                  _buildFinancialDetailRow(
                    vm: vm,
                    currency: Currency.KIP,
                    budget: vm.grandTotalBudget[Currency.KIP.code] ?? 0.0,
                    cost: vm.grandTotalCost[Currency.KIP.code] ?? 0.0,
                    remaining: vm.grandTotalRemaining[Currency.KIP.code] ?? 0.0,
                  ),
                  _buildFinancialDetailRow(
                    vm: vm,
                    currency: Currency.THB,
                    budget: vm.grandTotalBudget[Currency.THB.code] ?? 0.0,
                    cost: vm.grandTotalCost[Currency.THB.code] ?? 0.0,
                    remaining: vm.grandTotalRemaining[Currency.THB.code] ?? 0.0,
                  ),
                  _buildFinancialDetailRow(
                    vm: vm,
                    currency: Currency.USD,
                    budget: vm.grandTotalBudget[Currency.USD.code] ?? 0.0,
                    cost: vm.grandTotalCost[Currency.USD.code] ?? 0.0,
                    remaining: vm.grandTotalRemaining[Currency.USD.code] ?? 0.0,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildYearDropdownFilter(HomeViewModel vm) {
    final isValueValid = vm.availableYears.contains(vm.selectedYearFilter);
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: isValueValid ? vm.selectedYearFilter : null,
          onChanged: (year) {
            vm.filterByYear(year);
          },
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: AppTextStyles.fontFamily),
          dropdownColor: AppColors.primaryDark,
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('ທັງໝົດ'),
            ),
            ...vm.availableYears.map((year) {
              return DropdownMenuItem<int?>(
                value: year,
                child: Text(year.toString()),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetRow(Currency currency, double amount, bool isVisible) {
    if (amount == 0) return const SizedBox.shrink();
    return Text(
      isVisible
          ? '${NumberFormat("#,##0.##").format(amount)} ${currency.symbol}'
          : '*********** ${currency.symbol}',
      style: AppTextStyles.subheading.copyWith(
        fontSize: 16,
        color: Colors.white.withOpacity(0.8),
      ),
    );
  }

  Widget _buildFinancialDetailRow({
    required HomeViewModel vm,
    required Currency currency,
    required double budget,
    required double cost,
    required double remaining,
  }) {
    if (budget == 0 && cost == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vm.areAmountsVisible
                ? '${NumberFormat("#,##0.##").format(remaining)} ${currency.symbol}'
                : '****** ${currency.symbol}',
            style: AppTextStyles.subheading.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          AnimatedProgressBar(
            value: cost,
            total: budget,
            currency: currency,
            isHeader: true,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text('ບໍ່ພົບລາຍການ', style: AppTextStyles.heading.copyWith(color: AppColors.textSecondary)),
            const Text('ລອງຄົ້ນຫາດ້ວຍຄຳອື່ນ ຫຼື ເພີ່ມລາຍການໃໝ່', style: AppTextStyles.body),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList(BuildContext context, HomeViewModel vm) {
    if (vm.selectedYearFilter == null) {
      final groupedItems = groupBy(vm.items, (ItemModel item) {
        return DateTime.fromMillisecondsSinceEpoch(item.creationTimestamp!).year;
      });
      final sortedYears = groupedItems.keys.toList()..sort((a, b) => b.compareTo(a));

      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 80),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: sortedYears.expand((year) {
          final itemsInYear = groupedItems[year]!;
          return [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
              child: Row(
                children: [
                  const Expanded(child: Divider(thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(year.toString(), style: AppTextStyles.heading),
                  ),
                  const Expanded(child: Divider(thickness: 1)),
                ],
              ),
            ),
            ...itemsInYear.map((item) {
              final projectCosts = vm.subItemsTotalCosts[item.id] ?? {};
              return _buildItemCard(context, vm, item, projectCosts);
            })
          ];
        }).toList(),
      );
    }
    else {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 80),
        itemCount: vm.items.length,
        itemBuilder: (context, index) {
          final item = vm.items[index];
          final projectCosts = vm.subItemsTotalCosts[item.id] ?? {};
          return _buildItemCard(context, vm, item, projectCosts);
        },
      );
    }
  }

  Widget _buildItemCard(BuildContext context, HomeViewModel vm, ItemModel item, Map<String, double> projectCosts) {
    return Card(
      key: ValueKey(item.id),
      elevation: 1.5,
      color: item.isIncludedInTotals ? Colors.white : Colors.grey.shade200,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DetailPage(item: item)),
          );
          Provider.of<HomeViewModel>(context, listen: false).loadItems();
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(item.title, style: AppTextStyles.heading.copyWith(fontSize: 18)),
                  ),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Builder(builder: (buttonContext) {
                      return IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                        onPressed: () => _showContextMenu(buttonContext, item, vm),
                      );
                    }),
                  ),
                ],
              ),
              if (item.selectedDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('dd/MM/yyyy').format(item.selectedDate!),
                        style: AppTextStyles.body.copyWith(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: item.selectedDate != null ? 6 : 10),
              Text(item.description, style: AppTextStyles.body, maxLines: 2, overflow: TextOverflow.ellipsis),
              const Divider(height: 20),
              _buildCardFinancials(item, projectCosts, vm.areAmountsVisible),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardFinancials(ItemModel item, Map<String, double> projectCosts, bool isVisible) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text('ງົບປະມານ:', style: AppTextStyles.body),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildCardAmountRow(Currency.KIP, item.amount, isVisible),
                _buildCardAmountRow(Currency.THB, item.amountThb, isVisible),
                _buildCardAmountRow(Currency.USD, item.amountUsd, isVisible),
              ],
            )
          ],
        ),
        const SizedBox(height: 8),
        _buildCardFinancialDetailRow(
          currency: Currency.KIP,
          budget: item.amount,
          cost: projectCosts[Currency.KIP.code] ?? 0.0,
          isVisible: isVisible,
        ),
        _buildCardFinancialDetailRow(
          currency: Currency.THB,
          budget: item.amountThb,
          cost: projectCosts[Currency.THB.code] ?? 0.0,
          isVisible: isVisible,
        ),
        _buildCardFinancialDetailRow(
          currency: Currency.USD,
          budget: item.amountUsd,
          cost: projectCosts[Currency.USD.code] ?? 0.0,
          isVisible: isVisible,
        ),
      ],
    );
  }

  Widget _buildCardAmountRow(Currency currency, double amount, bool isVisible) {
    if (amount == 0) return const SizedBox.shrink();
    return Text(
      isVisible
          ? '${NumberFormat("#,##0.##").format(amount)} ${currency.symbol}'
          : '*********** ${currency.symbol}',
      style: AppTextStyles.body.copyWith(
          color: AppColors.textSecondary,
          fontSize: 13
      ),
    );
  }

  Widget _buildCardFinancialDetailRow({
    required Currency currency,
    required double budget,
    required double cost,
    required bool isVisible,
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
                : '*********** ${currency.symbol}',
            style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 4),
          AnimatedProgressBar(
            value: cost,
            total: budget,
            currency: currency
          ),
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext buttonContext, ItemModel item, HomeViewModel vm) {
    final RenderBox overlay = Overlay.of(buttonContext).context.findRenderObject() as RenderBox;
    final RenderBox button = buttonContext.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: buttonContext,
      position: position,
      items: [
        const PopupMenuItem<String>(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('ແກ້ໄຂ'))),
        PopupMenuItem<String>(
          value: 'toggle_inclusion',
          child: ListTile(
            leading: Icon(
              item.isIncludedInTotals ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            ),
            title: Text(
              item.isIncludedInTotals ? 'ເຮັດເປັນໂຄງການດ່ຽວ' : 'ເຮັດເປັນໂຄງການຮ່ວມ',
            ),
          ),
        ),
        const PopupMenuItem<String>(value: 'delete', child: ListTile(leading: Icon(Icons.delete), title: Text('ລົບ'))),
      ],
    ).then((value) {
      if (value == 'edit') {
        showAddItemDialog(buttonContext, vm, existingItem: item);
      } else if (value == 'delete') {
        _showDeleteConfirmation(buttonContext, item, vm);
      } else if (value == 'toggle_inclusion') {
        vm.toggleItemInclusion(item.id!);
      }
    });
  }

  void _showDeleteConfirmation(BuildContext context, ItemModel item, HomeViewModel vm) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('ຢືນຢັນການລົບ'),
          content: Text('ທ່ານຕ້ອງການລົບລາຍການ "${item.title}" ແມ່ນບໍ່?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('ຍົກເລີກ')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                vm.deleteItem(item.id!);
                Navigator.of(dialogContext).pop();
              },
              child: const Text('ລົບ'),
            ),
          ],
        );
      },
    );
  }
}

class AnimatedProgressBar extends StatefulWidget {
  final double value;
  final double total;
  final Currency currency;
  final bool isHeader;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    required this.total,
    required this.currency,
    this.isHeader = false,
  });

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.005), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.005, end: -0.005), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -0.005, end: 0.003), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.003, end: -0.003), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -0.003, end: 0.001), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.001, end: 0.0), weight: 10),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _checkAndTriggerAnimation();
  }

  @override
  void didUpdateWidget(covariant AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value || widget.total != oldWidget.total) {
      _checkAndTriggerAnimation();
    }
  }

  void _checkAndTriggerAnimation() {
    final percentage = (widget.total > 0) ? (widget.value / widget.total) : 0.0;
    if (percentage > 1.0) {
      _timer ??= Timer.periodic(const Duration(milliseconds: 1500), (timer) {
        if (mounted) {
          _controller.forward(from: 0.0);
        }
      });
    } else {
      _timer?.cancel();
      _timer = null;
      if (_controller.isAnimating) {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (widget.total > 0) ? (widget.value / widget.total) : (widget.value > 0 ? 1.0 : 0.0);

    Color progressBarColor;
    if (percentage > 1.0) {
      progressBarColor = Colors.red.shade400;
    } else if (percentage >= 0.8) {
      progressBarColor = Colors.yellow.shade700;
    } else {
      progressBarColor = Colors.green.shade400;
    }

    return RotationTransition(
      turns: _animation,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double barWidth = constraints.maxWidth;
          final double visualPercentage = percentage.clamp(0.0, 1.0);
          final double filledWidth = barWidth * visualPercentage;

          return Container(
            height: widget.isHeader ? 24 : 18,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: widget.isHeader ? Colors.white.withOpacity(0.3) : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  width: filledWidth,
                  decoration: BoxDecoration(
                    color: progressBarColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    'ໃຊ້${widget.currency.laoName}ໄປແລ້ວ ${(percentage * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: widget.isHeader ? 12 : 10,
                      fontWeight: FontWeight.bold,
                      shadows: const [
                        Shadow(blurRadius: 1.0, color: Colors.black87, offset: Offset(0.5, 0.5)),
                      ],
                    ),
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
