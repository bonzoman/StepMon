import Foundation

actor DeviceTokenUploader {
    static let shared = DeviceTokenUploader()

    // ✅ 너 서버 주소로 바꾸기
    private let endpoint = URL(string: "http://192.168.0.205:8888/api/device/register")!

    private let pendingKey = "bnz.stepmon.pendingDeviceReg"
    private let lastSentTokenKey = "bnz.stepmon.lastSentDeviceToken"

    private var isSending = false

    struct Payload: Codable {
        let installId: String
        let deviceToken: String
        let isNotificationEnabled: Bool
        let platform: String      // "iOS"
        let appVersion: String
        let sentAt: String        // ISO8601
    }

    // 앱에서 호출: 토큰/알림설정이 바뀌면 여기로
    func upsert(deviceToken: String, isNotificationEnabled: Bool) {
        Task {
            let installId = await MainActor.run { InstallIdManager.installId }
            let appVersion = await MainActor.run {
                Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
            }

            let payload = Payload(
                installId: installId,
                deviceToken: deviceToken,
                isNotificationEnabled: isNotificationEnabled,
                platform: "iOS",
                appVersion: appVersion,
                sentAt: ISO8601DateFormatter().string(from: Date())
            )

            savePending(payload)
            await flushWithRetry()
        }
    }


    // 앱 시작/포그라운드 복귀 등 “재시도 트리거” 용
    func flushIfNeeded() {
        Task { await flushWithRetry() }
    }

    private func flushWithRetry() async {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }

        guard let payload = loadPending() else { return }

        // ✅ 이미 같은 토큰을 성공 전송한 기록이면(중복 업로드 방지) 종료
        if let last = UserDefaults.standard.string(forKey: lastSentTokenKey),
           last == payload.deviceToken {
            // 단, 알림 on/off 같은 상태 변경도 같이 보내고 싶으면 여기 조건을 더 세분화하면 됨
            clearPending()
            return
        }

        // ✅ 재시도: 1s, 2s, 4s, 8s, 16s (최대 5회) + 약간의 랜덤 지터
        let delays: [UInt64] = [1, 2, 4, 8, 16].map { UInt64($0) }

        for (idx, sec) in delays.enumerated() {
            do {
                let ok = try await send(payload)
                if ok {
                    UserDefaults.standard.set(payload.deviceToken, forKey: lastSentTokenKey)
                    clearPending()
                    return
                }
            } catch {
                // 네트워크/타임아웃 등: 아래 재시도로 넘어감
            }

            // 마지막 시도면 종료(펜딩은 남아있어서 다음 기회에 다시 flush 됨)
            if idx == delays.count - 1 { return }

            let jitterMs = UInt64(Int.random(in: 0...300)) // 0~300ms
            try? await Task.sleep(nanoseconds: sec * 1_000_000_000 + jitterMs * 1_000_000)
        }
    }

    private func send(_ payload: Payload) async throws -> Bool {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 8

        req.httpBody = try JSONEncoder().encode(payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { return false }

        // ✅ 200~299 성공
        if (200...299).contains(http.statusCode) { return true }

        // ✅ 4xx는 보통 요청 문제(서버 규약 불일치) 가능성 큼
        //    여기서는 false로 처리해서 펜딩 유지(원인 고치면 다음에 다시 성공하도록)
        //    디버깅 필요하면 data를 로그로 찍어도 됨(운영에선 개인정보 로그 주의)
        _ = String(data: data, encoding: .utf8)
        return false
    }

    private func savePending(_ payload: Payload) {
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: pendingKey)
        }
    }

    private func loadPending() -> Payload? {
        guard let data = UserDefaults.standard.data(forKey: pendingKey) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }

    private func clearPending() {
        UserDefaults.standard.removeObject(forKey: pendingKey)
    }
}
