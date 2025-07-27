import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../data/item_model.dart';
import '../../data/sub_item_model.dart';
import '../../services/db_service.dart';
import '../core/app_styles.dart';
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
  bool _isScrolled = false;
  
  List<SubItemModel> _subItems = [];
  bool _isSubItemsLoading = true;

  List<int> _expandedCardIds = [];
  bool _areAllCardsExpanded = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadAllData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final isScrolled = _scrollController.hasClients && _scrollController.offset > (280 - 70 - kToolbarHeight);
    if (isScrolled != _isScrolled) {
      setState(() {
        _isScrolled = isScrolled;
      });
    }
  }

  Future<void> _loadAllData() async {
    _itemDetailFuture = _loadItemDetails();
    await _loadSubItems();
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
      final subItems = await DBService.instance.readSubItemsForParent(widget.itemId);
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
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
    final double totalSubItemsCost = _subItems.fold(0.0, (sum, e) => sum + (e.laborCost ?? 0) + (e.materialCost ?? 0));
    final double remainingAmount = item.amount - totalSubItemsCost;
    
    return Container(
      decoration: const BoxDecoration(gradient: headerGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final bool? result = await _showAddEditSubItemDialog(context, item.id!);
            if (result == true) {
              await _loadSubItems();
              _scrollToBottom();
            }
          },
          child: Ink(
            decoration: const BoxDecoration(
              gradient: headerGradient,
              borderRadius: BorderRadius.all(Radius.circular(16.0)),
            ),
            child: Container(
              constraints: const BoxConstraints(minWidth: 56.0, minHeight: 56.0),
              alignment: Alignment.center,
              child: const Icon(Icons.add, color: AppColors.textOnPrimary),
            ),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4.0,
        ),
        body: CustomScrollView(
          controller: _scrollController,
          slivers: <Widget>[
            SliverAppBar(
              backgroundColor: _isScrolled ? AppColors.background : Colors.transparent,
              surfaceTintColor: Colors.transparent,
              expandedHeight: 280.0,
              collapsedHeight: 70.0,
              pinned: true,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios, color: _isScrolled ? AppColors.primary : AppColors.textOnPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    _areAllCardsExpanded ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: _isScrolled ? AppColors.primary : AppColors.textOnPrimary,
                  ),
                  onPressed: () {
                    setState(() {
                      _areAllCardsExpanded = !_areAllCardsExpanded;
                      if (_areAllCardsExpanded) {
                        _expandedCardIds = _subItems.map((sub) => sub.id!).toList();
                      } else {
                        _expandedCardIds.clear();
                      }
                    });
                  },
                ),
                /* ------------------ ▼ โค้ดที่ต้องเพิ่ม/แก้ไข ▼ ------------------ */
                // 1. เปลี่ยนไอคอนและเพิ่มการดักจับ Error
                IconButton(
                  icon: Icon(Icons.picture_as_pdf_outlined, color: _isScrolled ? AppColors.primary : AppColors.textOnPrimary),
                  onPressed: () async {
                    try {
                      // แสดง Indicator ขณะกำลังสร้าง PDF
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ກຳລັງສ້າງ PDF...'), duration: Duration(seconds: 2)),
                      );
                      await PdfExporter.generateAndPrintPdf(item, _subItems);
                    } on MissingPluginException {
                      // ดักจับ Error กรณีที่ Plugin ไม่พร้อมใช้งาน
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ບໍ່ສາມາດເປີດຟັງຊັນ PDF ໄດ້. ກະລຸນາລອງປິດເປີດແອັບໃໝ່.'), backgroundColor: Colors.red),
                      );
                    } catch (e) {
                      // ดักจับ Error อื่นๆ ที่อาจเกิดขึ้น
                       ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດ: $e'), backgroundColor: Colors.red),
                      );
                    }
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
                titlePadding: const EdgeInsets.only(bottom: 12, left: 60, right: 60),
                centerTitle: true,
                background: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(item.title, style: AppTextStyles.display.copyWith(fontSize: 32), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.description,
                                style: AppTextStyles.subheading.copyWith(color: Colors.white.withOpacity(0.7), fontSize: 16),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'ງົບ: ${NumberFormat("#,##0").format(item.amount)}',
                              style: AppTextStyles.subheading.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text('ຍອດຄົງເຫຼືອ', style: AppTextStyles.subheading.copyWith(fontSize: 14, color: Colors.white.withOpacity(0.8))),
                        Text(
                          '${NumberFormat("#,##0.##").format(remainingAmount)} ກີບ',
                          style: AppTextStyles.display.copyWith(fontSize: 28),
                        ),
                        const SizedBox(height: 12),
                        _buildProgressBar(totalSubItemsCost, item.amount, isHeader: true),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: _isScrolled ? null : const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
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
                                return _buildSubItemCard(subItem, item.amount);
                              },
                            ),
                ),
              ),
            ),
          ],
        ),
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
          const Text('ກົດປຸ່ມ + ເພື່ອເພິ້ມລາຍການໃໝ່', style: AppTextStyles.body),
        ],
      ),
    );
  }

  Widget _buildSubItemCard(SubItemModel subItem, double mainBudget) {
    final bool isExpanded = _expandedCardIds.contains(subItem.id);
    final double subItemTotal = (subItem.laborCost ?? 0) + (subItem.materialCost ?? 0);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() {
            if (isExpanded) {
              _expandedCardIds.remove(subItem.id);
            } else {
              _expandedCardIds.add(subItem.id!);
            }
            if (_expandedCardIds.length == _subItems.length) {
              _areAllCardsExpanded = true;
            } else {
              _areAllCardsExpanded = false;
            }
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCollapsedCardView(subItem, subItemTotal, mainBudget),
            AnimatedCrossFade(
              firstChild: Container(),
              secondChild: _buildExpandedCardView(subItem),
              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedCardView(SubItemModel subItem, double subItemTotal, double mainBudget) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(subItem.title, style: AppTextStyles.heading)),
              SizedBox(
                width: 24,
                height: 24,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      final bool? result = await _showAddEditSubItemDialog(context, subItem.parentId, existingSubItem: subItem);
                      if (result == true) {
                        _loadSubItems();
                      }
                    } else if (value == 'delete') {
                      _showDeleteSubItemConfirmation(context, subItem);
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(value: 'edit', child: Text('ແກ້ໄຂ')),
                    const PopupMenuItem<String>(value: 'delete', child: Text('ລົບ')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('ລາຄາລວມ: ${NumberFormat("#,##0").format(subItemTotal)} ກີບ', style: AppTextStyles.body),
          const SizedBox(height: 8),
          _buildProgressBar(subItemTotal, mainBudget),
        ],
      ),
    );
  }

  Widget _buildExpandedCardView(SubItemModel subItem) {
    final descriptionWidgets = (subItem.description ?? '')
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 2.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('o ', style: AppTextStyles.body),
                  Expanded(child: Text(line, style: AppTextStyles.body)),
                ],
              ),
            ))
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 24),
          if (descriptionWidgets.isNotEmpty) ...[
            Text('ລາຍລະອຽດ:', style: AppTextStyles.body.copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            ...descriptionWidgets,
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ຈຳນວນ:', style: AppTextStyles.body.copyWith(color: AppColors.textPrimary)),
              Text('${subItem.quantity ?? "-"} ${subItem.unit ?? ""}', style: AppTextStyles.bodyBold),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ຄ່າແຮງ:', style: AppTextStyles.body.copyWith(color: AppColors.textPrimary)),
              Text(subItem.laborCost != null ? '${NumberFormat("#,##0").format(subItem.laborCost)} ກີບ' : '-', style: AppTextStyles.bodyBold),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ຄ່າວັດສະດຸ:', style: AppTextStyles.body.copyWith(color: AppColors.textPrimary)),
              Text(subItem.materialCost != null ? '${NumberFormat("#,##0").format(subItem.materialCost)} ກີບ' : '-', style: AppTextStyles.bodyBold),
            ],
          ),
          if (subItem.selectedDate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(DateFormat('dd MMMM yyyy').format(subItem.selectedDate!), style: AppTextStyles.body),
              ],
            )
          ]
        ],
      ),
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
          height: isHeader ? 24 : 20,
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
                  'ໃຊ້ໄປແລ້ວ ${(clampedPercentage * 100).toStringAsFixed(1)}%', // 2. เปลี่ยนเป็นภาษาลาว
                  /* ------------------ ▲ จบส่วนโค้ดที่เพิ่ม/แก้ไข ▲ ------------------ */
                  style: TextStyle(
                    color: isHeader ? AppColors.primaryDark : Colors.white,
                    fontSize: isHeader ? 12 : 10,
                    fontWeight: FontWeight.bold,
                    shadows: isHeader ? null : [
                      const Shadow(blurRadius: 1.0, color: Colors.black54, offset: Offset(0.5, 0.5)),
                    ]
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

  Future<bool?> _showAddEditSubItemDialog(BuildContext context, int parentId, {SubItemModel? existingSubItem}) {
    final bool isEditing = existingSubItem != null;
    final formKey = GlobalKey<FormState>();
    
    final titleController = TextEditingController(text: existingSubItem?.title);
    final descriptionController = TextEditingController(text: existingSubItem?.description);
    final quantityController = TextEditingController(text: existingSubItem?.quantity?.toString() ?? '');
    final laborCostController = TextEditingController(text: existingSubItem?.laborCost?.toString() ?? '');
    final materialCostController = TextEditingController(text: existingSubItem?.materialCost?.toString() ?? '');

    String? selectedUnit = existingSubItem?.unit;
    DateTime? selectedDate = existingSubItem?.selectedDate;
    bool showCalendar = existingSubItem?.selectedDate != null;

    final List<String> units = ['m', 'm²', 'm³', 'kg', 'unit', 'No Unit', 'ໂຕນ', 'ອັນ', 'ແກັດ', ' '];

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
                        validator: (v) => v!.isEmpty ? 'ກະລຸນາປ້ອນຫົວຂໍ້' : null,
                      ),
                      TextFormField(
                        controller: descriptionController,
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
                              controller: quantityController,
                              decoration: const InputDecoration(labelText: 'ຈຳນວນ'),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              value: selectedUnit,
                              hint: const Text('ໜ່ວຍ'),
                              items: units.map((String unit) {
                                return DropdownMenuItem<String>(value: unit, child: Text(unit));
                              }).toList(),
                              onChanged: (newValue) {
                                setStateDialog(() { selectedUnit = newValue; });
                              },
                            ),
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: laborCostController,
                        decoration: const InputDecoration(labelText: 'ຄ່າແຮງ (ກີບ)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      TextFormField(
                        controller: materialCostController,
                        decoration: const InputDecoration(labelText: 'ຄ່າວັດສະດຸ (ກີບ)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const Divider(height: 24),
                      CheckboxListTile(
                        title: const Text("ສະແດງວັນທີ"),
                        value: showCalendar,
                        onChanged: (bool? value) async {
                          if (value == true) {
                            final DateTime? picked = await showDatePicker(
                              context: context,
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
                            ? Text(DateFormat('dd MMMM yyyy').format(selectedDate!))
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
                      if (isEditing) {
                        final updatedItem = existingSubItem!.copyWith(
                          title: titleController.text,
                          description: descriptionController.text.isNotEmpty ? descriptionController.text : null,
                          quantity: double.tryParse(quantityController.text),
                          unit: selectedUnit,
                          laborCost: double.tryParse(laborCostController.text),
                          materialCost: double.tryParse(materialCostController.text),
                          selectedDate: selectedDate,
                        );
                        await DBService.instance.updateSubItem(updatedItem);
                      } else {
                        final newSubItem = SubItemModel(
                          parentId: parentId,
                          title: titleController.text,
                          description: descriptionController.text.isNotEmpty ? descriptionController.text : null,
                          quantity: double.tryParse(quantityController.text),
                          unit: selectedUnit,
                          laborCost: double.tryParse(laborCostController.text),
                          materialCost: double.tryParse(materialCostController.text),
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

  void _showDeleteSubItemConfirmation(BuildContext context, SubItemModel subItem) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('ຢືນຢັນການລົບ'),
          content: Text('ທ່ານຕ້ອງການລົບລາຍການ "${subItem.title}" ແມ່ນບໍ່?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('ຍົກເລີກ')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () async {
                await DBService.instance.deleteSubItem(subItem.id!);
                Navigator.of(dialogContext).pop();
                _loadSubItems();
              },
              child: const Text('ລົບ'),
            ),
          ],
        );
      },
    );
  }
}
