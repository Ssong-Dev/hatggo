class ChecklistItem {
  final String id;
  final String title;
  final bool isChecked;

  ChecklistItem({
    required this.id,
    required this.title,
    this.isChecked = false,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] as String,
      title: json['title'] as String,
      isChecked: json['isChecked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isChecked': isChecked,
    };
  }

  ChecklistItem copyWith({
    String? id,
    String? title,
    bool? isChecked,
  }) {
    return ChecklistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      isChecked: isChecked ?? this.isChecked,
    );
  }
}
