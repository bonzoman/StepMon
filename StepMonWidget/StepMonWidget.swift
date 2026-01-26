//
//  StepMonWidget.swift
//  StepMonWidget
//
//  Created by 오승준 on 1/26/26.
//
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    // App Group ID (메인 앱과 동일하게 설정)
    let appGroupId = "group.com.bnz.StepMon" // 본인의 App Group ID로 수정 필수
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), steps: 1234)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let steps = fetchStepsFromDefaults()
        let entry = SimpleEntry(date: Date(), steps: steps)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // 타임라인 갱신: 메인 앱에서 reloadAllTimelines()를 호출할 때 갱신됨
        // 혹은 30분마다 자동 갱신
        let steps = fetchStepsFromDefaults()
        let currentDate = Date()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate)!
        
        let entry = SimpleEntry(date: currentDate, steps: steps)
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
    
    private func fetchStepsFromDefaults() -> Int {
        if let sharedDefaults = UserDefaults(suiteName: appGroupId) {
            return sharedDefaults.integer(forKey: "widgetSteps")
        }
        return 0
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let steps: Int
}

struct StepMonWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack {
            Text("오늘의 걸음")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("\(entry.steps)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .padding(.vertical, 2)
            
            Text("StepMon")
                .font(.system(size: 10))
                .foregroundStyle(.gray.opacity(0.5))
        }
        .containerBackground(for: .widget) {
            Color.white
        }
    }
}

//@main
struct StepMonWidget: Widget {
    let kind: String = "StepMonWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            StepMonWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Step Monitor")
        .description("오늘의 걸음 수를 확인하세요.")
        .supportedFamilies([.systemSmall])
    }
}
