import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import '../../data/item_model.dart';
import '../../logic/home_vm.dart';
import '../core/app_styles.dart';
import '../core/app_currencies.dart';
import '../page/detail_page.dart';
import 'add_edit_item_dialog.dart';

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: headerGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Consumer<HomeViewModel>(
          builder: (context, vm, child) {
            if (vm.isLoading) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            return CustomScrollView(
              slivers: <Widget>[
                SliverAppBar(
                  backgroundColor: AppColors.primaryDark,
                  surfaceTintColor: Colors.transparent,
                  expandedHeight: 420.0,
                  pinned: true,
                  collapsedHeight: 70.0,
                  actions: [
                    IconButton(
                      icon: Icon(
                        vm.areAmountsVisible ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.textOnPrimary,
                      ),
                      onPressed: () {
                        vm.toggleAmountVisibility();
                      },
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
                    title: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 30,
                            child: TextField(
                              onChanged: (value) => vm.search(value),
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
                    background: Container(
                      decoration: const BoxDecoration(gradient: headerGradient),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 60),
                          child: _buildGrandTotalDisplay(vm),
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
                    child: vm.items.isEmpty
                        ? _buildEmptyState()
                        : _buildItemsList(context, vm),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGrandTotalDisplay(HomeViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'ງົບປະມານທັງໝົດ',
          style: AppTextStyles.subheading.copyWith(fontSize: 14, color: Colors.white.withOpacity(0.8))
        ),
        _buildBudgetRow(Currency.KIP, vm.grandTotalBudget[Currency.KIP.code] ?? 0.0, vm.areAmountsVisible),
        _buildBudgetRow(Currency.THB, vm.grandTotalBudget[Currency.THB.code] ?? 0.0, vm.areAmountsVisible),
        _buildBudgetRow(Currency.USD, vm.grandTotalBudget[Currency.USD.code] ?? 0.0, vm.areAmountsVisible),
        const SizedBox(height: 12),
        Text(
          'ຍອດຄົງເຫຼືອລວມ',
          style: AppTextStyles.subheading.copyWith(fontSize: 14, color: Colors.white.withOpacity(0.8))
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
    );
  }

  Widget _buildYearDropdownFilter(HomeViewModel vm) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: vm.selectedYearFilter,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          isVisible
              ? '${NumberFormat("#,##0.##").format(amount)} ${currency.symbol}'
              : '*********** ${currency.symbol}',
          style: AppTextStyles.subheading.copyWith(
            fontSize: 16,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
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
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DetailPage(itemId: item.id!)),
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
              /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
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
              /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
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
        const PopupMenuItem<String>(value: 'delete', child: ListTile(leading: Icon(Icons.delete), title: Text('ລົບ'))),
      ],
    ).then((value) {
      if (value == 'edit') {
        showAddItemDialog(buttonContext, vm, existingItem: item);
      } else if (value == 'delete') {
        _showDeleteConfirmation(buttonContext, item, vm);
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
                    color: Colors.red.shade400,
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
