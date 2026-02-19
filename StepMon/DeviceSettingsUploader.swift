import Foundation

actor DeviceSettingsUploader {
    //TODO: device
//    static let shared = DeviceSettingsUploader()
//
//    // ✅ 너 서버 주소로 바꾸기
//    private let endpoint = URL(string: "http://192.168.0.205:8888/api/device/settings")!
//
//    private let pendingKey = "bnz.stepmon.pendingDeviceSettings"
//    private var isSending = false
//
//    struct Payload: Codable {
//        let installId: String
//        let isNotificationEnabled: Bool
//        let startMinutes: Int
//        let endMinutes: Int
//        let timeZone: String
//
//        let platform: String
//        let appVersion: String
//        let sentAt: String
//    }
//
//    /// Settings 변경 시 호출
//    func upsert(isNotificationEnabled: Bool, startMinutes: Int, endMinutes: Int, timeZone: String) {
//        Task {
//            let installId = await MainActor.run { InstallIdManager.installId }
//            let appVersion = await MainActor.run {
//                Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
//            }
//
//            let payload = Payload(
//                installId: installId,
//                isNotificationEnabled: isNotificationEnabled,
//                startMinutes: startMinutes,
//                endMinutes: endMinutes,
//                timeZone: timeZone,
//                platform: "iOS",
//                appVersion: appVersion,
//                sentAt: ISO8601DateFormatter().string(from: Date())
//            )
//
//            savePending(payload)
//            await flushWithRetry()
//        }
//    }
//
//    /// 앱 시작/복귀 시 재시도 트리거
//    func flushIfNeeded() {
//        Task { await flushWithRetry() }
//    }
//
//    private func flushWithRetry() async {
//        guard !isSending else { return }
//        isSending = true
//        defer { isSending = false }
//
//        guard let payload = loadPending() else { return }
//
//        let delays: [UInt64] = [1, 2, 4, 8, 16]
//        for (idx, sec) in delays.enumerated() {
//            do {
//                let ok = try await send(payload)
//                if ok {
//                    clearPending()
//                    return
//                }
//            } catch {
//                // 네트워크 오류 -> 재시도
//            }
//
//            if idx == delays.count - 1 { return }
//            let jitterMs = UInt64(Int.random(in: 0...300))
//            try? await Task.sleep(nanoseconds: sec * 1_000_000_000 + jitterMs * 1_000_000)
//        }
//    }
//
//    private func send(_ payload: Payload) async throws -> Bool {
//        var req = URLRequest(url: endpoint)
//        req.httpMethod = "POST"
//        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        req.timeoutInterval = 8
//        req.httpBody = try JSONEncoder().encode(payload)
//
//        let (data, resp) = try await URLSession.shared.data(for: req)
//        guard let http = resp as? HTTPURLResponse else { return false }
//        if (200...299).contains(http.statusCode) { return true }
//
//        _ = String(data: data, encoding: .utf8) // 디버그용
//        return false
//    }
//
//    private func savePending(_ payload: Payload) {
//        if let data = try? JSONEncoder().encode(payload) {
//            UserDefaults.standard.set(data, forKey: pendingKey)
//        }
//    }
//
//    private func loadPending() -> Payload? {
//        guard let data = UserDefaults.standard.data(forKey: pendingKey) else { return nil }
//        return try? JSONDecoder().decode(Payload.self, from: data)
//    }
//
//    private func clearPending() {
//        UserDefaults.standard.removeObject(forKey: pendingKey)
//    }
}
