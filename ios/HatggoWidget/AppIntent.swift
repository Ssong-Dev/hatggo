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
        let suiteName = "group.com.yourcompany.hatggo"
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
        return .result()
    }
}
