//
//  StepMonWidget.swift
//  StepMonWidget
//
//  Created by 오승준 on 1/26/26.
//
//

import WidgetKit
import SwiftUI
import CoreMotion // [필수] 센서 접근을 위해 추가

struct Provider: TimelineProvider {
    // App Group ID
    let appGroupId = "group.com.bnz.stepmon"
    
    // [추가] 위젯이 직접 센서에 접근하기 위한 객체
    let pedometer = CMPedometer()
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), steps: 1234)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        // 스냅샷(미리보기)은 빨리 떠야 하므로 기존 방식(UserDefaults) 유지
        let steps = fetchStepsFromDefaults()
        let entry = SimpleEntry(date: Date(), steps: steps)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // [핵심 수정] 앱이 죽어있어도 위젯이 직접 하드웨어 센서값을 조회합니다.
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        
        // 기기가 걸음 측정을 지원하는지 확인
        if CMPedometer.isStepCountingAvailable() {
            // 오늘 0시 ~ 현재까지의 걸음 수 조회 (비동기)
            pedometer.queryPedometerData(from: startOfDay, to: now) { data, error in
                
                var finalSteps = 0
                
                if let realSteps = data?.numberOfSteps.intValue {
                    // 1. 센서 조회 성공 시: 실제 센서값 사용
                    finalSteps = realSteps
                } else {
                    // 2. 센서 조회 실패 시: 기존 저장값(UserDefaults) 사용 (Fallback)
                    finalSteps = fetchStepsFromDefaults()
                }
                
                // 타임라인 생성
                let entry = SimpleEntry(date: now, steps: finalSteps)
                
                // 15분 뒤에 다시 갱신하도록 예약 (iOS 시스템 최소 간격)
                // 이제 앱을 안 켜도 15~30분마다 스스로 숫자가 바뀝니다.
                let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: now)!
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                
                completion(timeline)
            }
        } else {
            // 센서 미지원 기기인 경우: 기존 방식 사용
            let steps = fetchStepsFromDefaults()
            let entry = SimpleEntry(date: now, steps: steps)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: now)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
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
                .foregroundStyle(.primary)
            
            Text("StepMon")
                .font(.system(size: 10))
                .foregroundStyle(.gray.opacity(0.5))
        }
        .containerBackground(for: .widget) {
            Color(uiColor: .systemBackground)
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
