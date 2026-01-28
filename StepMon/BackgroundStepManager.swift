//
//  BackgroundStepManager.swift
//  StepMon
//  백그라운드 동작 관리자
//  - 백그라운드 작업을 등록하고, 실행하고, 스케줄링하는 핵심 클래스
//  - SwiftData 컨테이너를 직접 주입받아 백그라운드 스레드에서 데이터를 안전하게 읽습니다.
//  Created by 오승준 on 1/25/26.
//

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
        
        // 알림 시간 체크 로직
        if !isTimeInRange(start: pref.startTime, end: pref.endTime) {
            print("알림 건너뜀.")
            completion(true)
            return
        }
        
        let interval = Double(pref.checkIntervalMinutes * 60)
        let threshold = pref.stepThreshold
        let now = Date()
        let startDate = now.addingTimeInterval(-interval)
        
        // [수정됨] HealthKitManager -> CoreMotionManager 사용
        print("🔍 CoreMotion: \(pref.checkIntervalMinutes)분 전부터 현재까지 걸음 수 조회 시작")
        CoreMotionManager.shared.querySteps(from: startDate, to: now) { steps in
            print("🚶 측정된 걸음 수: \(steps) / 목표: \(threshold)")
            if steps < threshold {
                self.sendNotification(steps: steps, threshold: threshold)
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
