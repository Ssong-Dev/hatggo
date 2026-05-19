import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:home_widget/home_widget.dart';

import '../providers/group_provider.dart';
import '../providers/history_provider.dart';
import '../models/history_log.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 1; // Default to Active Tab

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final activeId = ref.read(activeGroupIdProvider);
      ref.read(groupProvider.notifier).syncFromWidget(activeId);
      _syncPendingHistoryLogs();
    }
  }

  Future<void> _syncPendingHistoryLogs() async {
    final pendingJson = await HomeWidget.getWidgetData<String>('pending_history_logs');
    if (pendingJson != null && pendingJson.isNotEmpty) {
      try {
        final List<dynamic> jsonList = jsonDecode(pendingJson);
        for (var item in jsonList) {
          final log = HistoryLog.fromJson(item as Map<String, dynamic>);
          ref.read(historyProvider.notifier).addRawLog(log);
        }
        // 처리 완료 후 임시 보관함 비우기
        await HomeWidget.saveWidgetData<String>('pending_history_logs', '[]');
      } catch (e) {
        // ignore
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the active group to auto-sync to the widget whenever it changes
    ref.listen(activeGroupProvider, (previous, next) {
      WidgetSyncService.syncActiveGroupToWidget(next);
    });

    final List<Widget> screens = [
      const _GroupsTab(),
      const _ActiveTab(),
      const _HistoryTab(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            iconSize: 26,
            selectedFontSize: 14,
            unselectedFontSize: 12,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.folder_outlined)),
                activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.folder)),
                label: '그룹 관리',
              ),
              BottomNavigationBarItem(
                icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.check_box_outlined)),
                activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.check_box)),
                label: '진행 중',
              ),
              BottomNavigationBarItem(
                icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.history_outlined)),
                activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.history)),
                label: '히스토리',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupsTab extends ConsumerWidget {
  const _GroupsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupProvider);
    final activeId = ref.watch(activeGroupIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('체크리스트 그룹')),
      body: groups.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('그룹이 없습니다.\n우측 하단 버튼으로 그룹을 만들어보세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16, height: 1.5)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: groups.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final group = groups[index];
                final isActive = (activeId == null && index == 0) || group.id == activeId;
                
                return GestureDetector(
                  onTap: () {
                    ref.read(activeGroupIdProvider.notifier).setActiveGroup(group.id);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive ? Theme.of(context).colorScheme.primary : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isActive 
                              ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                              : Colors.black.withOpacity(0.04),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isActive ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isActive ? Icons.check_circle : Icons.list_alt,
                              color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${group.items.length}개 항목',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => _showDeleteConfirm(context, ref, group.id),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        onPressed: () => _showAddGroupDialog(context, ref),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, String groupId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('그룹 삭제'),
        content: const Text('정말로 이 그룹을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              ref.read(groupProvider.notifier).removeGroup(groupId);
              Navigator.pop(context);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddGroupDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('새 그룹 추가', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '예: 외출 전 필수 확인',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              ref.read(groupProvider.notifier).addGroup(controller.text);
              Navigator.pop(context);
            },
            child: const Text('추가', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _ActiveTab extends ConsumerWidget {
  const _ActiveTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(activeGroupProvider);

    if (group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('햇꼬 체크리스트')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.checklist_rtl, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('선택된 그룹이 없습니다.\n[그룹 관리] 탭에서 그룹을 선택하세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16, height: 1.5)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(group.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: group.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_task, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('항목이 없습니다.\n하단의 + 버튼을 눌러 추가하세요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 16, height: 1.5)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: group.items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = group.items[index];
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          color: item.isChecked ? Colors.grey.shade50 : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: item.isChecked ? Colors.transparent : Colors.grey.shade200),
                          boxShadow: item.isChecked
                              ? []
                              : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: GestureDetector(
                            onTap: () => ref.read(groupProvider.notifier).toggleItemInGroup(group.id, item.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: item.isChecked ? Theme.of(context).colorScheme.secondary : Colors.transparent,
                                border: Border.all(
                                  color: item.isChecked ? Theme.of(context).colorScheme.secondary : Colors.grey.shade400,
                                  width: 2,
                                ),
                              ),
                              child: item.isChecked
                                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                                  : null,
                            ),
                          ),
                          title: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: 18,
                              fontFamily: 'Hansol',
                              color: item.isChecked ? Colors.grey.shade400 : Colors.black87,
                              decoration: item.isChecked ? TextDecoration.lineThrough : TextDecoration.none,
                            ),
                            child: Text(item.title),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, color: Colors.black26),
                            onPressed: () {
                              ref.read(groupProvider.notifier).removeItemFromGroup(group.id, item.id);
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Complete Button Area
          if (group.items.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: const Color(0xFFFDFCF8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFDFCF8).withOpacity(0.9),
                    blurRadius: 20,
                    spreadRadius: 20,
                    offset: const Offset(0, -10),
                  )
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primary.withOpacity(0.8),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: () {
                        ref.read(historyProvider.notifier).addLog(group);
                        ref.read(groupProvider.notifier).uncheckAllItems(group.id);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('완료 처리되어 히스토리에 저장되었습니다 🎉', style: TextStyle(fontFamily: 'Hansol', fontSize: 16)),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                          ),
                        );
                      },
                      child: const Text('완료 처리', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: group.items.isNotEmpty 
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80.0),
              child: FloatingActionButton(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                backgroundColor: Theme.of(context).colorScheme.secondary,
                onPressed: () => _showAddItemDialog(context, ref, group.id),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            )
          : FloatingActionButton(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              onPressed: () => _showAddItemDialog(context, ref, group.id),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
    );
  }

  void _showAddItemDialog(BuildContext context, WidgetRef ref, String groupId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('체크리스트 항목 추가', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '예: 보일러 전원 끄기',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (value) {
            ref.read(groupProvider.notifier).addItemToGroup(groupId, value);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              ref.read(groupProvider.notifier).addItemToGroup(groupId, controller.text);
              Navigator.pop(context);
            },
            child: const Text('추가', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('히스토리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.black54),
            onPressed: () {
              if (history.isNotEmpty) {
                _showClearHistoryConfirm(context, ref);
              }
            },
          )
        ],
      ),
      body: history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('완료된 기록이 없습니다.\n체크리스트를 완료해보세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16, height: 1.5)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final log = history[index];
                final formattedDate = DateFormat('yyyy. MM. dd  HH:mm').format(log.completedAt.toLocal());
                
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      iconColor: Theme.of(context).colorScheme.primary,
                      collapsedIconColor: Colors.grey.shade400,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      title: Text(log.groupTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(formattedDate, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14)),
                      ),
                      children: log.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, size: 16, color: Theme.of(context).colorScheme.secondary),
                              const SizedBox(width: 12),
                              Expanded(child: Text(item.title, style: TextStyle(fontSize: 16, color: Colors.grey.shade700))),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showClearHistoryConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('히스토리 삭제'),
        content: const Text('모든 히스토리 기록을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              ref.read(historyProvider.notifier).clearHistory();
              Navigator.pop(context);
            },
            child: const Text('전체 삭제', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
