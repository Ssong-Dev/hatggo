import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "This is an example widget." }

    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String
}

// 버튼 클릭(체크박스 토글)을 처리하는 인터랙티브 AppIntent
struct ToggleChecklistItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Checklist Item"
    
    // 버튼을 누른 항목의 ID
    @Parameter(title: "Item ID")
    var itemId: String
    
    init() {}
    
    init(itemId: String) {
        self.itemId = itemId
    }

    func perform() async throws -> some IntentResult {
        let suiteName = "group.com.ssong.hatggo"
        let prefKey = "checklist_data"
        
        // App Group의 UserDefaults 접근
        guard let prefs = UserDefaults(suiteName: suiteName),
              let jsonString = prefs.string(forKey: prefKey),
              var data = jsonString.data(using: .utf8) else {
            return .result()
        }
        
        // JSON 파싱 및 상태 반전 (Dart 개입 없이 네이티브 환경에서 직접 수행)
        if var list = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
            for i in 0..<list.count {
                if let id = list[i]["id"] as? String, id == itemId {
                    let current = list[i]["isChecked"] as? Bool ?? false
                    list[i]["isChecked"] = !current
                    break
                }
            }
            // 변경된 JSON을 다시 저장
            if let newData = try? JSONSerialization.data(withJSONObject: list, options: []),
               let newString = String(data: newData, encoding: .utf8) {
                prefs.set(newString, forKey: prefKey)
            }
        }
        
        // Widget 타임라인 즉시 새로고침 요청
        WidgetCenter.shared.reloadTimelines(ofKind: "HatggoWidget")
        if #available(iOS 16.0, *) {
            return .result()
        } else {
            // Fallback on earlier versions
        }
    }
}

// 위젯에서 완료 처리 버튼을 눌렀을 때 실행되는 인텐트
struct CompleteChecklistIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Checklist"
    
    init() {}
    
    func perform() async throws -> some IntentResult {
        let suiteName = "group.com.ssong.hatggo"
        let prefKey = "checklist_data"
        let historyKey = "pending_history_logs"
        
        guard let prefs = UserDefaults(suiteName: suiteName),
              let jsonString = prefs.string(forKey: prefKey),
              let data = jsonString.data(using: .utf8) else {
            return .result()
        }
        
        if var list = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
            // 체크된 항목만 추출
            let checkedItems = list.filter { ($0["isChecked"] as? Bool) == true }
            
            if !checkedItems.isEmpty {
                // 히스토리 로그 생성
                let groupId = prefs.string(forKey: "active_group_id") ?? "unknown"
                let groupTitle = prefs.string(forKey: "active_group_title") ?? "Unknown Group"
                
                let isoFormatter = ISO8601DateFormatter()
                
                let historyLog: [String: Any] = [
                    "id": UUID().uuidString,
                    "groupId": groupId,
                    "groupTitle": groupTitle,
                    "completedAt": isoFormatter.string(from: Date()),
                    "items": checkedItems
                ]
                
                // 기존 보관함 읽기
                var pendingLogs: [[String: Any]] = []
                if let pendingJsonString = prefs.string(forKey: historyKey),
                   let pendingData = pendingJsonString.data(using: .utf8),
                   let existingLogs = try? JSONSerialization.jsonObject(with: pendingData, options: []) as? [[String: Any]] {
                    pendingLogs = existingLogs
                }
                
                // 새 히스토리 추가 후 저장
                pendingLogs.append(historyLog)
                if let newPendingData = try? JSONSerialization.data(withJSONObject: pendingLogs, options: []),
                   let newPendingString = String(data: newPendingData, encoding: .utf8) {
                    prefs.set(newPendingString, forKey: historyKey)
                }
            }
            
            // 위젯 상의 모든 항목 체크 해제
            for i in 0..<list.count {
                list[i]["isChecked"] = false
            }
            
            if let newData = try? JSONSerialization.data(withJSONObject: list, options: []),
               let newString = String(data: newData, encoding: .utf8) {
                prefs.set(newString, forKey: prefKey)
            }
        }
        
        WidgetCenter.shared.reloadTimelines(ofKind: "HatggoWidget")
        return .result()
    }
}

