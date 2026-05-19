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
    let suiteName = "group.com.ssong.hatggo"
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
    
    let primaryColor = Color(red: 155/255, green: 137/255, blue: 255/255)
    let secondaryColor = Color(red: 107/255, green: 206/255, blue: 180/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("햇꼬 체크리스트")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 2)
            
            if entry.items.isEmpty {
                Text("진행 중인 체크리스트가 없습니다.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                // 최대 12개 항목 노출 (systemLarge 위젯 지원)
                ForEach(entry.items.prefix(12)) { item in
                    Button(intent: ToggleChecklistItemIntent(itemId: item.id)) {
                        HStack(spacing: 10) {
                            Image(systemName: item.isChecked ? "checkmark.square.fill" : "square")
                                .foregroundColor(item.isChecked ? secondaryColor : .secondary.opacity(0.5))
                                .font(.system(size: 18))
                            
                            Text(item.title)
                                .strikethrough(item.isChecked)
                                .foregroundColor(item.isChecked ? .secondary : .primary)
                                .lineLimit(1)
                                .font(.system(size: 14, weight: item.isChecked ? .regular : .medium))
                            
                            Spacer()
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 8)
                        .background(Color(UIColor.secondarySystemBackground).opacity(item.isChecked ? 0.2 : 0.6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(intent: CompleteChecklistIntent()) {
                    HStack {
                        Spacer()
                        Text("완료 처리")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .background(primaryColor)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            Spacer()
        }
        .containerBackground(.thinMaterial, for: .widget)
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
