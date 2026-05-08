import WidgetKit
import SwiftUI
import AppIntents

// Flutter 앱과 동일한 데이터 모델
struct ChecklistItem: Codable, Identifiable {
    let id: String
    let title: String
    let isChecked: Bool
}

struct Provider: TimelineProvider {
    let suiteName = "group.com.yourcompany.hatggo"
    let prefKey = "checklist_data"
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), items: [
            ChecklistItem(id: "1", title: "가스 밸브 잠그기", isChecked: false),
            ChecklistItem(id: "2", title: "보일러 끄기", isChecked: true)
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(placeholder(in: context))
    }

    // UserDefaults에서 실제 데이터를 불러오는 로직
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var items: [ChecklistItem] = []
        
        if let prefs = UserDefaults(suiteName: suiteName),
           let jsonString = prefs.string(forKey: prefKey),
           let data = jsonString.data(using: .utf8) {
            do {
                items = try JSONDecoder().decode([ChecklistItem].self, from: data)
            } catch {
                print("Decode error: \(error)")
            }
        }
        
        let entry = SimpleEntry(date: Date(), items: items)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let items: [ChecklistItem]
}

struct HatggoWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("햇꼬 체크리스트")
                .font(.headline)
                .padding(.bottom, 4)
            
            if entry.items.isEmpty {
                Text("항목이 없습니다.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else {
                // 최대 5개 항목 노출
                ForEach(entry.items.prefix(5)) { item in
                    HStack(spacing: 12) {
                        // 인터랙티브 버튼: ToggleChecklistItemIntent 호출
                        Button(intent: ToggleChecklistItemIntent(itemId: item.id)) {
                            Image(systemName: item.isChecked ? "checkmark.square.fill" : "square")
                                .foregroundColor(item.isChecked ? .gray : .blue)
                                .font(.system(size: 20))
                        }
                        .buttonStyle(.plain)
                        
                        Text(item.title)
                            .strikethrough(item.isChecked)
                            .foregroundColor(item.isChecked ? .gray : .primary)
                            .lineLimit(1)
                            .font(.system(size: 15))
                        
                        Spacer()
                    }
                }
            }
            Spacer()
        }
        .containerBackground(Color(UIColor.systemBackground), for: .widget)
    }
}

struct HatggoWidget: Widget {
    let kind: String = "HatggoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            HatggoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("햇꼬 체크리스트")
        .description("앱을 열지 않고 체크리스트를 확인하고 조작하세요.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
