import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import '../models/checklist_group.dart';
import '../models/checklist_item.dart';
import 'nickname_provider.dart';

const String _groupPrefKey = 'checklist_groups';
const String _activeGroupPrefKey = 'active_group_id';
const String _memberIdPrefKey = 'user_member_id';
const String _ownerTokensPrefKey = 'owner_tokens'; // Map of groupId -> ownerToken
const String _iOSWidgetName = 'HatggoWidget';
const String _androidWidgetName = 'WidgetActionReceiver';
const String _widgetDataKey = 'checklist_data';

// 에뮬레이터 및 시뮬레이터 구동 환경에 따른 서버 주소 설정
String get serverHost {
  if (kIsWeb) return 'localhost:3000';
  if (Platform.isAndroid) return '10.0.2.2:3000';
  return 'localhost:3000';
}

class GroupNotifier extends Notifier<List<ChecklistGroup>> {
  WebSocketChannel? _wsChannel;
  String? _currentWsGroupId;
  String _memberId = '';
  Map<String, String> _ownerTokens = {};

  String get memberId => _memberId;
  
  String? getOwnerToken(String groupId) => _ownerTokens[groupId];

  @override
  List<ChecklistGroup> build() {
    _loadMemberIdAndTokens().then((_) {
      _loadFromPrefs();
    });

    // 선언적으로 활성 그룹 및 닉네임 변경 시 WebSocket 연결 관리
    final activeId = ref.watch(activeGroupIdProvider);
    final nickname = ref.watch(nicknameProvider);

    if (activeId != null && _memberId.isNotEmpty) {
      // 로드된 그룹들 중에서 찾아서 서버 연동 그룹인 경우에만 WS 연결 수행
      Future.microtask(() {
        try {
          final group = state.firstWhere((g) => g.id == activeId);
          if (group.inviteCode != null) {
            _connectWebSocket(activeId, nickname);
          } else {
            _disconnectWebSocket();
          }
        } catch (e) {
          // 아직 데이터가 로드 중인 경우 등
        }
      });
    } else {
      Future.microtask(() => _disconnectWebSocket());
    }

    ref.onDispose(() {
      _disconnectWebSocket();
    });

    return [];
  }

  Future<void> _loadMemberIdAndTokens() async {
    final prefs = await SharedPreferences.getInstance();
    String? mId = prefs.getString(_memberIdPrefKey);
    if (mId == null || mId.isEmpty) {
      mId = Uuid().v4();
      await prefs.setString(_memberIdPrefKey, mId);
    }
    _memberId = mId;

    final tokensJson = prefs.getString(_ownerTokensPrefKey);
    if (tokensJson != null) {
      try {
        _ownerTokens = Map<String, String>.from(jsonDecode(tokensJson));
      } catch (e) {
        _ownerTokens = {};
      }
    }
  }

