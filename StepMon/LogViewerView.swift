import SwiftUI
import UIKit

struct LogViewerView: View {
    @State private var text: AttributedString = ""

    var body: some View {
        VStack(spacing: 12) {
            ScrollView {
                Text(text.characters.isEmpty ? AttributedString("로그 없음") : text)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
            }

            HStack(spacing: 12) {
                Button("새로고침") { reload() }

                Button("전체 복사") {
                    UIPasteboard.general.string = String(text.characters)
                }

                Button("지우기") {
                    AppLog.clear()
                    reload()
                }

                Spacer()

                Button("공유") { share() }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .navigationTitle("BG 로그")
        .onAppear { reload() }
    }

    private func reload() {
        text = AppLog.readAttributed()
    }

    private func share() {
        let url = AppLog.exportURL()
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            vc.popoverPresentationController?.sourceView = root.view
            root.present(vc, animated: true)
        }
    }
}
