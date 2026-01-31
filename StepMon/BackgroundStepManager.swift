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
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        checkStepsAndNotify { success in
            task.setTaskCompleted(success: success)
            self.scheduleAppRefresh()
        }
    }
    
    private func checkStepsAndNotify(completion: @escaping (Bool) -> Void) {
        guard let container = modelContainer else {
            completion(false)
            return
        }
        
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<UserPreference>()
        
        guard let pref = try? context.fetch(descriptor).first else {
            completion(true)
            return
        }
        
        // [삭제됨] 여기서 시간을 체크해서 return 하던 로직을 제거했습니다.
        // 이제 시간과 관계없이 항상 데이터를 조회하고 저장합니다.
        
        let interval = Double(pref.checkIntervalMinutes * 60)
        let threshold = pref.stepThreshold
        let now = Date()
        let startDate = now.addingTimeInterval(-interval)
        
        print("🔍 CoreMotion: \(pref.checkIntervalMinutes)분 전부터 현재까지 걸음 수 조회 시작")
        
        CoreMotionManager.shared.querySteps(from: startDate, to: now) { steps in
            print("🚶 구간 측정값: \(steps) (목표: \(threshold))")
            
            // 1. 데이터 저장 (24시간 항상 실행됨)
            pref.bgCheckSteps = steps
            pref.bgCheckDate = now
            try? context.save()
            
            // 2. 알림 발송 조건 체크 (여기서 시간 체크!)
            // 걸음 수가 부족하고 + 설정된 알림 시간대일 경우에만 알림 발송
            if steps < threshold {
                if self.isTimeInRange(start: pref.startTime, end: pref.endTime) {
                    self.sendNotification(steps: steps, threshold: threshold)
                } else {
                    print("⚠️ 걸음 수 부족하지만 알림 금지 시간대라 조용히 넘어갑니다.")
                }
            }
            
            completion(true)
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
