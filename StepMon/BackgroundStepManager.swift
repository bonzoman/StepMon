import Foundation
import BackgroundTasks
import UserNotifications
import SwiftData
import CoreMotion

class BackgroundStepManager {
    static let shared = BackgroundStepManager()
    let taskId = "bnz.stepmon.stepcheck.refresh"
    private let lastScheduledKey = "bnz.stepmon.lastScheduledDate" // 예약 시간 저장용 키
    
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
    
    // [수정] 중복 예약 방지 로직이 추가된 스케줄링 함수
    func scheduleAppRefresh(force: Bool = false) {
        // 1. 이미 예약된 시간이 미래에 있다면 건너뜀 (밀림 방지)
        if !force {
            if let lastDate = UserDefaults.standard.object(forKey: lastScheduledKey) as? Date,
               lastDate > Date() {
                print("⏳ 이미 예약된 작업이 있습니다: \(lastDate.formatted(date: .omitted, time: .shortened))")
                return
            }
        }
        
        let nextDate = Date(timeIntervalSinceNow: 15 * 60)
        let request = BGAppRefreshTaskRequest(identifier: taskId)
        // [유지] 체크는 15분마다 최대한 자주 수행
        request.earliestBeginDate = nextDate
        
        do {
            try BGTaskScheduler.shared.submit(request)
            // 2. 예약 성공 시 해당 시간을 저장
            UserDefaults.standard.set(nextDate, forKey: lastScheduledKey)
            print("✅ 차기 체크 예약 완료: \(nextDate.formatted(date: .omitted, time: .shortened))")
        } catch {
            print("❌ 스케줄링 실패: \(error)")
        }
    }
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        checkStepsAndNotify { success in
            task.setTaskCompleted(success: success)
            // 성공/실패 여부와 관계없이 다음 스케줄링 등록
            // [수정] 백그라운드 작업 완료 후에는 'force: true'로 무조건 다음 릴레이 예약
            self.scheduleAppRefresh(force: true)
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
