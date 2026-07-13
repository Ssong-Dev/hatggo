package com.hatggo.server;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Optional;

@Component
public class ChecklistRoutineScheduler {

    private final SupabaseRepository supabaseRepository;
    private final SseService sseService;

    public ChecklistRoutineScheduler(SupabaseRepository supabaseRepository, SseService sseService) {
        this.supabaseRepository = supabaseRepository;
        this.sseService = sseService;
    }

    // 매일 자정에 DAILY_ROUTINE 타입의 체크리스트 전체 상태 초기화 수행
    @Scheduled(cron = "0 0 0 * * *")
    public void resetDailyRoutines() {
        System.out.println("[스케줄러] 매일 반복 루틴 자정 리셋 작업을 수행합니다.");
        
        List<Long> resetRoomIds = supabaseRepository.resetAllDailyRoutines();
        
        for (Long roomId : resetRoomIds) {
            Optional<ChecklistGroup> groupOpt = supabaseRepository.findGroupById(roomId);
            if (groupOpt.isPresent()) {
                ChecklistGroup group = groupOpt.get();
                System.out.println("[스케줄러 리셋] Group ID: " + roomId + " (" + group.getTitle() + ") 리셋 완료");
                // 실시간 구독 클라이언트에게 동기화 브로드캐스트
                sseService.broadcast(String.valueOf(roomId), group);
            }
        }
    }
}
