//
//  StepViewModel.swift
//  StepMon
//
//  Created by 오승준 on 1/25/26.
//

import SwiftUI
import WidgetKit
// HealthKit 제거

@Observable
class StepViewModel {
    var currentSteps: Int = 0
    
    func startUpdates() {
        // 오늘 자정부터 현재까지의 걸음 수 추적 시작
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        
        // 실시간 업데이트 시작
        CoreMotionManager.shared.startMonitoring(from: startOfDay) { [weak self] steps in
            DispatchQueue.main.async {
                self?.currentSteps = steps
                self?.updateWidget(steps: steps)
            }
        }
    }
    
    // 앱이 포그라운드로 돌아올 때 호출 (혹은 명시적 새로고침)
    func fetchTodaySteps() {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        
        CoreMotionManager.shared.querySteps(from: startOfDay, to: now) { [weak self] steps in
            DispatchQueue.main.async {
                self?.currentSteps = steps
                self?.updateWidget(steps: steps)
                
                // 쿼리 후에도 실시간 감지를 계속 유지하기 위해 재호출 가능
                self?.startUpdates()
            }
        }
    }
    
    private func updateWidget(steps: Int) {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.bnz.StepMon") {
            sharedDefaults.set(steps, forKey: "widgetSteps")
            sharedDefaults.synchronize()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    // 뷰모델이 해제될 때 센서 중지 (선택 사항)
    deinit {
        CoreMotionManager.shared.stopMonitoring()
    }
}
