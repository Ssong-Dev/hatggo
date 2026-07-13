package com.hatggo.server;

import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Repository;
import org.springframework.web.client.RestClient;

import java.util.*;

@Repository
public class SupabaseRepository {

    private final RestClient anonClient;
    private final RestClient serviceClient;

    public SupabaseRepository(RestClient supabaseAnonClient, RestClient supabaseServiceClient) {
        this.anonClient = supabaseAnonClient;
        this.serviceClient = supabaseServiceClient;
    }

    // 1. 방 조회 (ID 기준)
    public Optional<ChecklistGroup> findGroupById(Long id) {
        List<ChecklistGroup> list = anonClient.get()
                .uri("/hatggo_room?id=eq." + id)
                .retrieve()
                .body(new ParameterizedTypeReference<List<ChecklistGroup>>() {});
        
        if (list == null || list.isEmpty()) {
            return Optional.empty();
        }
        
        ChecklistGroup group = list.get(0);
        enrichGroupDetails(group);
        return Optional.of(group);
    }

    // 2. 방 조회 (초대코드 기준)
    public Optional<ChecklistGroup> findGroupByInviteCode(String inviteCode) {
        List<ChecklistGroup> list = anonClient.get()
                .uri("/hatggo_room?invite_code=eq." + inviteCode)
                .retrieve()
                .body(new ParameterizedTypeReference<List<ChecklistGroup>>() {});
        
        if (list == null || list.isEmpty()) {
            return Optional.empty();
        }
        
        ChecklistGroup group = list.get(0);
        enrichGroupDetails(group);
        return Optional.of(group);
    }

