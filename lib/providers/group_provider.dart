import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import '../models/checklist_group.dart';
import '../models/checklist_item.dart';

const String _groupPrefKey = 'checklist_groups';
const String _activeGroupPrefKey = 'active_group_id';
const String _iOSWidgetName = 'HatggoWidget';
const String _androidWidgetName = 'WidgetActionReceiver';
const String _widgetDataKey = 'checklist_data';

class GroupNotifier extends Notifier<List<ChecklistGroup>> {
  @override
  List<ChecklistGroup> build() {
    _loadFromPrefs();
    return [];
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_groupPrefKey);
    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        state = jsonList.map((e) => ChecklistGroup.fromJson(e)).toList();
      } catch (e) {
        state = [];
      }
    } else {
      // Default initial state
      state = [
        ChecklistGroup(id: 'default', title: '기본 체크리스트', items: [])
      ];
      _saveToPrefs();
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_groupPrefKey, jsonString);
  }

  void addGroup(String title) {
    if (title.trim().isEmpty) return;
    final newGroup = ChecklistGroup(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
    );
    state = [...state, newGroup];
    _saveToPrefs();
  }

  void removeGroup(String id) {
    state = state.where((g) => g.id != id).toList();
    _saveToPrefs();
  }

  void updateGroupTitle(String id, String newTitle) {
    if (newTitle.trim().isEmpty) return;
    state = state.map((g) {
      if (g.id == id) return g.copyWith(title: newTitle.trim());
      return g;
    }).toList();
    _saveToPrefs();
  }

  void addItemToGroup(String groupId, String title) {
    if (title.trim().isEmpty) return;
    state = state.map((g) {
      if (g.id == groupId) {
        final newItem = ChecklistItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title.trim(),
        );
        return g.copyWith(items: [...g.items, newItem]);
      }
      return g;
    }).toList();
    _saveToPrefs();
  }

  void toggleItemInGroup(String groupId, String itemId) {
    state = state.map((g) {
      if (g.id == groupId) {
        final newItems = g.items.map((i) {
          if (i.id == itemId) return i.copyWith(isChecked: !i.isChecked);
          return i;
        }).toList();
        return g.copyWith(items: newItems);
      }
      return g;
    }).toList();
    _saveToPrefs();
  }

  void removeItemFromGroup(String groupId, String itemId) {
    state = state.map((g) {
      if (g.id == groupId) {
        final newItems = g.items.where((i) => i.id != itemId).toList();
        return g.copyWith(items: newItems);
      }
      return g;
    }).toList();
    _saveToPrefs();
  }

  void uncheckAllItems(String groupId) {
    state = state.map((g) {
      if (g.id == groupId) {
        final newItems = g.items.map((i) => i.copyWith(isChecked: false)).toList();
        return g.copyWith(items: newItems);
      }
      return g;
    }).toList();
    _saveToPrefs();
  }
  
  Future<void> syncFromWidget(String? activeGroupId) async {
    if (activeGroupId == null) return;
    // SharedPreferences가 아닌 위젯 앱 그룹(HomeWidget)에서 직접 데이터를 읽어와야 합니다.
    final widgetJson = await HomeWidget.getWidgetData<String>(_widgetDataKey);
    
    if (widgetJson != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(widgetJson);
        final widgetItems = jsonList.map((e) => ChecklistItem.fromJson(e)).toList();
        
        state = state.map((g) {
          if (g.id == activeGroupId) {
            return g.copyWith(items: widgetItems);
          }
          return g;
        }).toList();
        await _saveToPrefs();
      } catch (e) {
        // ignore
      }
    }
  }

  Future<void> reload() async {
    await _loadFromPrefs();
  }
}

final groupProvider = NotifierProvider<GroupNotifier, List<ChecklistGroup>>(() {
  return GroupNotifier();
});

class ActiveGroupIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    _loadFromPrefs();
    return null;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_activeGroupPrefKey);
  }

  Future<void> setActiveGroup(String id) async {
    state = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeGroupPrefKey, id);
  }
}

final activeGroupIdProvider = NotifierProvider<ActiveGroupIdNotifier, String?>(() {
  return ActiveGroupIdNotifier();
});

// A derived provider that gives the actual active group
final activeGroupProvider = Provider<ChecklistGroup?>((ref) {
  final groups = ref.watch(groupProvider);
  final activeId = ref.watch(activeGroupIdProvider);
  
  if (activeId == null) {
    return groups.isNotEmpty ? groups.first : null;
  }
  
  try {
    return groups.firstWhere((g) => g.id == activeId);
  } catch (e) {
    return groups.isNotEmpty ? groups.first : null;
  }
});

// Service to handle syncing with the iOS widget
class WidgetSyncService {
  static Future<void> syncActiveGroupToWidget(ChecklistGroup? group) async {
    // If no group, send empty items to widget
    final items = group?.items ?? [];
    final jsonString = jsonEncode(items.map((e) => e.toJson()).toList());
    
    // Using the same key 'checklist_data' so Swift code doesn't need to change
    await HomeWidget.saveWidgetData<String>(_widgetDataKey, jsonString);
    
    // 네이티브에서 히스토리를 만들 때 필요한 메타데이터 전송
    await HomeWidget.saveWidgetData<String>('active_group_id', group?.id ?? '');
    await HomeWidget.saveWidgetData<String>('active_group_title', group?.title ?? '');
    
    await HomeWidget.updateWidget(
      iOSName: _iOSWidgetName,
      androidName: _androidWidgetName,
    );
  }
}
