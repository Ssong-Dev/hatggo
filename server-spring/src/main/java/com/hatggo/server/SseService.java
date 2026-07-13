package com.hatggo.server;

import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArraySet;

@Service
public class SseService {

    // key: groupId, value: Map of memberId -> SseEmitter
    private final Map<String, Map<String, SseEmitter>> roomEmitters = new ConcurrentHashMap<>();

    public SseEmitter subscribe(String groupId, String memberId, String nickname) {
        // 30분 타임아웃
        SseEmitter emitter = new SseEmitter(1800000L);
        
        roomEmitters.computeIfAbsent(groupId, k -> new ConcurrentHashMap<>()).put(memberId, emitter);
        System.out.println("[SSE 연결] User: " + nickname + " (ID: " + memberId + ") joined Group ID: " + groupId + " (Active clients: " + roomEmitters.get(groupId).size() + ")");

        emitter.onCompletion(() -> removeEmitter(groupId, memberId, nickname));
        emitter.onTimeout(() -> removeEmitter(groupId, memberId, nickname));
        emitter.onError((ex) -> removeEmitter(groupId, memberId, nickname));

        // 최초 연결 확인 메시지 전송
        try {
            emitter.send(SseEmitter.event()
                    .name("INIT")
                    .data("Connected"));
        } catch (IOException e) {
            removeEmitter(groupId, memberId, nickname);
        }

        return emitter;
    }

    public void broadcast(String groupId, Object payload) {
        Map<String, SseEmitter> emitters = roomEmitters.get(groupId);
        if (emitters == null || emitters.isEmpty()) {
            return;
        }

        for (Map.Entry<String, SseEmitter> entry : emitters.entrySet()) {
            try {
                entry.getValue().send(SseEmitter.event()
                        .name("SYNC")
                        .data(payload));
            } catch (IOException e) {
                entry.getValue().complete();
            }
        }
    }

    public void broadcastGroupDeleted(String groupId) {
        Map<String, SseEmitter> emitters = roomEmitters.get(groupId);
        if (emitters == null || emitters.isEmpty()) {
            return;
        }

        Map<String, String> payload = Map.of("type", "GROUP_DELETED", "groupId", groupId);
        for (Map.Entry<String, SseEmitter> entry : emitters.entrySet()) {
            try {
                entry.getValue().send(SseEmitter.event()
                        .name("GROUP_DELETED")
                        .data(payload));
                entry.getValue().complete();
            } catch (IOException e) {
                entry.getValue().complete();
            }
        }
        roomEmitters.remove(groupId);
    }

    public void kickMember(String groupId, String memberId) {
        Map<String, SseEmitter> emitters = roomEmitters.get(groupId);
        if (emitters == null) {
            return;
        }
        SseEmitter emitter = emitters.get(memberId);
        if (emitter != null) {
            try {
                emitter.send(SseEmitter.event()
                        .name("KICKED")
                        .data(Map.of("type", "KICKED", "groupId", groupId, "memberId", memberId)));
                emitter.complete();
            } catch (IOException e) {
                emitter.complete();
            }
        }
    }

    private void removeEmitter(String groupId, String memberId, String nickname) {
        Map<String, SseEmitter> emitters = roomEmitters.get(groupId);
        if (emitters != null) {
            emitters.remove(memberId);
            System.out.println("[SSE 연결 종료] User: " + nickname + " (ID: " + memberId + ") left Group ID: " + groupId + " (Remaining clients: " + emitters.size() + ")");
            if (emitters.isEmpty()) {
                roomEmitters.remove(groupId);
            }
        }
    }
}
