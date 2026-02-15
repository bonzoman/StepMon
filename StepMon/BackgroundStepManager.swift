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
import UIKit

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
    private let bgResubmitGuardSeconds: TimeInterval = 3 * 60

    // ✅ BG pending 조회 자체 과다 호출 방지 (1~2분 추천)
    private let lastBgCheckKey = "bnz.stepmon.lastBgCheckDate"
    private let bgCheckThrottleSeconds: TimeInterval = 90
    
    private let lastNotiSentKey = "bnz.stepmon.lastNotiSentDate"
    private let notiCooldownSeconds: TimeInterval = 15 * 60   // 15분동안 1번만 알림 받기위해

    // ✅ FG 즉시 체크 과다 호출 방지
    private let lastFgCheckKey = "bnz.stepmon.lastFgCheckDate"
    private let fgCheckCooldownSeconds: TimeInterval = 180

    // ✅ 중복 실행 방지
    private var isFgChecking = false
    
    private init() {}

    // MARK: - Register
    func registerBackgroundTask(container: ModelContainer) {
        self.modelContainer = container

        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskId, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            self.handleAppRefresh(task: task)
        }

        AppLog.write("✅ registerBackgroundTask done", .red)
    }

    // MARK: - BG Task Handler
    private func handleAppRefresh(task: BGAppRefreshTask) {
        AppLog.write("🚀 Task START", .red)

        let finishLock = NSLock()
        var finished = false

        @discardableResult
        func finish(_ success: Bool, reason: String) -> Bool {
            finishLock.lock()
            defer { finishLock.unlock() }

            if finished {
                AppLog.write("⚠️ finish called twice (reason=\(reason))")
                return false
            }

            finished = true
            AppLog.write("🏁 Task END success=\(success) reason=\(reason)")
            task.setTaskCompleted(success: success)
            return true
        }

        // ⏰ 1. 시스템 만료 핸들러
        task.expirationHandler = {
            AppLog.write("⏰ Task EXPIRED")
            _ = finish(false, reason: "expired")
        }

        // ⏱ 2. 안전 타임아웃 (25초)
        let safetyTimeout = DispatchWorkItem {
            AppLog.write("💥 Task SAFETY TIMEOUT")
            _ = finish(false, reason: "safety_timeout")
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 25, execute: safetyTimeout)

        // 🔎 3. 실제 작업
        checkStepsAndNotify(source: "bgTask") { success in
            safetyTimeout.cancel()

            if finish(success, reason: "completed") {
                //self.scheduleAppRefreshBackground(reason: "after_run")
                self.submitRefreshRequest(path: "FG")
            }
        }
    }
    
    
    
    // MARK: - Public Schedulers
    // 포그라운드에서 즉시 체크 (submit 하지 않음)
