//
//  BackgroundStepManager.swift
//  StepMon
//
//  - Foreground: pending 체크 후 submit
//  - Background: pending 체크 없이 즉시 submit (suspend로 submit 누락 방지)
//  - BG는 "earliest 리셋(밀림)" 방지 위해 별도 가드(12분) 적용
//  - AppLog로 파일 로그 저장
//

import Foundation
import BackgroundTasks
import UserNotifications
import SwiftData
import CoreMotion

final class BackgroundStepManager {
    static let shared = BackgroundStepManager()
    let taskId = "bnz.stepmon.stepcheck.refresh"

    private let center = UNUserNotificationCenter.current()
    private(set) var modelContainer: ModelContainer?

    // FG submit 과다 호출 방지용
    private let lastSubmitKey = "bnz.stepmon.lastSubmitDate"
    private let submitThrottleSeconds: TimeInterval = 30

    // ✅ BG submit "earliest 밀림" 방지용 가드 (추천: 10~15분)
    private let lastBgSubmitKey = "bnz.stepmon.lastBgSubmitDate"
    private let bgResubmitGuardSeconds: TimeInterval = 12 * 60

    private init() {}

    // MARK: - Register

    func registerBackgroundTask(container: ModelContainer) {
        self.modelContainer = container

        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskId, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            self.handleAppRefresh(task: task)
        }

