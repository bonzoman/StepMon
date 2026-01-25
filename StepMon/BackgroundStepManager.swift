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
    let taskId = "bnz.stepmon.stepcheck.refresh" // Info.plist와 일치해야 함
    
    private let pedometer = CMPedometer()
    private let center = UNUserNotificationCenter.current()
    
    // 백그라운드에서 SwiftData 접근을 위한 컨테이너 저장
    var modelContainer: ModelContainer?
    
    private init() {}
    
    // 1. 앱 시작 시 호출: 백그라운드 작업 등록
    func registerBackgroundTask(container: ModelContainer) {
        self.modelContainer = container
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskId, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            self.handleAppRefresh(task: task)
        }
    }
    
    // 2. 앱이 백그라운드로 갈 때 호출: 다음 작업 스케줄링
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 최소 15분 후 실행 요청 (시스템 제약)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("백그라운드 작업 스케줄링 성공")
        } catch {
            print("스케줄링 실패: \(error)")
        }
    }
    
    // 3. 실제 백그라운드에서 실행되는 로직
    private func handleAppRefresh(task: BGAppRefreshTask) {
        // 작업이 너무 오래 걸리면 시스템이 강제 종료하므로 만료 핸들러 설정
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        checkStepsAndNotify { success in
            task.setTaskCompleted(success: success)
            // 다음 작업 예약 (반복 실행을 위해)
            self.scheduleAppRefresh()
        }
    }
    
    // 4. 걸음 수 체크 및 알림 로직
    private func checkStepsAndNotify(completion: @escaping (Bool) -> Void) {
        guard let container = modelContainer else {
            completion(false)
            return
        }
        
        // 백그라운드 컨텍스트 생성
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<UserPreference>()
        
        guard let pref = try? context.fetch(descriptor).first else {
            completion(true) // 설정 없으면 그냥 종료
            return
        }
        
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
                print("백그라운드 체크: 지난 \(pref.checkIntervalMinutes)분간 \(steps)걸음")
                
                if steps < threshold {
                    self?.sendNotification(steps: steps, threshold: threshold)
                }
                
                completion(true)
            }
        } else {
            completion(false)
        }
    }
    
    private func sendNotification(steps: Int, threshold: Int) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ 움직임 부족 알림"
        content.body = "목표: \(threshold)보 / 현재: \(steps)보. 잠시 일어나서 걸어보세요!"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil) // 즉시 발송
        center.add(request)
    }
}
