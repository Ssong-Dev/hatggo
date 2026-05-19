import 'checklist_item.dart';

class ChecklistGroup {
  final String id;
  final String title;
  final List<ChecklistItem> items;

  ChecklistGroup({
    required this.id,
    required this.title,
    this.items = const [],
  });

  factory ChecklistGroup.fromJson(Map<String, dynamic> json) {
    return ChecklistGroup(
      id: json['id'] as String,
      title: json['title'] as String,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }

  ChecklistGroup copyWith({
    String? id,
    String? title,
    List<ChecklistItem>? items,
  }) {
    return ChecklistGroup(
      id: id ?? this.id,
      title: title ?? this.title,
      items: items ?? this.items,
    );
  }
}