        AppLog.write("✅ registerBackgroundTask done")
    }

    // MARK: - Public Schedulers

    /// 포그라운드: pending 체크 후 submit
    func scheduleAppRefreshForeground(reason: String = "foreground") {
        AppLog.write("🟢 schedule FG called (\(reason))")
        guard throttleOK() else {
            AppLog.write("🟢 FG throttled")
            return
        }

        BGTaskScheduler.shared.getPendingTaskRequests { requests in
            let already = requests.contains(where: { $0.identifier == self.taskId })
            AppLog.write("🟢 FG pendingCount=\(requests.count) already=\(already)")

            if already { return }
            self.submitRefreshRequest(path: "FG")
        }
    }

    /// 백그라운드: pending 체크 없이 즉시 submit
    /// ✅ 단, BG는 자주 submit하면 earliest가 계속 리셋될 수 있으니 별도 가드 적용
    func scheduleAppRefreshBackground(reason: String = "background") {
        AppLog.write("🟠 schedule BG called (\(reason))")

        // (1) 짧은 throttle(30초)도 유지해도 되지만, 핵심은 아래 BG 가드임
        guard throttleOK() else {
            AppLog.write("🟠 BG throttled(30s)")
            return
        }

        // (2) ✅ BG 전용 가드: 마지막 BG submit 후 12분 이내면 submit 스킵
        if let last = UserDefaults.standard.object(forKey: lastBgSubmitKey) as? Date {
            let delta = Date().timeIntervalSince(last)
            if delta < bgResubmitGuardSeconds {
                AppLog.write("🟠 BG guard skip delta=\(Int(delta))s")
                return
            }
        }

        submitRefreshRequest(path: "BG")
        UserDefaults.standard.set(Date(), forKey: lastBgSubmitKey)
    }

    // MARK: - BG Task Handler

    private func handleAppRefresh(task: BGAppRefreshTask) {
        AppLog.write("🚀 BG START")

        task.expirationHandler = {
            AppLog.write("⏰ BG EXPIRED")
            task.setTaskCompleted(success: false)
        }

        checkStepsAndNotify { success in
            AppLog.write("🏁 BG END success=\(success)")
            task.setTaskCompleted(success: success)

            // 다음 예약은 “백그라운드 방식”으로(가드가 있으니 earliest 밀림 방지됨)
            self.scheduleAppRefreshBackground(reason: "after_run")
        }
    }

    // MARK: - Core Logic

    private func checkStepsAndNotify(completion: @escaping (Bool) -> Void) {
        guard let container = modelContainer else {
            completion(false)
            return
        }

        let readContext = ModelContext(container)
        let descriptor = FetchDescriptor<UserPreference>()
        guard let readPref = try? readContext.fetch(descriptor).first else {
            completion(true)
            return
        }

        let interval = Double(readPref.checkIntervalMinutes * 60)
        let threshold = readPref.stepThreshold
        let startTime = readPref.startTime
        let endTime = readPref.endTime
        let isNotifEnabled = readPref.isNotificationEnabled

        let now = Date()
        let startDate = now.addingTimeInterval(-interval)

        AppLog.write("🔍 querySteps (\(readPref.checkIntervalMinutes)m) start=\(startDate) end=\(now)")

        CoreMotionManager.shared.querySteps(from: startDate, to: now) { steps in
            // ✅ BG에서도 안정적으로: 콜백 안에서 바로 저장
            let writeContext = ModelContext(container)

            do {
                // pref 업데이트
                if let writePref = try writeContext.fetch(descriptor).first {
                    writePref.bgCheckSteps = steps
                    writePref.bgCheckDate = now
                }

                let isTimeValid = self.isTimeInRange(start: startTime, end: endTime)
                let shouldNotify = (steps < threshold) && isTimeValid && isNotifEnabled

                // ✅ 히스토리 무조건 기록
                let history = NotificationHistory(
                    timestamp: now,
                    steps: steps,
                    threshold: threshold,
                    isNotified: shouldNotify,
                    intervalMinutes: readPref.checkIntervalMinutes
                )
                writeContext.insert(history)

                // 30개 유지
                let historyFetch = FetchDescriptor<NotificationHistory>(
                    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                )
                let all = try writeContext.fetch(historyFetch)
                if all.count > 30 {
                    for i in 30..<all.count { writeContext.delete(all[i]) }
                }

                try writeContext.save()
                AppLog.write("✅ history saved steps=\(steps) notified=\(shouldNotify)")

                if shouldNotify {
                    self.sendNotification(steps: steps, threshold: threshold)
                }

                completion(true)
            } catch {
                AppLog.write("❌ save failed: \(error)")
                completion(false)
            }
        }
    }

    

    private func isTimeInRange(start: Date, end: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()

        let nowMin = (calendar.component(.hour, from: now) * 60) + calendar.component(.minute, from: now)
        let startMin = (calendar.component(.hour, from: start) * 60) + calendar.component(.minute, from: start)
        let endMin = (calendar.component(.hour, from: end) * 60) + calendar.component(.minute, from: end)

        if startMin <= endMin {
            return nowMin >= startMin && nowMin <= endMin
        } else {
            return nowMin >= startMin || nowMin <= endMin
        }
    }

    private func sendNotification(steps: Int, threshold: Int) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ 움직임 부족"
        content.body = "목표: \(threshold)보 / 현재: \(steps)보. 잠시 걸어보세요!"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                AppLog.write("❌ notification add error: \(error)")
            } else {
                AppLog.write("✅ notification posted")
            }
        }
    }

    // MARK: - Submit Helper

    private func submitRefreshRequest(path: String) {
        let request = BGAppRefreshTaskRequest(identifier: taskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            UserDefaults.standard.set(Date(), forKey: lastSubmitKey)

            // ✅ earliest 로컬 포맷으로 출력(UTC 헷갈림 방지)
            if let earliest = request.earliestBeginDate {
                AppLog.write("✅ submit success [\(path)] earliest=\(formatLocal(earliest))")
            } else {
                AppLog.write("✅ submit success [\(path)] earliest=nil")
            }
        } catch {
            AppLog.write("❌ submit failed [\(path)]: \(error)")
        }

        BGTaskScheduler.shared.getPendingTaskRequests { reqs in
            let ids = reqs.map { $0.identifier }.joined(separator: ",")
            AppLog.write("📌 pending count=\(reqs.count) ids=[\(ids)]")
        }
    }

    private func throttleOK() -> Bool {
        if let last = UserDefaults.standard.object(forKey: lastSubmitKey) as? Date {
            let delta = Date().timeIntervalSince(last)
            return delta >= submitThrottleSeconds
        }
        return true
    }

    private func formatLocal(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yy.MM.dd HH:mm:ss"
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = .current
        return f.string(from: date)
    }
}
