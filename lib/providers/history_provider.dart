import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_log.dart';
import '../models/checklist_group.dart';

const String _historyPrefKey = 'history_logs';

class HistoryNotifier extends Notifier<List<HistoryLog>> {
  @override
  List<HistoryLog> build() {
    _loadFromPrefs();
    return [];
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_historyPrefKey);
    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        state = jsonList.map((e) => HistoryLog.fromJson(e)).toList();
      } catch (e) {
        state = [];
      }
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_historyPrefKey, jsonString);
  }

  void addLog(ChecklistGroup group) {
    // Only log items that were actually checked
    final checkedItems = group.items.where((i) => i.isChecked).toList();
    if (checkedItems.isEmpty) return;

    final newLog = HistoryLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      groupId: group.id,
      groupTitle: group.title,
      completedAt: DateTime.now(),
      items: checkedItems,
    );
    
    // Add to top of list (newest first)
    state = [newLog, ...state];
    _saveToPrefs();
  }

  void addRawLog(HistoryLog log) {
    state = [log, ...state];
    _saveToPrefs();
  }

  void clearHistory() {
    state = [];
    _saveToPrefs();
  }
}

final historyProvider = NotifierProvider<HistoryNotifier, List<HistoryLog>>(() {
  return HistoryNotifier();
});
