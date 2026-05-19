import 'checklist_item.dart';

class HistoryLog {
  final String id;
  final String groupId;
  final String groupTitle;
  final DateTime completedAt;
  final List<ChecklistItem> items;

  HistoryLog({
    required this.id,
    required this.groupId,
    required this.groupTitle,
    required this.completedAt,
    this.items = const [],
  });

  factory HistoryLog.fromJson(Map<String, dynamic> json) {
    return HistoryLog(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      groupTitle: json['groupTitle'] as String,
      completedAt: DateTime.parse(json['completedAt'] as String),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'groupTitle': groupTitle,
      'completedAt': completedAt.toIso8601String(),
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}
