import Foundation

enum AppLog {
    private static let fileName = "bglog.txt"
    private static let queue = DispatchQueue(label: "bnz.stepmon.applog")

    private static var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    static func write(_ message: String) {
        let dateString = formattedDate()
        let fullMessage = "\(dateString)\n\(message)\n"

        // ✅ DEBUG 빌드에서만 콘솔 출력
        #if DEBUG
        print(fullMessage)
        #endif

        // ✅ 파일 저장 (항상)
        queue.async {
            let line = fullMessage + "\n"
            guard let data = line.data(using: .utf8) else { return }

            do {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    let handle = try FileHandle(forWritingTo: fileURL)
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                    try handle.close()
                } else {
                    try data.write(to: fileURL, options: .atomic)
                }
            } catch {
                // 무한 루프 방지
            }
        }
    }

    static func read() -> String {
        (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    static func clear() {
        queue.async {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    static func exportURL() -> URL {
        fileURL
    }

    private static func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMdd HH:mm:ss"
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }
}
