import SwiftUI
import SwiftData

struct NotificationHistoryView: View {
    @Query(sort: \NotificationHistory.timestamp, order: .reverse)
    private var history: [NotificationHistory]
    
    var body: some View {
        List {
            if history.isEmpty {
                ContentUnavailableView("기록 없음", systemImage: "tray", description: Text("백그라운드 작업이 실행되면 기록이 쌓입니다."))
            } else {
                ForEach(history.prefix(100)) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            // [상단 행] 시각 및 당시 집계 범위 표시
                            HStack(spacing: 8) {
                                Text(item.timestamp.formatted(
                                    .dateTime
                                        .month(.abbreviated)
                                        .day(.twoDigits)
                                        .hour(.twoDigits(amPM: .omitted))
                                        .minute(.twoDigits)
                                ))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                
                                // [위치 이동] 저장 시점의 집계 범위 표시
                                Text("(\(item.intervalMinutes)분 범위)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.orange.opacity(0.7))
                            }
                            
                            // [하단 행] 걸음 수 및 기준치
                            HStack(spacing: 4) {
                                Text("걸음수: \(item.steps)보")
                                Text("/")
                                    .foregroundStyle(.gray.opacity(0.5))
                                Text("기준: \(item.threshold)보")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        if item.isNotified {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(.orange)
                                .font(.system(size: 14))
                        }
                    }
                    .listRowBackground(item.isNotified ? Color.orange.opacity(0.05) : Color.clear)
                }
            }
        }
        .navigationTitle("알림 체크 히스토리")
        .navigationBarTitleDisplayMode(.inline)
    }
}
