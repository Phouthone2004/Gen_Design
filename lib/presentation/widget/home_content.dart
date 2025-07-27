import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/item_model.dart';
import '../../logic/home_vm.dart';
import '../core/app_styles.dart';
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

            final grandTotalBudget = vm.grandTotalBudget;
            final grandTotalCost = vm.grandTotalCost;
            final grandTotalRemaining = vm.grandTotalRemaining;

            return CustomScrollView(
              slivers: <Widget>[
                SliverAppBar(
                  backgroundColor: AppColors.primaryDark,
                  surfaceTintColor: Colors.transparent,
                  expandedHeight: 250.0,
                  pinned: true,
                  collapsedHeight: 70.0,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
                    title: SizedBox(
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
                    background: Container(
                      decoration: const BoxDecoration(gradient: headerGradient),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 60, 24, 60),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('ຈຳນວນເງິນທັງໝົດ', style: AppTextStyles.subheading),
                                  Text(
                                    '${NumberFormat("#,##0").format(grandTotalBudget)} ກີບ',
                                    style: AppTextStyles.subheading.copyWith(
                                      color: AppColors.textOnPrimary.withOpacity(0.8),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Text('ຍອດຄົງເຫຼືອ', style: AppTextStyles.subheading.copyWith(fontSize: 14, color: Colors.white.withOpacity(0.8))),
                              Text(
                                '${NumberFormat("#,##0.##").format(grandTotalRemaining)} ກີບ',
                                style: AppTextStyles.display.copyWith(fontSize: 28),
                              ),
                              const SizedBox(height: 12),
                              _buildProgressBar(grandTotalCost, grandTotalBudget, isHeader: true),
                            ],
                          ),
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
                        : _buildReorderableList(vm),
                  ),
                ),
              ],
            );
          },
        ),
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

  Widget _buildReorderableList(HomeViewModel vm) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 80),
      itemCount: vm.items.length,
      onReorder: (oldIndex, newIndex) {
        vm.reorderItems(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final item = vm.items[index];
        final double totalCost = vm.subItemsTotalCosts[item.id] ?? 0.0;
        final double remainingAmount = item.amount - totalCost;

        return ReorderableDragStartListener(
          key: ValueKey(item.id),
          index: index,
          enabled: item.isPinned == 0,
          child: Card(
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
                        if (item.isPinned == 1)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0, right: 4.0),
                            child: Icon(Icons.push_pin, size: 18, color: AppColors.accent),
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
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(item.description, style: AppTextStyles.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'งบ: ${NumberFormat("#,##0").format(item.amount)}',
                          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ຄົງເຫຼືອ: ${NumberFormat("#,##0").format(remainingAmount)} ກີບ',
                      style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    _buildProgressBar(totalCost, item.amount),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
        PopupMenuItem<String>(value: 'edit', child: const ListTile(leading: Icon(Icons.edit), title: Text('ແກ້ໄຂ'))),
        PopupMenuItem<String>(value: 'pin', child: ListTile(leading: Icon(item.isPinned == 1 ? Icons.push_pin_outlined : Icons.push_pin, color: AppColors.accent), title: Text(item.isPinned == 1 ? 'ເອົາໝຸດອອກ' : 'ປັກໝຸດ'))),
        const PopupMenuDivider(),
        PopupMenuItem<String>(value: 'delete', child: const ListTile(leading: Icon(Icons.delete, color: AppColors.danger), title: Text('ລົບ', style: TextStyle(color: AppColors.danger)))),
      ],
    ).then((value) {
      if (value == 'edit') {
        showAddItemDialog(buttonContext, vm, existingItem: item);
      } else if (value == 'pin') {
        vm.togglePinStatus(item);
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

  Widget _buildProgressBar(double value, double total, {bool isHeader = false}) {
    if (total <= 0) return const SizedBox.shrink();

    final double percentage = (value / total);
    final double clampedPercentage = percentage.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double barWidth = constraints.maxWidth;
        final double redWidth = barWidth * clampedPercentage;

        return Container(
          height: isHeader ? 24 : 18,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: isHeader ? Colors.white.withOpacity(0.3) : Colors.green.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                width: redWidth,
                decoration: BoxDecoration(
                  color: isHeader ? Colors.white : Colors.red.shade400,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
                  'ໃຊ້ໄປແລ້ວ ${(clampedPercentage * 100).toStringAsFixed(1)}%', // 1. เปลี่ยนเป็นภาษาลาว
                  /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
                  style: TextStyle(
                    color: isHeader ? AppColors.primaryDark : Colors.white,
                    fontSize: isHeader ? 12 : 10,
                    fontWeight: FontWeight.bold,
                    shadows: isHeader ? null : [
                      const Shadow(blurRadius: 1.0, color: Colors.black54, offset: Offset(0.5, 0.5)),
                    ],
                  ),
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