    // 3. 방 생성
    public ChecklistGroup createGroup(ChecklistGroup group) {
        Map<String, Object> body = new HashMap<>();
        body.put("title", group.getTitle());
        body.put("invite_code", group.getInviteCode());
        body.put("type", group.getType());
        body.put("start_date", group.getStartDate());
        body.put("end_date", group.getEndDate());

        List<ChecklistGroup> created = anonClient.post()
                .uri("/hatggo_room")
                .header("Prefer", "return=representation")
                .contentType(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .body(new ParameterizedTypeReference<List<ChecklistGroup>>() {});

        if (created == null || created.isEmpty()) {
            throw new RuntimeException("Failed to create room in Supabase");
        }
        return created.get(0);
    }

    // 4. 사용자 정보 저장 (Upsert)
    public void upsertMember(String uuid, String nickname) {
        Map<String, Object> body = new HashMap<>();
        body.put("uuid", uuid);
        body.put("nickname", nickname);

        // ON CONFLICT (uuid) DO UPDATE SET nickname = EXCLUDED.nickname
        anonClient.post()
                .uri("/hatggo_member")
                .header("Prefer", "resolution=merge-duplicates")
                .contentType(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .toBodilessEntity();
    }

    // 5. 방 참가자 추가/수정 (Upsert)
    public void upsertRoomMember(Long roomId, String memberUuid, String role) {
        Map<String, Object> body = new HashMap<>();
        body.put("room_id", roomId);
        body.put("member_uuid", memberUuid);
        body.put("role", role);

        anonClient.post()
                .uri("/hatggo_room_member")
                .header("Prefer", "resolution=merge-duplicates")
                .contentType(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .toBodilessEntity();
    }

    // 6. 방 멤버 권한 변경
    public void updateRoomMemberPermission(Long roomId, String memberUuid, String permission) {
        Map<String, Object> body = new HashMap<>();
        body.put("role", permission);

        anonClient.patch()
                .uri(uriBuilder -> uriBuilder
                        .path("/hatggo_room_member")
                        .queryParam("room_id", "eq." + roomId)
                        .queryParam("member_uuid", "eq." + memberUuid)
                        .build())
                .contentType(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .toBodilessEntity();
    }

    // 7. 방 참가자 삭제 (강제퇴장 / 탈퇴)
    public void deleteRoomMember(Long roomId, String memberUuid) {
        anonClient.delete()
                .uri(uriBuilder -> uriBuilder
                        .path("/hatggo_room_member")
                        .queryParam("room_id", "eq." + roomId)
                        .queryParam("member_uuid", "eq." + memberUuid)
                        .build())
                .retrieve()
                .toBodilessEntity();
    }

    // 8. 체크리스트 아이템 추가
    public ChecklistItem addChecklistItem(ChecklistItem item) {
        Map<String, Object> body = new HashMap<>();
        body.put("room_id", item.getRoomId());
        body.put("content", item.getTitle());
        body.put("is_completed", item.isChecked());

        List<ChecklistItem> created = anonClient.post()
                .uri("/hatggo_checklist_item")
                .header("Prefer", "return=representation")
                .contentType(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .body(new ParameterizedTypeReference<List<ChecklistItem>>() {});

        if (created == null || created.isEmpty()) {
            throw new RuntimeException("Failed to add checklist item");
        }
        return created.get(0);
    }

    // 9. 체크리스트 아이템 삭제
    public boolean deleteChecklistItem(Long itemId) {
        try {
            anonClient.delete()
                    .uri("/hatggo_checklist_item?id=eq." + itemId)
                    .retrieve()
                    .toBodilessEntity();
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    // 10. 체크리스트 아이템 상태 수정 (체크 토글 등)
    public void updateChecklistItem(ChecklistItem item) {
        Map<String, Object> body = new HashMap<>();
        body.put("is_completed", item.isChecked());
        body.put("completed_by_uuid", item.getCompletedBy());
        body.put("completed_at", item.getCompletedAt());

        anonClient.patch()
                .uri("/hatggo_checklist_item?id=eq." + item.getId())
                .contentType(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .toBodilessEntity();
    }

    // 11. 체크리스트 아이템 전체 상태 초기화 (Uncheck All)
    public void uncheckAllItems(Long roomId) {
        Map<String, Object> body = new HashMap<>();
        body.put("is_completed", false);
        body.put("completed_by_uuid", null);
        body.put("completed_at", null);

        anonClient.patch()
                .uri("/hatggo_checklist_item?room_id=eq." + roomId)
                .contentType(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .toBodilessEntity();
    }

    // 12. 방 제목 업데이트
    public void updateRoomTitle(Long roomId, String title) {
        Map<String, Object> body = new HashMap<>();
        body.put("title", title);

        anonClient.patch()
                .uri("/hatggo_room?id=eq." + roomId)
                .contentType(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .toBodilessEntity();
    }

    // 13. 방 삭제
    public void deleteRoom(Long roomId) {
        anonClient.delete()
                .uri("/hatggo_room?id=eq." + roomId)
                .retrieve()
                .toBodilessEntity();
    }

    // 14. 데일리 루틴 전체 초기화 (스케줄러용 - Service Role 권한)
    public List<Long> resetAllDailyRoutines() {
        List<Long> resetRoomIds = new ArrayList<>();
        // DAILY_ROUTINE 타입인 모든 방에 속한 체크리스트 아이템들을 일괄 초기화
        List<Map<String, Object>> rooms = serviceClient.get()
                .uri("/hatggo_room?type=eq.DAILY_ROUTINE&select=id")
                .retrieve()
                .body(new ParameterizedTypeReference<List<Map<String, Object>>>() {});

        if (rooms != null) {
            for (Map<String, Object> room : rooms) {
                Object idObj = room.get("id");
                if (idObj != null) {
                    Long roomId = Long.valueOf(idObj.toString());
                    uncheckAllItems(roomId);
                    resetRoomIds.add(roomId);
                }
            }
        }
        return resetRoomIds;
    }

    // 방 내부 상세 정보(아이템 리스트, 유저 권한, 닉네임, 강퇴 목록 등) 동적 보충
    private void enrichGroupDetails(ChecklistGroup group) {
        // A. 아이템 목록 조회
        List<ChecklistItem> items = anonClient.get()
                .uri("/hatggo_checklist_item?room_id=eq." + group.getId() + "&order=id.asc")
                .retrieve()
                .body(new ParameterizedTypeReference<List<ChecklistItem>>() {});
        group.setItems(items != null ? items : new ArrayList<>());

        // B. 참가자 정보 조회 (hatggo_room_member 조인 조회 및 역직렬화)
        // member_uuid, role 컬럼 및 가입한 유저 정보 닉네임 조회
        List<Map<String, Object>> members = anonClient.get()
                .uri("/hatggo_room_member?room_id=eq." + group.getId() + "&select=member_uuid,role,hatggo_member(nickname)")
                .retrieve()
                .body(new ParameterizedTypeReference<List<Map<String, Object>>>() {});

        if (members != null) {
            for (Map<String, Object> m : members) {
                String memberUuid = (String) m.get("member_uuid");
                String role = (String) m.get("role");
                
                // 닉네임 파싱
                String nickname = "익명";
                Object memberObj = m.get("hatggo_member");
                if (memberObj instanceof Map) {
                    Object nick = ((Map<?, ?>) memberObj).get("nickname");
                    if (nick != null) {
                        nickname = nick.toString();
                    }
                }

                if (memberUuid != null) {
                    if ("OWNER".equals(role)) {
                        group.setOwnerToken(memberUuid); // 방장 UUID를 ownerToken으로 바인딩
                    }
                    group.getMemberPermissions().put(memberUuid, role.equals("READ_ONLY") ? "READ_ONLY" : "READ_WRITE");
                    group.getMemberNicknames().put(memberUuid, nickname);
                }
            }
        }
    }
}
