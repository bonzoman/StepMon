//
//  StepViewModel.swift
//  StepMon
//
//  Created by 오승준 on 1/25/26.
//

import SwiftUI
import WidgetKit

@Observable
class StepViewModel {
    var currentSteps: Int = 0
    
    // 메모리 보호: 마지막으로 위젯을 업데이트한 걸음 수
    private var lastSavedSteps: Int = 0
    
    // 뷰모델이 메모리에서 해제될 때 센서 모니터링 중지
    deinit {
        CoreMotionManager.shared.stopMonitoring()
        print("🛑 StepViewModel 해제: 센서 모니터링 중지")
    }
    
    func startUpdates() {
        
        CoreMotionManager.shared.stopMonitoring() // ✅ 중복 모니터링 방지

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        
        // 실시간 업데이트 시작
        CoreMotionManager.shared.startMonitoring(from: startOfDay) { [weak self] steps in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // 1. UI용 변수 업데이트 (실시간)
                self.currentSteps = steps
                
                // 2. 무거운 작업(위젯/저장)은 50보 단위로 스로틀링 (메모리 폭주 방지)
                if abs(steps - self.lastSavedSteps) >= 50 {
                    self.updateWidget(steps: steps)
                    self.lastSavedSteps = steps
                    print("💾 위젯 데이터 저장 및 갱신 (걸음수: \(steps))")
                }
            }
        }
    }
    
    func fetchTodaySteps() {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        
        CoreMotionManager.shared.querySteps(from: startOfDay, to: now) { [weak self] steps in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.currentSteps = steps
                // 앱 진입 시에는 즉시 한 번 위젯 갱신
                self.updateWidget(steps: steps)
                self.lastSavedSteps = steps
                
                // 실시간 감지 시작
                self.startUpdates()
            }
        }
    }
    
    private func updateWidget(steps: Int) {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.bnz.stepmon") {
            sharedDefaults.set(steps, forKey: "widgetSteps")
            // WidgetCenter 호출은 시스템 자원을 많이 소모하므로 꼭 필요한 때만 실행
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
