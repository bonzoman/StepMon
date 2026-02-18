import SwiftUI
import SwiftData
import UIKit

struct LogViewerView: View {
    @Query(sort: \AppLogEntry.timestamp, order: .reverse)
    private var logs: [AppLogEntry]

    var body: some View {
        VStack(spacing: 12) {
            ScrollView {
                if logs.isEmpty {
                    Text("로그 없음")
                        .font(.system(.footnote, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(logs.prefix(300)) { item in
                            VStack(alignment: .leading, spacing: 4) {
//                                Text(item.timestamp, style: .time)
                                Text(formatLocal(item.timestamp))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)

                                Text(item.message)
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundStyle(color(from: item.colorRaw))
                                    .textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }
            }

            HStack(spacing: 12) {
                Button("지우기") { AppLog.clear() }

                Spacer()

                Button("공유") { share() }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .navigationTitle("BG 로그")
    }

    private func color(from raw: String) -> Color {
        switch raw {
        case "red": return .red
        case "yellow": return .yellow
        case "gray": return .gray
        case "green": return .green
        case "blue": return .blue
        default: return .primary
        }
    }

    private func share() {
        guard let url = AppLog.exportURL() else { return }
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            vc.popoverPresentationController?.sourceView = root.view
            root.present(vc, animated: true)
        }
    }
    
    private func formatLocal(_ date: Date) -> String {
        let f = DateFormatter()
        // 사용자의 지역 설정을 반영합니다.
        f.locale = Locale.current
        f.timeZone = .current
        
        // "jmm" 또는 "Hm" 템플릿을 사용하면 시스템 설정에 따라
        // 한국인은 "14:00", 미국인은 "2:00 PM"으로 알아서 보여줍니다.
//        f.setLocalizedDateFormatFromTemplate("Hm")
        f.dateFormat = "HH:mm:ss" // ✅ 초까지 나오도록 변경
        
        return f.string(from: date)
    }
}
