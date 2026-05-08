import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import '../models/checklist_item.dart';

const String _iOSWidgetName = 'HatggoWidget';
const String _androidWidgetName = 'WidgetActionReceiver'; 
const String _prefKey = 'checklist_data';

class ChecklistNotifier extends Notifier<List<ChecklistItem>> {
  @override
  List<ChecklistItem> build() {
    _loadFromPrefs();
    return [];
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_prefKey);
    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        state = jsonList.map((e) => ChecklistItem.fromJson(e)).toList();
      } catch (e) {
        state = [];
      }
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(state.map((e) => e.toJson()).toList());
    
    await prefs.setString(_prefKey, jsonString);
    
    await HomeWidget.saveWidgetData<String>(_prefKey, jsonString);
    await HomeWidget.updateWidget(
      iOSName: _iOSWidgetName,
      androidName: _androidWidgetName,
    );
  }

  void addItem(String title) {
    if (title.trim().isEmpty) return;
    
    final newItem = ChecklistItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
    );
    state = [...state, newItem];
    _saveToPrefs();
  }

  void toggleItem(String id) {
    state = state.map((item) {
      if (item.id == id) {
        return item.copyWith(isChecked: !item.isChecked);
      }
      return item;
    }).toList();
    _saveToPrefs();
  }

  void removeItem(String id) {
    state = state.where((item) => item.id != id).toList();
    _saveToPrefs();
  }

  void updateItem(String id, String newTitle) {
    if (newTitle.trim().isEmpty) return;

    state = state.map((item) {
      if (item.id == id) {
        return item.copyWith(title: newTitle.trim());
      }
      return item;
    }).toList();
    _saveToPrefs();
  }
  
  Future<void> reload() async {
    await _loadFromPrefs();
  }
}

final checklistProvider = NotifierProvider<ChecklistNotifier, List<ChecklistItem>>(() {
  return ChecklistNotifier();
});
