import SwiftUI
import SwiftData

struct NotificationHistoryView: View {
    @Query(sort: \NotificationHistory.timestamp, order: .reverse)
    private var history: [NotificationHistory]

    // "yyyy.MM.dd HH:mm" 포맷터
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // [추가] 상단 고정 주의 문구
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.top, 2)
                
                Text("앱을 강제 종료하거나 취침 등 장시간 미사용 시 알림을 위해 앱을 실행시켜 주세요.")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color.red.opacity(0.05)) // 옅은 빨간 배경으로 강조
            
            // 기존 리스트 영역
            List {
                if history.isEmpty {
                    ContentUnavailableView("기록 없음", systemImage: "tray", description: Text("백그라운드 작업이 실행되면 기록이 쌓입니다."))
                } else {
                    ForEach(history.prefix(30)) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                
                                // [상단 행] 시각
                                HStack(spacing: 8) {
                                    
                                    Text("\(item.timestamp, formatter: Self.dateFormatter)")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    
                                    Text(sourceLabel(item.source))
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(sourceColor(item.source).opacity(0.15))
                                        .foregroundStyle(sourceColor(item.source))
                                        .clipShape(Capsule())
                                }
                                
                                // [하단 행] 걸음 수 및 기준치
                                HStack(spacing: 4) {
                                    Text("최근 \(item.intervalMinutes)분 걸음: \(item.steps)")
                                        .foregroundStyle(item.steps < item.threshold ? .orange : .primary)
                                    Text("/")
                                        .foregroundStyle(.gray.opacity(0.5))
                                    Text("기준: \(item.threshold)보")
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                            }
                            
                            Spacer()
                            
                            // 알림 발송 아이콘
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
            .listStyle(.plain) // 문구와 자연스럽게 어우러지도록 스타일 조정
        }
        .navigationTitle("알림 체크 히스토리")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func sourceLabel(_ source: String) -> String {
        switch source {
        case "silentPush": return "Silent"
        case "bgTask": return "BG"
        case "foreground": return "FG"
        default: return source
        }
    }

    private func sourceColor(_ source: String) -> Color {
        switch source {
        case "silentPush": return .purple
        case "bgTask": return .blue
        case "foreground": return .green
        default: return .gray
        }
    }

}
