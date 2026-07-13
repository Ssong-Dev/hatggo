import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:home_widget/home_widget.dart';
import 'package:confetti/confetti.dart';

import '../providers/group_provider.dart';
import '../providers/history_provider.dart';
import '../providers/nickname_provider.dart';
import '../models/history_log.dart';
import '../models/checklist_group.dart';

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
    final nickname = ref.watch(nicknameProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('체크리스트 그룹'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.account_circle_outlined, size: 22),
            label: Text(
              nickname,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () => _showNicknameDialog(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
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
                                Row(
                                  children: [
                                    Text(
                                      '${group.items.length}개 항목',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                    if (group.inviteCode != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade300),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: group.inviteCode!));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('초대코드 [${group.inviteCode}]가 복사되었습니다. 📋'),
                                              duration: const Duration(seconds: 1),
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '초대코드: ${group.inviteCode}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context).colorScheme.primary,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.copy,
                                                size: 10,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
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

  void _showNicknameDialog(BuildContext context, WidgetRef ref) {
    final currentNickname = ref.read(nicknameProvider);
    final controller = TextEditingController(text: currentNickname);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('닉네임 설정', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '활동할 닉네임을 입력하세요',
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
              if (controller.text.trim().isNotEmpty) {
                ref.read(nicknameProvider.notifier).updateNickname(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('저장', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, String groupId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('그룹 삭제'),
        content: const Text('정말로 이 그룹을 삭제하시겠습니까?\n공유 그룹일 경우 다른 사람들에게도 보이지 않게 됩니다.'),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('그룹 추가', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogOption(
              context,
              icon: Icons.add_circle_outline,
              title: '새 공유 그룹 만들기',
              subtitle: '새로운 체크리스트 그룹을 생성하고 초대코드를 발급받습니다.',
              onTap: () {
                Navigator.pop(context);
                _showCreateGroupDialog(context, ref);
              },
            ),
            const SizedBox(height: 12),
            _buildDialogOption(
              context,
              icon: Icons.group_add_outlined,
              title: '초대코드로 참여하기',
              subtitle: '공유받은 초대코드를 입력하여 다른 사람의 체크리스트에 참여합니다.',
              onTap: () {
                Navigator.pop(context);
                _showJoinGroupDialog(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('새 공유 그룹 만들기', style: TextStyle(fontWeight: FontWeight.bold)),
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
            onPressed: () async {
              final title = controller.text.trim();
              if (title.isNotEmpty) {
                Navigator.pop(context);
                await ref.read(groupProvider.notifier).addServerGroup(title);
              }
            },
            child: const Text('만들기', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showJoinGroupDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('초대코드로 참여하기', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: '6자리 초대코드 입력 (예: A7B8C9)',
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
            onPressed: () async {
              final code = controller.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(context);
                try {
                  await ref.read(groupProvider.notifier).joinGroupWithCode(code);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('성공적으로 공유 그룹에 가입했습니다! 👥'),
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                } catch (e) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('가입 실패'),
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('확인'),
                        )
                      ],
                    ),
                  );
                }
              }
            },
            child: const Text('참여하기', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _ActiveTab extends ConsumerStatefulWidget {
  const _ActiveTab();

  @override
  ConsumerState<_ActiveTab> createState() => _ActiveTabState();
}

class _ActiveTabState extends ConsumerState<_ActiveTab> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    final memberId = ref.read(groupProvider.notifier).memberId;
    final ownerToken = ref.read(groupProvider.notifier).getOwnerToken(group.id);
    final isOwner = group.inviteCode != null && ownerToken != null;
    final myPermission = group.memberPermissions[memberId] ?? 'READ_WRITE';
    final isReadOnly = group.inviteCode != null && myPermission == 'READ_ONLY';

    return Scaffold(
      appBar: AppBar(
        title: Text(group.title),
        actions: [
          if (group.inviteCode != null) ...[
            if (isOwner) ...[
              IconButton(
                icon: Icon(Icons.admin_panel_settings, color: Theme.of(context).colorScheme.primary),
                tooltip: '참여자 권한 관리',
                onPressed: () => _showManageMembersDialog(context, ref, group),
              ),
            ],
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: group.inviteCode!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('초대코드 [${group.inviteCode}]가 복사되었습니다. 📋'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_alt_outlined,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '초대코드: ${group.inviteCode}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.copy,
                      size: 10,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: group.items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_task, size: 80, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(isReadOnly ? '항목이 없습니다.' : '항목이 없습니다.\n하단의 + 버튼을 눌러 추가하세요.',
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
                              onTap: isReadOnly
                                  ? () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('읽기 전용 권한 상태입니다. 🔒'),
                                          duration: Duration(seconds: 1),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  : () {
                                      HapticFeedback.lightImpact();
                                      ref.read(groupProvider.notifier).toggleItemInGroup(group.id, item.id);
                                    },
                              leading: AnimatedContainer(
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
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 200),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontFamily: 'Hansol',
                                      color: item.isChecked ? Colors.grey.shade400 : Colors.black87,
                                      decoration: item.isChecked ? TextDecoration.lineThrough : TextDecoration.none,
                                    ),
                                    child: Text(item.title),
                                  ),
                                  if (item.isChecked && item.completedBy != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '완료: ${item.completedBy!}${item.completedAt != null ? " (${DateFormat('HH:mm').format(item.completedAt!.toLocal())})" : ""}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: isReadOnly
                                  ? null
                                  : IconButton(
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
                              isReadOnly
                                  ? Colors.grey.shade400
                                  : Theme.of(context).colorScheme.primary,
                              isReadOnly
                                  ? Colors.grey.shade400.withOpacity(0.8)
                                  : Theme.of(context).colorScheme.primary.withOpacity(0.8),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isReadOnly
                                  ? Colors.grey.withOpacity(0.3)
                                  : Theme.of(context).colorScheme.primary.withOpacity(0.4),
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
                          onPressed: isReadOnly
                              ? () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('읽기 전용 권한 상태입니다. 🔒'),
                                      duration: Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              : () {
                                  _confettiController.play();
                                  HapticFeedback.mediumImpact();
                                  
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
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
                Colors.yellow,
                Colors.red,
              ],
              numberOfParticles: 25,
              gravity: 0.15,
            ),
          ),
        ],
      ),
      floatingActionButton: isReadOnly
          ? null
          : (group.items.isNotEmpty 
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
                )),
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

  void _showManageMembersDialog(BuildContext context, WidgetRef ref, ChecklistGroup group) {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            // 실시간 그룹 정보 가져오기
            final currentGroup = ref.watch(groupProvider).firstWhere((g) => g.id == group.id, orElse: () => group);
            final myMemberId = ref.read(groupProvider.notifier).memberId;
            final members = currentGroup.memberNicknames.keys.where((id) => id != myMemberId).toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Icon(Icons.manage_accounts, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('참여자 권한 관리', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: members.isEmpty
                  ? const SizedBox(
                      height: 100,
                      child: Center(
                        child: Text(
                          '현재 참여 중인 다른 멤버가 없습니다.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    )
                  : SizedBox(
                      width: double.maxFinite,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: members.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final mId = members[index];
                          final name = currentGroup.memberNicknames[mId] ?? '익명';
                          final permission = currentGroup.memberPermissions[mId] ?? 'READ_WRITE';
                          final isReadOnly = permission == 'READ_ONLY';

                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              Row(
                                children: [
                                  ChoiceChip(
                                    label: const Text('읽기/쓰기', style: TextStyle(fontSize: 12)),
                                    selected: !isReadOnly,
                                    selectedColor: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                                    onSelected: (selected) {
                                      if (selected) {
                                        ref.read(groupProvider.notifier).updateMemberPermission(
                                          currentGroup.id,
                                          mId,
                                          'READ_WRITE',
                                        );
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  ChoiceChip(
                                    label: const Text('읽기전용', style: TextStyle(fontSize: 12)),
                                    selected: isReadOnly,
                                    selectedColor: Colors.amber.shade100,
                                    onSelected: (selected) {
                                      if (selected) {
                                        ref.read(groupProvider.notifier).updateMemberPermission(
                                          currentGroup.id,
                                          mId,
                                          'READ_ONLY',
                                        );
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                                    tooltip: '강제퇴장',
                                    onPressed: () {
                                      ref.read(groupProvider.notifier).kickMember(currentGroup.id, mId);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
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
