import SwiftUI
import SwiftData

struct NotificationHistoryView: View {
    // 최신순으로 100개 조회
    @Query(sort: \NotificationHistory.timestamp, order: .reverse)
    private var history: [NotificationHistory]
    
    var body: some View {
        List {
            if history.isEmpty {
                ContentUnavailableView("기록 없음", systemImage: "tray", description: Text("백그라운드 작업이 실행되면 기록이 쌓입니다."))
            } else {
                ForEach(history.prefix(100)) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            HStack {
                                Text("걸음수: \(item.steps)보")
                                Text("/")
                                Text("기준: \(item.threshold)보")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        // 알림이 실제로 발송된 케이스 표시
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
