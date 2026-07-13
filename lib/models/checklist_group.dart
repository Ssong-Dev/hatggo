import 'checklist_item.dart';

class ChecklistGroup {
  final String id;
  final String title;
  final List<ChecklistItem> items;
  final String? inviteCode;
  final String? ownerToken;
  final Map<String, String> memberPermissions; // memberId -> "READ_WRITE" or "READ_ONLY"
  final Map<String, String> memberNicknames; // memberId -> nickname
  final List<String> kickedMembers;

  ChecklistGroup({
    required this.id,
    required this.title,
    this.items = const [],
    this.inviteCode,
    this.ownerToken,
    this.memberPermissions = const {},
    this.memberNicknames = const {},
    this.kickedMembers = const [],
  });

  factory ChecklistGroup.fromJson(Map<String, dynamic> json) {
    return ChecklistGroup(
      id: json['id'] as String,
      title: json['title'] as String,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      inviteCode: json['inviteCode'] as String?,
      ownerToken: json['ownerToken'] as String?,
      memberPermissions: Map<String, String>.from(json['memberPermissions'] ?? {}),
      memberNicknames: Map<String, String>.from(json['memberNicknames'] ?? {}),
      kickedMembers: List<String>.from(json['kickedMembers'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'items': items.map((e) => e.toJson()).toList(),
      'inviteCode': inviteCode,
      'ownerToken': ownerToken,
      'memberPermissions': memberPermissions,
      'memberNicknames': memberNicknames,
      'kickedMembers': kickedMembers,
    };
  }

  ChecklistGroup copyWith({
    String? id,
    String? title,
    List<ChecklistItem>? items,
    String? inviteCode,
    String? ownerToken,
    Map<String, String>? memberPermissions,
    Map<String, String>? memberNicknames,
    List<String>? kickedMembers,
  }) {
    return ChecklistGroup(
      id: id ?? this.id,
      title: title ?? this.title,
      items: items ?? this.items,
      inviteCode: inviteCode ?? this.inviteCode,
      ownerToken: ownerToken ?? this.ownerToken,
      memberPermissions: memberPermissions ?? this.memberPermissions,
      memberNicknames: memberNicknames ?? this.memberNicknames,
      kickedMembers: kickedMembers ?? this.kickedMembers,
    );
  }
}
