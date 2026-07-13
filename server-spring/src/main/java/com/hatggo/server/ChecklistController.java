package com.hatggo.server;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.time.Instant;
import java.util.*;

@RestController
@CrossOrigin(origins = "*")
public class ChecklistController {

    private final SseService sseService;
    private final SupabaseRepository supabaseRepository;

    public ChecklistController(SseService sseService, SupabaseRepository supabaseRepository) {
        this.sseService = sseService;
        this.supabaseRepository = supabaseRepository;
    }

    // 6자리 고유 초대코드 생성 함수
    private String generateInviteCode() {
        String chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        Random random = new Random();
        while (true) {
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < 6; i++) {
                sb.append(chars.charAt(random.nextInt(chars.length())));
            }
            String code = sb.toString();
            // DB에 해당 초대코드가 존재하지 않는 경우 사용
            if (supabaseRepository.findGroupByInviteCode(code).isEmpty()) {
                return code;
            }
        }
    }

    // 1. REST API: 새 그룹 생성
    @PostMapping("/api/groups")
    public ResponseEntity<?> createGroup(@RequestBody Map<String, String> body) {
        String title = body.get("title");
        if (title == null || title.trim().isEmpty()) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("error", "그룹 제목은 필수입니다."));
        }

        String type = body.get("type"); // DAILY_ROUTINE or DEADLINE_BOUND
        String startDate = body.get("startDate");
        String endDate = body.get("endDate");
        String ownerToken = body.get("ownerToken"); // 방장 UUID
        String nickname = body.get("nickname"); // 방장 닉네임

        String inviteCode = generateInviteCode();

        ChecklistGroup tempGroup = new ChecklistGroup(null, title.trim(), inviteCode, type, startDate, endDate);
        ChecklistGroup createdGroup = supabaseRepository.createGroup(tempGroup);

        if (ownerToken != null && !ownerToken.trim().isEmpty()) {
            String cleanNickname = (nickname != null) ? nickname.trim() : "방장";
            supabaseRepository.upsertMember(ownerToken, cleanNickname);
            supabaseRepository.upsertRoomMember(createdGroup.getId(), ownerToken, "OWNER");
            
            // 데이터 강제 갱신 반영
            createdGroup = supabaseRepository.findGroupById(createdGroup.getId()).orElse(createdGroup);
        }

        System.out.println("[그룹 생성] Title: " + createdGroup.getTitle() + ", Code: " + inviteCode + ", OwnerToken: " + ownerToken);
        return ResponseEntity.status(HttpStatus.CREATED).body(createdGroup);
    }

    // 2. REST API: 초대코드로 그룹 참여
    @PostMapping("/api/groups/join")
    public ResponseEntity<?> joinGroup(@RequestBody Map<String, String> body) {
        String inviteCode = body.get("inviteCode");
        String memberId = body.get("memberId"); // 참가하려는 사용자 UUID
        String nickname = body.get("nickname"); // 참가하려는 사용자 닉네임

        if (inviteCode == null) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("error", "초대코드를 입력해주세요."));
        }

        String upperCode = inviteCode.trim().toUpperCase();
        Optional<ChecklistGroup> groupOpt = supabaseRepository.findGroupByInviteCode(upperCode);

        if (groupOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "유효하지 않은 초대코드입니다."));
        }

        ChecklistGroup group = groupOpt.get();

        // 사용자 정보 및 참가 정보 등록
        if (memberId != null && !memberId.trim().isEmpty()) {
            String cleanNickname = (nickname != null) ? nickname.trim() : "참여자";
            supabaseRepository.upsertMember(memberId, cleanNickname);
            
            // 이미 가입된 경우 권한 유지(기본 READ_WRITE), 신규 가입일 경우 MEMBER
            String currentPermission = group.getMemberPermissions().get(memberId);
            String role = (currentPermission != null) ? currentPermission : "READ_WRITE";
            if ("OWNER".equals(group.getOwnerToken()) && memberId.equals(group.getOwnerToken())) {
                role = "OWNER";
            }
            supabaseRepository.upsertRoomMember(group.getId(), memberId, role);
            
            // 갱신된 정보로 다시 조회
            group = supabaseRepository.findGroupById(group.getId()).orElse(group);
        }

        System.out.println("[그룹 가입] Code: " + upperCode + " -> Group: " + group.getTitle());
        return ResponseEntity.ok(group);
    }

    // 3. REST API: 특정 그룹 상세 조회
    @GetMapping("/api/groups/{id}")
    public ResponseEntity<?> getGroup(@PathVariable String id) {
        try {
            Long roomId = Long.parseLong(id);
            Optional<ChecklistGroup> groupOpt = supabaseRepository.findGroupById(roomId);
            if (groupOpt.isEmpty()) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "그룹을 찾을 수 없습니다."));
            }
            return ResponseEntity.ok(groupOpt.get());
        } catch (NumberFormatException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("error", "올바르지 않은 그룹 ID 형식입니다."));
        }
    }

    // 4. SSE 구독 API
    @GetMapping(value = "/api/groups/{groupId}/subscribe", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter subscribe(
            @PathVariable String groupId,
            @RequestParam String memberId,
            @RequestParam(required = false, defaultValue = "익명") String nickname) {
        
        Long roomId = Long.parseLong(groupId);
        Optional<ChecklistGroup> groupOpt = supabaseRepository.findGroupById(roomId);
        if (groupOpt.isEmpty()) {
            throw new IllegalArgumentException("Invalid Group ID");
        }

        ChecklistGroup group = groupOpt.get();

        // 강퇴 여부는 DB에서 룸 멤버 목록에 사용자가 존재하는지 여부 및 별도 보완 가능
        // 현재는 room_member 테이블에서 삭제되는 방식(강퇴 시 매핑 행 삭제)으로 구현
        if (!group.getMemberPermissions().containsKey(memberId) && !memberId.equals(group.getOwnerToken())) {
            // 강퇴 혹은 비가입 유저 구독 요청 차단 (신규 구독 시 자동 가입 연동)
            supabaseRepository.upsertMember(memberId, nickname);
            supabaseRepository.upsertRoomMember(roomId, memberId, "READ_WRITE");
            group = supabaseRepository.findGroupById(roomId).orElse(group);
        }

        SseEmitter emitter = sseService.subscribe(groupId, memberId, nickname);
        
        // 연결 즉시 현재의 최신 그룹 데이터를 Sync 이벤트로 한번 발송해줌
        sseService.broadcast(groupId, group);
        
        return emitter;
    }

    // 5. REST API: 아이템 추가
    @PostMapping("/api/groups/{groupId}/items")
    public ResponseEntity<?> addItem(
            @PathVariable String groupId, 
            @RequestHeader(value = "X-Member-Id", required = false) String memberId,
            @RequestBody Map<String, String> body) {
        
        Long roomId = Long.parseLong(groupId);
        Optional<ChecklistGroup> groupOpt = supabaseRepository.findGroupById(roomId);
        if (groupOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "그룹을 찾을 수 없습니다."));
        }

        ChecklistGroup group = groupOpt.get();

        // 권한 체크
        if (memberId != null) {
            String permission = group.getMemberPermissions().get(memberId);
            if ("READ_ONLY".equals(permission)) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "쓰기 권한이 없습니다."));
            }
        }

        String title = body.get("title");
        if (title == null || title.trim().isEmpty()) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("error", "아이템 제목은 필수입니다."));
        }

        ChecklistItem newItem = new ChecklistItem(null, roomId, title.trim(), false, null, null);
        ChecklistItem createdItem = supabaseRepository.addChecklistItem(newItem);

        // 변경 사항을 실시간 SSE 구독자들에게 브로드캐스트하기 위해 최신 그룹 정보 재조회
        ChecklistGroup updatedGroup = supabaseRepository.findGroupById(roomId).orElse(group);
        sseService.broadcast(groupId, updatedGroup);

        return ResponseEntity.status(HttpStatus.CREATED).body(createdItem);
    }

    // 6. REST API: 아이템 삭제
    @DeleteMapping("/api/groups/{groupId}/items/{itemId}")
    public ResponseEntity<?> deleteItem(
            @PathVariable String groupId, 
            @PathVariable String itemId,
            @RequestHeader(value = "X-Member-Id", required = false) String memberId) {
        
        Long roomId = Long.parseLong(groupId);
        Long itemLongId = Long.parseLong(itemId);
        Optional<ChecklistGroup> groupOpt = supabaseRepository.findGroupById(roomId);
        if (groupOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "그룹을 찾을 수 없습니다."));
        }

        ChecklistGroup group = groupOpt.get();

        // 권한 체크
        if (memberId != null) {
            String permission = group.getMemberPermissions().get(memberId);
            if ("READ_ONLY".equals(permission)) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "쓰기 권한이 없습니다."));
            }
        }

        boolean removed = supabaseRepository.deleteChecklistItem(itemLongId);
        if (removed) {
            System.out.println("[아이템 삭제] Group: " + group.getTitle() + ", ItemId: " + itemId);
            ChecklistGroup updatedGroup = supabaseRepository.findGroupById(roomId).orElse(group);
            sseService.broadcast(groupId, updatedGroup);
            return ResponseEntity.ok(Map.of("success", true));
        }

        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "아이템을 찾을 수 없습니다."));
    }

    // 7. REST API: 아이템 체크 토글
    @PostMapping("/api/groups/{groupId}/items/{itemId}/toggle")
    public ResponseEntity<?> toggleItem(
            @PathVariable String groupId,
            @PathVariable String itemId,
            @RequestHeader(value = "X-Member-Id", required = false) String memberId,
            @RequestBody Map<String, String> body) {
        
        Long roomId = Long.parseLong(groupId);
        Long itemLongId = Long.parseLong(itemId);
        Optional<ChecklistGroup> groupOpt = supabaseRepository.findGroupById(roomId);
        if (groupOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "그룹을 찾을 수 없습니다."));
        }

        ChecklistGroup group = groupOpt.get();

        // 권한 체크
        if (memberId != null) {
            String permission = group.getMemberPermissions().get(memberId);
            if ("READ_ONLY".equals(permission)) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "쓰기 권한이 없습니다."));
            }
        }

        String completedBy = body.get("completedBy"); // 완료자 UUID

        boolean updated = false;
        for (ChecklistItem item : group.getItems()) {
            if (item.getId().equals(itemLongId)) {
                boolean nextChecked = !item.isChecked();
                item.setChecked(nextChecked);
                item.setCompletedBy(nextChecked ? completedBy : null);
                item.setCompletedAt(nextChecked ? Instant.now().toString() : null);
                
                supabaseRepository.updateChecklistItem(item);
                updated = true;
                break;
            }
        }

        if (updated) {
            ChecklistGroup updatedGroup = supabaseRepository.findGroupById(roomId).orElse(group);
            sseService.broadcast(groupId, updatedGroup);
            return ResponseEntity.ok(updatedGroup);
        }

        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "아이템을 찾을 수 없습니다."));
    }

    // 8. REST API: 전체 체크 해제
    @PostMapping("/api/groups/{groupId}/uncheck-all")
    public ResponseEntity<?> uncheckAll(
            @PathVariable String groupId,
            @RequestHeader(value = "X-Member-Id", required = false) String memberId) {
        
        Long roomId = Long.parseLong(groupId);
        Optional<ChecklistGroup> groupOpt = supabaseRepository.findGroupById(roomId);
        if (groupOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "그룹을 찾을 수 없습니다."));
        }

        ChecklistGroup group = groupOpt.get();

        // 권한 체크
        if (memberId != null) {
            String permission = group.getMemberPermissions().get(memberId);
            if ("READ_ONLY".equals(permission)) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "쓰기 권한이 없습니다."));
            }
        }

        supabaseRepository.uncheckAllItems(roomId);

        System.out.println("[전체 해제] Group: " + group.getTitle());
        ChecklistGroup updatedGroup = supabaseRepository.findGroupById(roomId).orElse(group);
        sseService.broadcast(groupId, updatedGroup);

        return ResponseEntity.ok(updatedGroup);
    }

    // 9. REST API: 그룹 제목 업데이트
    @PutMapping("/api/groups/{groupId}/title")
    public ResponseEntity<?> updateTitle(
            @PathVariable String groupId, 
            @RequestHeader(value = "X-Member-Id", required = false) String memberId,
            @RequestBody Map<String, String> body) {
        
        Long roomId = Long.parseLong(groupId);
        Optional<ChecklistGroup> groupOpt = supabaseRepository.findGroupById(roomId);
        if (groupOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "그룹을 찾을 수 없습니다."));
        }

        ChecklistGroup group = groupOpt.get();

        // 권한 체크
        if (memberId != null) {
            String permission = group.getMemberPermissions().get(memberId);
            if ("READ_ONLY".equals(permission)) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "쓰기 권한이 없습니다."));
            }
        }

        String title = body.get("title");
        if (title == null || title.trim().isEmpty()) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("error", "그룹 제목은 필수입니다."));
        }

        supabaseRepository.updateRoomTitle(roomId, title.trim());
        System.out.println("[그룹 타이틀 변경] GroupId: " + groupId + " -> Title: " + title.trim());
        
        ChecklistGroup updatedGroup = supabaseRepository.findGroupById(roomId).orElse(group);
        sseService.broadcast(groupId, updatedGroup);

        return ResponseEntity.ok(updatedGroup);
    }

    // 10. REST API: 그룹 삭제
    @DeleteMapping("/api/groups/{groupId}")
    public ResponseEntity<?> deleteGroup(
            @PathVariable String groupId,
            @RequestHeader(value = "X-Owner-Token", required = false) String ownerToken) {
        
        Long roomId = Long.parseLong(groupId);
        Optional<ChecklistGroup> groupOpt = supabaseRepository.findGroupById(roomId);
        if (groupOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "그룹을 찾을 수 없습니다."));
        }

        ChecklistGroup group = groupOpt.get();

        // 방장 여부 확인 (ownerToken 검증)
        if (group.getOwnerToken() != null && !group.getOwnerToken().equals(ownerToken)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "방장만 그룹을 삭제할 수 있습니다."));
        }

        System.out.println("[그룹 삭제] GroupId: " + groupId);
        
        // 구독 중인 클라이언트들에게 그룹 삭제 알림 발송 및 SSE 커넥션 종료
        sseService.broadcastGroupDeleted(groupId);

        // Supabase DB에서 삭제
        supabaseRepository.deleteRoom(roomId);

        return ResponseEntity.ok(Map.of("success", true));
    }

    // 11. REST API: 참여자 권한 수정
    @PostMapping("/api/groups/{groupId}/permissions")
    public ResponseEntity<?> updatePermission(
            @PathVariable String groupId,
            @RequestHeader("X-Owner-Token") String ownerToken,
            @RequestBody Map<String, String> body) {
        
        Long roomId = Long.parseLong(groupId);
        Optional<ChecklistGroup> groupOpt = supabaseRepository.findGroupById(roomId);
        if (groupOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "그룹을 찾을 수 없습니다."));
        }

        ChecklistGroup group = groupOpt.get();

        if (group.getOwnerToken() == null || !group.getOwnerToken().equals(ownerToken)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "방장 권한이 없습니다."));
        }

        String targetMemberId = body.get("memberId");
        String permission = body.get("permission"); // "READ_WRITE" or "READ_ONLY"

        if (targetMemberId == null || permission == null) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("error", "memberId와 permission은 필수입니다."));
        }

        // DB 권한 업데이트
        supabaseRepository.updateRoomMemberPermission(roomId, targetMemberId, permission);

        ChecklistGroup updatedGroup = supabaseRepository.findGroupById(roomId).orElse(group);
        sseService.broadcast(groupId, updatedGroup);

        return ResponseEntity.ok(updatedGroup);
    }

    // 12. REST API: 참여자 강제 퇴장 (Kick)
    @PostMapping("/api/groups/{groupId}/kick")
    public ResponseEntity<?> kickMember(
            @PathVariable String groupId,
            @RequestHeader("X-Owner-Token") String ownerToken,
            @RequestBody Map<String, String> body) {
        
        Long roomId = Long.parseLong(groupId);
        Optional<ChecklistGroup> groupOpt = supabaseRepository.findGroupById(roomId);
        if (groupOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "그룹을 찾을 수 없습니다."));
        }

        ChecklistGroup group = groupOpt.get();

        if (group.getOwnerToken() == null || !group.getOwnerToken().equals(ownerToken)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "방장 권한이 없습니다."));
        }

        String targetMemberId = body.get("memberId");
        if (targetMemberId == null) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("error", "memberId는 필수입니다."));
        }

        // DB 룸 멤버 테이블에서 관계 삭제
        supabaseRepository.deleteRoomMember(roomId, targetMemberId);

        sseService.kickMember(groupId, targetMemberId);
        
        ChecklistGroup updatedGroup = supabaseRepository.findGroupById(roomId).orElse(group);
        sseService.broadcast(groupId, updatedGroup);

        return ResponseEntity.ok(updatedGroup);
    }
}
