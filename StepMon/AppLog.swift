import Foundation
import SwiftUI

enum AppLog {
    private static let fileName = "bglog.txt"
    private static let queue = DispatchQueue(label: "bnz.stepmon.applog")

    private static var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    enum LogColor: String, Codable {
        case normal
        case red
        case yellow
        case gray
        case green
        case blue
    }

    private struct Entry: Codable {
        let time: String          // "HH:mm:ss"
        let message: String
        let color: LogColor
    }

    // ✅ 기존: write(message)
    static func write(_ message: String) {
        write(message, .normal)
    }

    // ✅ 추가: write(message, .red)
    static func write(_ message: String, _ color: LogColor) {
        let entry = Entry(time: formattedTime(), message: message, color: color)

        #if DEBUG
        print("\(entry.time)\n\(entry.message)\n")
        #endif

        queue.async {
            var entries = loadEntries()
            entries.insert(entry, at: 0)                 // ✅ 최신이 맨 위로
            if entries.count > 100 {                     // ✅ 100개만 유지
                entries = Array(entries.prefix(100))
            }
            saveEntries(entries)
        }
    }

    /// ✅ 텍스트로 읽기(최신이 위)
    static func read() -> String {
        let entries = queue.sync { loadEntries() }
        return entries
            .map { "\($0.time)\n\($0.message)\n" }
            .joined(separator: "\n")
    }

    /// ✅ 빨간색 포함 AttributedString (LogViewerView에서 사용)
    static func readAttributed() -> AttributedString {
        let entries = queue.sync { loadEntries() }

        var result = AttributedString("")
        for (idx, e) in entries.enumerated() {
            var chunk = AttributedString("\(e.time)\n\(e.message)\n")
            switch e.color {
            case .normal:
                break
            case .red:
                chunk.foregroundColor = .red
            case .yellow:
                chunk.foregroundColor = .yellow
            case .gray:
                chunk.foregroundColor = .gray
            case .green:
                chunk.foregroundColor = .green
            case .blue:
                chunk.foregroundColor = .blue
            }

            result += chunk
            if idx != entries.count - 1 {
                result += AttributedString("\n")
            }
        }
        return result
    }

    static func clear() {
        queue.async {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    static func exportURL() -> URL {
        fileURL
    }

    // MARK: - Private

    private static func formattedTime() -> String {
        let formatter = DateFormatter()
        // 1. 사용자의 현재 지역 설정을 따름
        formatter.locale = Locale.current
        formatter.timeZone = .current
        
        // 2. '시간, 분, 초'가 필요하다는 템플릿을 제공
        // 시스템이 사용자 설정에 맞춰 "14:05:01" 또는 "2:05:01 PM"으로 변환합니다.
        formatter.setLocalizedDateFormatFromTemplate("Hms")
        
        return formatter.string(from: Date())
    }

    private static func loadEntries() -> [Entry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        // JSON 배열로 저장/로드
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    private static func saveEntries(_ entries: [Entry]) {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // 무한 루프 방지
        }
    }
}
