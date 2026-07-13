class ChecklistItem {
  final String id;
  final String title;
  final bool isChecked;
  final String? completedBy;
  final DateTime? completedAt;

  ChecklistItem({
    required this.id,
    required this.title,
    this.isChecked = false,
    this.completedBy,
    this.completedAt,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] as String,
      title: json['title'] as String,
      isChecked: json['isChecked'] as bool? ?? false,
      completedBy: json['completedBy'] as String?,
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isChecked': isChecked,
      'completedBy': completedBy,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  ChecklistItem copyWith({
    String? id,
    String? title,
    bool? isChecked,
    String? completedBy,
    DateTime? completedAt,
  }) {
    return ChecklistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      isChecked: isChecked ?? this.isChecked,
      completedBy: completedBy ?? this.completedBy,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