//    func runForegroundCheckIfNeeded(reason: String = "scene_active") {
//        // 쿨다운
//        if let last = UserDefaults.standard.object(forKey: lastFgCheckKey) as? Date {
//            let delta = Date().timeIntervalSince(last)
//            if delta < fgCheckCooldownSeconds {
//                AppLog.write("🟢 FG check cooldown \(Int(delta))s/\(Int(fgCheckCooldownSeconds))s")
//                return
//            }
//        }
//
//        // 중복 실행 방지
//        if isFgChecking {
//            AppLog.write("🟢 FG check skipped (already running)")
//            return
//        }
//
//        isFgChecking = true
//        UserDefaults.standard.set(Date(), forKey: lastFgCheckKey)
//
//        AppLog.write("🟢 FG CHECK START (\(reason))")
//
//        checkStepsAndNotify { success in
//            AppLog.write("🟢 FG CHECK END success=\(success)")
//            self.isFgChecking = false
//        }
//    }

    
    
    // 포그라운드
    func scheduleAppRefreshForeground(reason: String = "foreground") {
        AppLog.write("🟢🟢🟢 FG called (\(reason))", .green)
//        guard throttleOK() else {
//            AppLog.write("🟢 FG throttled")
//            return
//        }

        BGTaskScheduler.shared.getPendingTaskRequests { requests in
            let already = requests.contains(where: { $0.identifier == self.taskId })
            AppLog.write("🟢 FG pendingCount=\(requests.count) already=\(already)")

            if already { return }
            let ok = self.submitRefreshRequest(path: "FG")
            if !ok {
                AppLog.write("🟢 FG submit failed")
            }
        }
    }
     
    /* **************
    func scheduleAppRefreshBackground(reason: String = "background") {
        //AppLog.write("🟠 schedule BG called (\(reason))")
        AppLog.write("🟠 schedule BG called")

        // (0) ✅ BG pending 조회 호출 자체를 90초로 제한 (로그/배터리 절약)
        if let last = UserDefaults.standard.object(forKey: lastBgCheckKey) as? Date {
            let delta = Date().timeIntervalSince(last)
            if delta < bgCheckThrottleSeconds {
                AppLog.write("🟠 BG check throttled =\(Int(delta))s / \(Int(bgCheckThrottleSeconds))s")
                return
            }
        }
        UserDefaults.standard.set(Date(), forKey: lastBgCheckKey)

        // (1) 짧은 throttle(30초)
//        guard throttleOK() else {
//            AppLog.write("🟠 BG throttled(30s)")
//            return
//        }

        // (2) ✅ BG 전용 가드
        if let last = UserDefaults.standard.object(forKey: lastBgSubmitKey) as? Date {
            let delta = Date().timeIntervalSince(last)
            if delta < bgResubmitGuardSeconds {
                AppLog.write("🟠 BG guard skip delta=\(Int(delta))s")
                return
            }
        }

        // (3) ✅ 먼저 pending만 확인 (여기선 beginBackgroundTask 안 함)
        BGTaskScheduler.shared.getPendingTaskRequests { requests in
            let already = requests.contains(where: { $0.identifier == self.taskId })
            AppLog.write("🟠 BG pendingCount=\(requests.count) already=\(already)")

            if already {
                // ✅ pending이 있으면 submit도 안 하고, begin/endBackgroundTask도 안 함
                return
            }

            // (4) ✅ pending이 없을 때만 suspend 대비로 beginBackgroundTask 사용
            DispatchQueue.main.async {
                var bgTask: UIBackgroundTaskIdentifier = .invalid
                bgTask = UIApplication.shared.beginBackgroundTask(withName: "StepMon_BG_Submit") {
                    if bgTask != .invalid {
                        AppLog.write("⏰ BGTask expired → endBackgroundTask")
                        UIApplication.shared.endBackgroundTask(bgTask)
                        bgTask = .invalid
                    }
                }

                let ok = self.submitRefreshRequest(path: "BG")
                if ok {
                    UserDefaults.standard.set(Date(), forKey: self.lastBgSubmitKey)
                } else {
                    AppLog.write("🟠 BG submit failed → lastBgSubmitDate not updated")
                }

                if bgTask != .invalid {
                    AppLog.write("✅ endBackgroundTask (cleanup)")
                    UIApplication.shared.endBackgroundTask(bgTask)
                    bgTask = .invalid
                }
            }
        }
    }
    ******************* */







    // MARK: - Core Logic

    private func checkStepsAndNotify(source: String, completion: @escaping (Bool) -> Void) {
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

        AppLog.write("🔍 querySteps (\(readPref.checkIntervalMinutes)m) start=\(formatLocal(startDate)) end=\(formatLocal(now))", .red)

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
                    intervalMinutes: readPref.checkIntervalMinutes,
                    source: source
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
                AppLog.write("history saved steps=\(steps) noti=\(shouldNotify)", .red)

                //알림 조건에 충족하더라도 15분동안 1번만 알림 보낸다!
                if shouldNotify {
//                    if self.notificationCooldownOK(now: now) {
                        self.sendNotification(steps: steps, threshold: threshold)
                        UserDefaults.standard.set(now, forKey: self.lastNotiSentKey)
//                    } else {
//                        AppLog.write("⛔️ notification skipped (cooldown)")
//                    }
                }

                completion(true)
            } catch {
                AppLog.write("❌ save failed: \(error)", .red)
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
                AppLog.write("❌ notification add error: \(error)", .red)
            } else {
                AppLog.write("✅✅ noti posted ✅✅", .red)
            }
        }
    }

    // MARK: - Submit Helper

    @discardableResult
    private func submitRefreshRequest(path: String) -> Bool {
        let request = BGAppRefreshTaskRequest(identifier: taskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            UserDefaults.standard.set(Date(), forKey: lastSubmitKey)

            if let earliest = request.earliestBeginDate {
                AppLog.write("✅ submit success [\(path)] earliest=\(formatLocal(earliest))", .red)
            } else {
                AppLog.write("✅ submit success [\(path)] earliest=nil", .red)
            }

//            BGTaskScheduler.shared.getPendingTaskRequests { reqs in
//                let ids = reqs.map { $0.identifier }.joined(separator: ",")
//                AppLog.write("📌 pending count=\(reqs.count) ids=[\(ids)]")
//            }

            return true
        } catch {
            AppLog.write("❌ submit failed [\(path)]: \(error)")
            return false
        }
    }


//    private func throttleOK() -> Bool {
//        if let last = UserDefaults.standard.object(forKey: lastSubmitKey) as? Date {
//            let delta = Date().timeIntervalSince(last)
//            return delta >= submitThrottleSeconds
//        }
//        return true
//    }

    private func formatLocal(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd HH:mm:ss"
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = .current
        return f.string(from: date)
    }

    private func notificationCooldownOK(now: Date) -> Bool {
        if let last = UserDefaults.standard.object(forKey: lastNotiSentKey) as? Date {
            let delta = now.timeIntervalSince(last)
            return delta >= notiCooldownSeconds
        }
        return true
    }
    
    // ✅ Silent Push(원격 알림)에서 호출할 공개 메서드
    func handleSilentPush(reason: String, completion: @escaping (Bool) -> Void) {
        AppLog.write("📩 SilentPush received reason=\(reason)", .red)

        // 내부 코어 로직 재사용
        checkStepsAndNotify(source: "silentPush") { ok in
            completion(ok)
        }
    }


}
