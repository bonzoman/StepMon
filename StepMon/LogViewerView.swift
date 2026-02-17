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
                                Text(item.timestamp, style: .time)
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
}
