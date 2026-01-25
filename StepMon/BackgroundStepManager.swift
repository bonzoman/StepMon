//
//  BackgroundStepManager.swift
//  StepMon
//  백그라운드 동작 관리자
//  - 백그라운드 작업을 등록하고, 실행하고, 스케줄링하는 핵심 클래스
//  - SwiftData 컨테이너를 직접 주입받아 백그라운드 스레드에서 데이터를 안전하게 읽습니다.
//  Created by 오승준 on 1/25/26.
//

import Foundation
import CoreMotion
import BackgroundTasks
import UserNotifications
import SwiftData

class BackgroundStepManager {
    static let shared = BackgroundStepManager()
    let taskId = "bnz.stepmon.stepcheck.refresh" // Info.plist와 일치 필수
    
    private let pedometer = CMPedometer()
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
        
        // --- [추가된 로직] 시간 체크 ---
        // 현재 시간이 설정된 범위 밖이라면 알림을 보내지 않고 종료
        if !isTimeInRange(start: pref.startTime, end: pref.endTime) {
            print("현재는 방해 금지 시간입니다. 알림을 건너뜁니다.")
            completion(true)
            return
        }
        // -------------------------
        
        let interval = Double(pref.checkIntervalMinutes * 60)
        let threshold = pref.stepThreshold
        let now = Date()
        let startDate = now.addingTimeInterval(-interval)
        
        if CMPedometer.isStepCountingAvailable() {
            pedometer.queryPedometerData(from: startDate, to: now) { [weak self] data, error in
                guard let data = data, error == nil else {
                    completion(false)
                    return
                }
                
                let steps = data.numberOfSteps.intValue
                if steps < threshold {
                    self?.sendNotification(steps: steps, threshold: threshold)
                }
                completion(true)
            }
        } else {
            completion(false)
        }
    }
    
    // --- [새로 만든 함수] 현재 시간이 범위 내인지 판별 ---
    private func isTimeInRange(start: Date, end: Date) -> Bool {
        let now = Date()
        let calendar = Calendar.current
        
        // 날짜는 무시하고 '시(Hour)'와 '분(Minute)'만 추출
        let nowComp = calendar.dateComponents([.hour, .minute], from: now)
        let startComp = calendar.dateComponents([.hour, .minute], from: start)
        let endComp = calendar.dateComponents([.hour, .minute], from: end)
        
        // 분 단위로 변환 (예: 1시 30분 -> 90분)
        let nowMinutes = (nowComp.hour! * 60) + nowComp.minute!
        let startMinutes = (startComp.hour! * 60) + startComp.minute!
        let endMinutes = (endComp.hour! * 60) + endComp.minute!
        
        if startMinutes <= endMinutes {
            // 예: 09:00 ~ 22:00 (낮 시간 동안만)
            return nowMinutes >= startMinutes && nowMinutes <= endMinutes
        } else {
            // 예: 22:00 ~ 07:00 (밤샘 설정인 경우 - 거의 없겠지만 예외처리)
            return nowMinutes >= startMinutes || nowMinutes <= endMinutes
        }
    }
    
    private func sendNotification(steps: Int, threshold: Int) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ 움직임 부족"
        content.body = "목표: \(threshold)보 / 현재: \(steps)보. 잠시 걸어보세요!"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil) // 즉시 발송
        center.add(request)
    }
}