  Future<void> _saveOwnerTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ownerTokensPrefKey, jsonEncode(_ownerTokens));
  }

  void _connectWebSocket(String groupId, String nickname) {
    if (_currentWsGroupId == groupId && _wsChannel != null) return;
    
    _disconnectWebSocket();

    final wsUrl = Uri.parse('ws://$serverHost/ws?groupId=$groupId&nickname=${Uri.encodeComponent(nickname)}&memberId=$_memberId');
    try {
      _wsChannel = WebSocketChannel.connect(wsUrl);
      _currentWsGroupId = groupId;

      _wsChannel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            if (data['type'] == 'SYNC') {
              final serverGroup = ChecklistGroup.fromJson(data['group']);
              state = state.map((g) {
                if (g.id == serverGroup.id) {
                  return serverGroup;
                }
                return g;
              }).toList();
              _saveToPrefs();

              // 현재 활성 그룹인 경우 위젯에도 즉시 동기화
              final activeId = ref.read(activeGroupIdProvider);
              if (activeId == serverGroup.id) {
                WidgetSyncService.syncActiveGroupToWidget(serverGroup);
              }
            } else if (data['type'] == 'GROUP_DELETED') {
              final deletedGroupId = data['groupId'];
              state = state.where((g) => g.id != deletedGroupId).toList();
              _saveToPrefs();
              _disconnectWebSocket();
            } else if (data['type'] == 'KICKED') {
              final kickedGroupId = data['groupId'];
              final kickedMemberId = data['memberId'];
              if (kickedMemberId == _memberId) {
                // 강퇴당함: 로컬 목록에서 삭제하고 홈화면 등으로 강제 튕기도록 처리
                state = state.where((g) => g.id != kickedGroupId).toList();
                _ownerTokens.remove(kickedGroupId);
                _saveOwnerTokens();
                _saveToPrefs();
                _disconnectWebSocket();
                
                final activeId = ref.read(activeGroupIdProvider);
                if (activeId == kickedGroupId) {
                  ref.read(activeGroupIdProvider.notifier).setActiveGroup(state.isNotEmpty ? state.first.id : '');
                }
              }
            }
          } catch (e) {
            // ignore
          }
        },
        onError: (err) {
          // 에러 시 재연결 시도는 생략하거나 간략화
        },
        onDone: () {
          _wsChannel = null;
          _currentWsGroupId = null;
        },
      );
    } catch (e) {
      // ignore
    }
  }

  void _disconnectWebSocket() {
    _wsChannel?.sink.close();
    _wsChannel = null;
    _currentWsGroupId = null;
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

  // 로컬 단독 그룹 추가
  void addGroup(String title) {
    if (title.trim().isEmpty) return;
    final newGroup = ChecklistGroup(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
    );
    state = [...state, newGroup];
    _saveToPrefs();
  }

  // 서버 공유형 그룹 추가 (API 호출)
  Future<void> addServerGroup(String title) async {
    if (title.trim().isEmpty) return;
    try {
      final ownerToken = Uuid().v4();
      final response = await http.post(
        Uri.parse('http://$serverHost/api/groups'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title.trim(),
          'ownerToken': ownerToken,
        }),
      );

      if (response.statusCode == 201) {
        final newGroup = ChecklistGroup.fromJson(jsonDecode(response.body));
        _ownerTokens[newGroup.id] = ownerToken;
        await _saveOwnerTokens();

        state = [...state, newGroup];
        await _saveToPrefs();
        await ref.read(activeGroupIdProvider.notifier).setActiveGroup(newGroup.id);
      } else {
        throw Exception('서버 그룹 생성 실패');
      }
    } catch (e) {
      // 네트워크 에러 시 대체로 로컬 생성 수행
      addGroup(title);
    }
  }

  // 초대코드로 서버 그룹 참가 (API 호출)
  Future<void> joinGroupWithCode(String inviteCode) async {
    if (inviteCode.trim().isEmpty) return;
    final response = await http.post(
      Uri.parse('http://$serverHost/api/groups/join'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'inviteCode': inviteCode.trim().toUpperCase()}),
    );

    if (response.statusCode == 200) {
      final joinedGroup = ChecklistGroup.fromJson(jsonDecode(response.body));
      
      // 이미 참여 중인 그룹이면 추가 안 함
      if (state.any((g) => g.id == joinedGroup.id)) {
        await ref.read(activeGroupIdProvider.notifier).setActiveGroup(joinedGroup.id);
        return;
      }

      state = [...state, joinedGroup];
      await _saveToPrefs();
      await ref.read(activeGroupIdProvider.notifier).setActiveGroup(joinedGroup.id);
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? '그룹 참가 실패');
    }
  }

  void removeGroup(String id) {
    final group = state.firstWhere((g) => g.id == id, orElse: () => ChecklistGroup(id: '', title: ''));
    if (group.id.isNotEmpty && group.inviteCode != null) {
      // 공유 그룹 삭제 시 서버에 삭제 요청 (방장일 때만 토큰 포함)
      final ownerToken = _ownerTokens[id];
      http.delete(
        Uri.parse('http://$serverHost/api/groups/$id'),
        headers: {
          'Content-Type': 'application/json',
          if (ownerToken != null) 'X-Owner-Token': ownerToken,
        },
      );
    }
    
    state = state.where((g) => g.id != id).toList();
    _ownerTokens.remove(id);
    _saveOwnerTokens();
    _saveToPrefs();
    
    // 만약 삭제한 그룹이 현재 활성화되어 있었다면 다른 그룹 활성화
    final activeId = ref.read(activeGroupIdProvider);
    if (activeId == id) {
      if (state.isNotEmpty) {
        ref.read(activeGroupIdProvider.notifier).setActiveGroup(state.first.id);
      } else {
        ref.read(activeGroupIdProvider.notifier).setActiveGroup('');
      }
    }
  }

  void updateGroupTitle(String id, String newTitle) {
    if (newTitle.trim().isEmpty) return;
    
    final group = state.firstWhere((g) => g.id == id, orElse: () => ChecklistGroup(id: '', title: ''));
    if (group.id.isNotEmpty && group.inviteCode != null) {
      http.put(
        Uri.parse('http://$serverHost/api/groups/$id/title'),
        headers: {
          'Content-Type': 'application/json',
          'X-Member-Id': _memberId,
        },
        body: jsonEncode({'title': newTitle.trim()}),
      );
      return;
    }

    state = state.map((g) {
      if (g.id == id) return g.copyWith(title: newTitle.trim());
      return g;
    }).toList();
    _saveToPrefs();
  }

  void addItemToGroup(String groupId, String title) {
    if (title.trim().isEmpty) return;

    final group = state.firstWhere((g) => g.id == groupId, orElse: () => ChecklistGroup(id: '', title: ''));
    if (group.id.isNotEmpty && group.inviteCode != null) {
      http.post(
        Uri.parse('http://$serverHost/api/groups/$groupId/items'),
        headers: {
          'Content-Type': 'application/json',
          'X-Member-Id': _memberId,
        },
        body: jsonEncode({'title': title.trim()}),
      );
      return;
    }

    // 로컬 전용 처리
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
    final group = state.firstWhere((g) => g.id == groupId, orElse: () => ChecklistGroup(id: '', title: ''));
    final nickname = ref.read(nicknameProvider);

    if (group.id.isNotEmpty && group.inviteCode != null) {
      http.post(
        Uri.parse('http://$serverHost/api/groups/$groupId/items/$itemId/toggle'),
        headers: {
          'Content-Type': 'application/json',
          'X-Member-Id': _memberId,
        },
        body: jsonEncode({'completedBy': nickname}),
      );
      return;
    }

    // 로컬 전용 처리
    state = state.map((g) {
      if (g.id == groupId) {
        final newItems = g.items.map((i) {
          if (i.id == itemId) {
            final nextChecked = !i.isChecked;
            return i.copyWith(
              isChecked: nextChecked,
              completedBy: nextChecked ? nickname : null,
              completedAt: nextChecked ? DateTime.now() : null,
            );
          }
          return i;
        }).toList();
        return g.copyWith(items: newItems);
      }
      return g;
    }).toList();
    _saveToPrefs();
  }

  void removeItemFromGroup(String groupId, String itemId) {
    final group = state.firstWhere((g) => g.id == groupId, orElse: () => ChecklistGroup(id: '', title: ''));
    if (group.id.isNotEmpty && group.inviteCode != null) {
      http.delete(
        Uri.parse('http://$serverHost/api/groups/$groupId/items/$itemId'),
        headers: {
          'Content-Type': 'application/json',
          'X-Member-Id': _memberId,
        },
      );
      return;
    }

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
    final group = state.firstWhere((g) => g.id == groupId, orElse: () => ChecklistGroup(id: '', title: ''));
    if (group.id.isNotEmpty && group.inviteCode != null) {
      http.post(
        Uri.parse('http://$serverHost/api/groups/$groupId/uncheck-all'),
        headers: {
          'Content-Type': 'application/json',
          'X-Member-Id': _memberId,
        },
      );
      return;
    }

    state = state.map((g) {
      if (g.id == groupId) {
        final newItems = g.items.map((i) => i.copyWith(
          isChecked: false,
          completedBy: null,
          completedAt: null,
        )).toList();
        return g.copyWith(items: newItems);
      }
      return g;
    }).toList();
    _saveToPrefs();
  }

  // 참여자 권한 제어 API 호출 (방장 전용)
  Future<void> updateMemberPermission(String groupId, String targetMemberId, String permission) async {
    final ownerToken = _ownerTokens[groupId];
    if (ownerToken == null) return;

    await http.post(
      Uri.parse('http://$serverHost/api/groups/$groupId/permissions'),
      headers: {
        'Content-Type': 'application/json',
        'X-Owner-Token': ownerToken,
      },
      body: jsonEncode({
        'memberId': targetMemberId,
        'permission': permission,
      }),
    );
  }

  // 참여자 강제 퇴장 API 호출 (방장 전용)
  Future<void> kickMember(String groupId, String targetMemberId) async {
    final ownerToken = _ownerTokens[groupId];
    if (ownerToken == null) return;

    await http.post(
      Uri.parse('http://$serverHost/api/groups/$groupId/kick'),
      headers: {
        'Content-Type': 'application/json',
        'X-Owner-Token': ownerToken,
      },
      body: jsonEncode({
        'memberId': targetMemberId,
      }),
    );
  }
  
  Future<void> syncFromWidget(String? activeGroupId) async {
    if (activeGroupId == null) return;
    
    // 공유 그룹은 클라이언트 위젯에서 수정했을 경우 동기화하는 것을 방지하고(웹소켓으로만 처리) 로컬 그룹만 우선 동기화
    final group = state.firstWhere((g) => g.id == activeGroupId, orElse: () => ChecklistGroup(id: '', title: ''));
    if (group.id.isNotEmpty && group.inviteCode != null) return;

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
