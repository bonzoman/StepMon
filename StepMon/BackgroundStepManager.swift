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

    // submit "earliest 밀림" 방지용 가드 (15분)
    private let lastSubmitKey = "bnz.stepmon.lastSubmitDate"
    private let bgResubmitGuardSeconds: TimeInterval = 15 * 60
    
    
    private init() {}

    // MARK: - Register
    func registerBackgroundTask(container: ModelContainer) {
        self.modelContainer = container

        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskId, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            self.handleAppRefresh(task: task)
        }

        AppLog.write("✅ init() regBGAppRefreshTask", .green)
    }

    // MARK: - BG Task Handler
    private func handleAppRefresh(task: BGAppRefreshTask) {
        AppLog.write("🏁 Task 시작 ==========>", .blue)

        //pending count=0 확인용
//        BGTaskScheduler.shared.getPendingTaskRequests { requests in
//            let ids = requests.map { $0.identifier }.joined(separator: ",")
//            AppLog.write("📌 pending count=\(requests.count) ids=[\(ids)]")
//        }
        
        // 1. 다음 작업 예약 (작업 시작 시점에 미리 해두는 것이 연쇄 보장에 유리)
        // 앞서 논의한 것처럼 '이미 예약된 건이 있으면 skip' 로직이 포함된 함수여야 함
        let ok = self.submitRefreshRequest(path: "BG_RELAY")
        if ok {
            //UserDefaults.standard.set(Date(), forKey: self.lastBgSubmitKey)
        } else {
            AppLog.write("🟠 BG_RELAY submit failed → lastBgSubmitDate not updated")
        }
        
        let finishLock = NSLock()
        var finished = false

        func finish(_ success: Bool, reason: String) {
            finishLock.lock()
            defer { finishLock.unlock() }
            
            guard !finished else { return }
            finished = true
            
            AppLog.write("🏁 <========== Task 종료", .blue)
            task.setTaskCompleted(success: success)
        }

        // 2. 시스템 제공 만료 핸들러 (이것이 곧 Safety Timeout입니다)
        task.expirationHandler = {
            AppLog.write("⏰ 시스템 제공 타임아웃 발생 (Expiration)")
            // 만약 여기서 작업 중인 스레드를 강제 종료해야 한다면 관련 로직 추가
            finish(false, reason: "expired")
        }

        // 3. 실제 작업 실행
        checkStepsAndNotify(source: "bgTask") { success in
            // 작업이 완료되면 시스템 만료 핸들러가 호출되기 전에 먼저 종료
            finish(success, reason: "completed")
        }
    }
    

     
    /// 백그라운드
    func scheduleAppRefreshBackground(reason: String = "background") {

        // 1. 함수 시작 즉시 Background 시간을 확보.(중요)
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "StepMon_BG_Submit") {
            if bgTask != .invalid {
                AppLog.write("⏰ BGTask expired → endBackgroundTask")
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }

        // ✅ pending check
        BGTaskScheduler.shared.getPendingTaskRequests { requests in
            let isPending = requests.contains(where: { $0.identifier == self.taskId })
            
            
            // 이미 예약된 작업이 있으면 15분 가드를 적용
            if isPending {
                AppLog.write("🟠 pendingCnt=\(requests.count) 스킵")
                // 확보했던 백그라운드 권한을 반환하고 즉시 종료
                if bgTask != .invalid {
                    UIApplication.shared.endBackgroundTask(bgTask)
                }
                return
                
//                if let last = UserDefaults.standard.object(forKey: self.lastSubmitKey) as? Date {
//                    let delta = Date().timeIntervalSince(last)
//                    if delta < self.bgResubmitGuardSeconds { //15분
//                        // 이미 잘 예약되어 있고 시간도 얼마 안 됐으니 건드리지 않음 (Starvation 방지)
//                        AppLog.write("🟠 15분 skip: 기예약 (\(Int(delta))s/\(Int(self.bgResubmitGuardSeconds))s)")
//                        // ⚠️ 종료 시 반드시 확보한 시간을 풀어줘야 합니다.
//                        if bgTask != .invalid {
//                            UIApplication.shared.endBackgroundTask(bgTask)
//                        }
//                        return
//                    }
//                }
            }
            AppLog.write("🟠 pendingCnt=\(requests.count)")

            DispatchQueue.main.async {

                let ok = self.submitRefreshRequest(path: "BG")
                
                if ok {
                    //UserDefaults.standard.set(Date(), forKey: self.lastBgSubmitKey)
                } else {
                    AppLog.write("🟠 BG submit failed → lastBgSubmitDate not updated")
                }
                // 작업이 모두 끝났으니 Background 확보를 해제
                if bgTask != .invalid {
                    AppLog.write("✅ endBackgroundTask (cleanup)")
                    UIApplication.shared.endBackgroundTask(bgTask)
                    bgTask = .invalid
                }
            }
        }
    }







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

        AppLog.write("🔍 querySteps (\(readPref.checkIntervalMinutes)m) \nstart=\(formatLocal(startDate)) end=\(formatLocal(now))", .red)

        CoreMotionManager.shared.querySteps(from: startDate, to: now) { steps in
            // ✅ BG에서도 안정적으로: 콜백 안에서 바로 저장
            let writeContext = ModelContext(container)

            do {
                // pref 업데이트
                if let writePref = try writeContext.fetch(descriptor).first {
                    writePref.bgCheckSteps = steps
                    writePref.bgCheckDate = now
                }

                // [수정] 시간 범위 체크 제거: 알림이 켜져있으면 무조건 체크
                let shouldNotify = (steps < threshold) && isNotifEnabled

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

                if shouldNotify {
                    self.sendNotification(steps: steps, threshold: threshold)
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
        
        // 그 외(BG_RELAY 등 연쇄 호출)라면 15분 후로 설정
        if path == "BG" { //15분 기다렸지만 여전히 pending 상태라면..
//            request.earliestBeginDate = nil // nil로 설정하거나 Date()로 설정하면 "지금부터 즉시 실행 가능"을 의미합니다.
            request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        } else if path == "BG_RELAY" { //15분 후로 예약된 게 실행된거기때문에 다음 15분 후로 예약 submit
            request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        }
    
        do {
            try BGTaskScheduler.shared.submit(request)
            UserDefaults.standard.set(Date(), forKey: lastSubmitKey)

            if let earliest = request.earliestBeginDate {
                AppLog.write("✅✅✅✅✅✅✅✅✅✅\nsubmit [\(path)] \(formatLocal(earliest))", .red)
            } else {
                AppLog.write("✅✅✅✅✅✅✅✅✅✅\nsubmit [\(path)] earliest=nil", .red)
            }

//            BGTaskScheduler.shared.getPendingTaskRequests { reqs in
//                let ids = reqs.map { $0.identifier }.joined(separator: ",")
//                AppLog.write("📌 pending count=\(reqs.count) ids=[\(ids)]")
//            }

            return true
        } catch {
            AppLog.write("❌❌❌❌❌ submit failed [\(path)]: \(error)")
            return false
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
    
    // ✅ Silent Push(원격 알림)에서 호출할 공개 메서드
    func handleSilentPush(reason: String, completion: @escaping (Bool) -> Void) {
        AppLog.write("📩 SilentPush received reason=\(reason)", .red)

        // 내부 코어 로직 재사용
        checkStepsAndNotify(source: "silentPush") { ok in
            completion(ok)
        }
    }


}
