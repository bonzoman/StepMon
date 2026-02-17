import Foundation
import SwiftUI
import SwiftData

enum AppLog {
    private static let queue = DispatchQueue(label: "bnz.stepmon.applog")

    private static var container: ModelContainer?
    private static var trimCounter = 0

    enum LogColor: String, Codable {
        case normal, red, yellow, gray, green, blue
    }

    // ✅ 앱 시작 시 1회 주입
    static func configure(container: ModelContainer) {
        self.container = container
    }

    static func write(_ message: String) {
        write(message, .normal)
    }

    static func write(_ message: String, _ color: LogColor) {
        
        
        #if DEBUG
        print("\(formattedTime())\n\(message)\n")
        #endif

        guard let container else { return }

        queue.async {
            let ctx = ModelContext(container)
            ctx.insert(AppLogEntry(timestamp: Date(),
                                  message: message,
                                  colorRaw: color.rawValue))
            
            // // ✅ 로그 개수 제한(예: 300개) — 오래된 것 삭제
            trimCounter += 1
            if trimCounter % 10 == 0 {
                trimIfNeeded(context: ctx, maxCount: 300)
            }

            

            do { try ctx.save() } catch {
                // 무한루프 방지: 여기서 다시 AppLog.write 호출 금지
            }
        }
    }

    static func clear() {
        guard let container else { return }
        queue.async {
            let ctx = ModelContext(container)
            let fd = FetchDescriptor<AppLogEntry>()
            if let items = try? ctx.fetch(fd) {
                for it in items { ctx.delete(it) }
                try? ctx.save()
            }
        }
    }

    // 공유용(버튼 눌렀을 때만) — 임시 파일 생성
    static func exportURL() -> URL? {
        guard let container else { return nil }
        let ctx = ModelContext(container)

        let fd = FetchDescriptor<AppLogEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let items = (try? ctx.fetch(fd)) ?? []

        let text = items.map {
            "\(formatLocal($0.timestamp))\n\($0.message)\n"
        }.joined(separator: "\n")

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bglog.txt")

        do {
            try text.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Private

    private static func trimIfNeeded(context: ModelContext, maxCount: Int) {
        // 1) 최신 maxCount개의 "마지막(가장 오래된) timestamp"를 구함
        var fd = FetchDescriptor<AppLogEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        fd.fetchLimit = maxCount

        guard let latest = try? context.fetch(fd),
              latest.count == maxCount,
              let cutoff = latest.last?.timestamp else {
            return // 아직 maxCount 미만이면 trim 불필요
        }

        // 2) cutoff 보다 "엄격히" 오래된 것만 삭제
        let predicate = #Predicate<AppLogEntry> { $0.timestamp < cutoff }
        var delFD = FetchDescriptor<AppLogEntry>(predicate: predicate)
        delFD.fetchLimit = 500 // 한 번에 너무 많이 지우지 않도록

        if let olds = try? context.fetch(delFD), !olds.isEmpty {
            for o in olds { context.delete(o) }
        }
    }


    private static func formattedTime() -> String {
        let f = DateFormatter()
        f.locale = .current
        f.timeZone = .current
//        f.setLocalizedDateFormatFromTemplate("Hms")
        f.dateFormat = "HH:mm:ss"   // ✅ 고정 포맷
        return f.string(from: Date())
    }

    private static func formatLocal(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.timeZone = .current
        f.dateFormat = "yyyy.MM.dd HH:mm:ss"
        return f.string(from: date)
    }
}
