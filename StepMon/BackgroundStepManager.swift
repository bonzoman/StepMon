import Foundation
import BackgroundTasks
import UserNotifications
import SwiftData
import CoreMotion

class BackgroundStepManager {
    static let shared = BackgroundStepManager()
    let taskId = "bnz.stepmon.stepcheck.refresh"
    private let lastSubmitKey = "bnz.stepmon.bg.lastSubmitDate"
    private let submitThrottleSeconds: TimeInterval = 5 * 60
    
    private let center = UNUserNotificationCenter.current()
    var modelContainer: ModelContainer?
    
    private init() {}
    
    func registerBackgroundTask(container: ModelContainer) {
        self.modelContainer = container
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskId, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            self.handleAppRefresh(task: task)
        }
    }
    
    
    // [수정] getTaskRequests를 사용하는 스케줄링 함수
    func scheduleAppRefresh(force: Bool = false) {
        // submit()을 너무 자주 호출하면 오히려 실행 기회가 줄거나 에러가 날 수 있어서 throttling 처리
        if !force, let last = UserDefaults.standard.object(forKey: lastSubmitKey) as? Date {
            let delta = Date().timeIntervalSince(last)
            if delta < submitThrottleSeconds {
                let remain = Int((submitThrottleSeconds - delta).rounded(.up))
                print("⏳ submit throttle: \(remain)s 후 재시도 권장")
                return
            }
        }

        // 비동기적으로 현재 대기 중인 작업 목록을 가져옴
        BGTaskScheduler.shared.getPendingTaskRequests { [weak self] (requests: [BGTaskRequest]) in
            guard let self = self else { return }

            // 1) 이미 pending 상태라면(그리고 force가 아니라면) 재등록하지 않음
            let pending = requests.first(where: { $0.identifier == self.taskId })
            if pending != nil && !force {
                let scheduledTime = pending?.earliestBeginDate?.formatted(date: .omitted, time: .shortened) ?? "알 수 없음"
                print("⏳ 이미 예약된 작업이 대기 중입니다. (예정: \(scheduledTime))")
                return
            }

            // 2) 예약 진행
            let nextDate = Date(timeIntervalSinceNow: 15 * 60) // 15분 뒤(최소 실행 가능 시점)
            let request = BGAppRefreshTaskRequest(identifier: self.taskId)
            request.earliestBeginDate = nextDate

            do {
                try BGTaskScheduler.shared.submit(request)
                UserDefaults.standard.set(Date(), forKey: self.lastSubmitKey)
                print("✅ 차기 체크 예약 완료: \(nextDate.formatted(date: .omitted, time: .shortened))")
            } catch {
                print("❌ 스케줄링 실패: \(error)")
            }
        }
    }

    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        var didComplete = false

        func completeOnce(success: Bool) {
            guard !didComplete else { return }
            didComplete = true
            task.setTaskCompleted(success: success)
            // 작업 종료 후 다음 작업 예약 (과도한 force/cancel 대신 throttle + pending 체크로 관리)
            self.scheduleAppRefresh()
        }

        task.expirationHandler = {
            // 시스템이 시간을 더 못 주는 상황: 여기서 1회만 완료 처리
            completeOnce(success: false)
        }

        checkStepsAndNotify { success in
            completeOnce(success: success)
        }
    }

    
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
        
        // 집계 범위(startDate) 계산
        let interval = Double(readPref.checkIntervalMinutes * 60)
        let threshold = readPref.stepThreshold
        let startTime = readPref.startTime
        let endTime = readPref.endTime
        let now = Date()
        let startDate = now.addingTimeInterval(-interval)
        let isNotifEnabled = readPref.isNotificationEnabled // 알림 활성화 여부 읽기
        
        print("🔍 CoreMotion: 조회 시작 (\(startDate.formatted(date: .omitted, time: .shortened)) ~ \(now.formatted(date: .omitted, time: .shortened)))")
        
        CoreMotionManager.shared.querySteps(from: startDate, to: now) { steps in
            Task { @MainActor in
                let writeContext = ModelContext(container)
                if let writePref = try? writeContext.fetch(descriptor).first {
                    
                    writePref.bgCheckSteps = steps
                    writePref.bgCheckDate = now
                    
                    let isTimeValid = self.isTimeInRange(start: startTime, end: endTime)
                    let shouldNotify = steps < threshold && isTimeValid && isNotifEnabled
                    
                    // 히스토리 기록
                    let history = NotificationHistory(
                        timestamp: now,
                        steps: steps,
                        threshold: threshold,
                        isNotified: shouldNotify,
                        intervalMinutes: readPref.checkIntervalMinutes // [수정] 현재 설정값을 기록에 고정
                    )
                    writeContext.insert(history)
                    
                    // 30개 유지 Pruning
                    let historyFetch = FetchDescriptor<NotificationHistory>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
                    if let allHistory = try? writeContext.fetch(historyFetch), allHistory.count > 30 {
                        for i in 30..<allHistory.count {
                            writeContext.delete(allHistory[i])
                        }
                    }
                    
                    do {
                        try writeContext.save()
                        print("✅ DB 저장 및 히스토리 기록 성공: \(steps)보")
                    } catch {
                        print("❌ DB 저장 실패: \(error)")
                    }
                    
                    if shouldNotify {
                        self.sendNotification(steps: steps, threshold: threshold)
                    }
                }
                completion(true)
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
        content.title = String(localized: "⚠️ 움직임 부족")
        content.body = String(localized:"최근: \(steps)보. 걷고 💧생명수를 채워주세요!")
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }
}
