import Foundation
import BackgroundTasks
import UserNotifications
import SwiftData
import CoreMotion

class BackgroundStepManager {
    static let shared = BackgroundStepManager()
    let taskId = "bnz.stepmon.stepcheck.refresh"
    
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
    
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("백그라운드 스케줄링 완료")
        } catch {
            print("스케줄링 실패: \(error)")
        }
    }
    
    // [수정된 함수 1]
    private func handleAppRefresh(task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        checkStepsAndNotify { success in
            task.setTaskCompleted(success: success)
            // 성공/실패 여부와 관계없이 다음 스케줄링 등록
            self.scheduleAppRefresh()
        }
    }
    
    // [수정된 함수 2] - 히스토리 저장 및 100개 유지 로직 통합
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
        let now = Date()
        let startDate = now.addingTimeInterval(-interval)
        
        print("🔍 CoreMotion: 조회 시작 (\(startDate.formatted(date: .omitted, time: .shortened)) ~ \(now.formatted(date: .omitted, time: .shortened)))")
        
        CoreMotionManager.shared.querySteps(from: startDate, to: now) { steps in
            print("🚶 측정된 걸음 수: \(steps)")
            
            Task { @MainActor in
                let writeContext = ModelContext(container)
                if let writePref = try? writeContext.fetch(descriptor).first {
                    
                    // 1. 기본 백그라운드 데이터 업데이트
                    writePref.bgCheckSteps = steps
                    writePref.bgCheckDate = now
                    
                    // 2. 히스토리 기록 (NotificationHistory 모델 활용)
                    let isTimeValid = self.isTimeInRange(start: startTime, end: endTime)
                    let shouldNotify = steps < threshold && isTimeValid
                    
                    let history = NotificationHistory(
                        timestamp: now,
                        steps: steps,
                        threshold: threshold,
                        isNotified: shouldNotify
                    )
                    writeContext.insert(history)
                    
                    // 3. 최신 100개 유지 로직 (Pruning)
                    let historyFetch = FetchDescriptor<NotificationHistory>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
                    if let allHistory = try? writeContext.fetch(historyFetch), allHistory.count > 100 {
                        for i in 100..<allHistory.count {
                            writeContext.delete(allHistory[i])
                        }
                    }
                    
                    // 4. DB 저장 시도
                    do {
                        try writeContext.save()
                        print("✅ DB 저장 및 히스토리 기록 성공: \(steps)보")
                    } catch {
                        print("❌ DB 저장 실패: \(error)")
                    }
                    
                    // 5. 실제 알림 발송
                    if shouldNotify {
                        self.sendNotification(steps: steps, threshold: threshold)
                    } else if steps < threshold && !isTimeValid {
                        print("⚠️ 알림 조건은 충족하나 알림 금지 시간대임")
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
        content.title = "⚠️ 움직임 부족"
        content.body = "목표: \(threshold)보 / 현재: \(steps)보. 잠시 걸어보세요!"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }
}
