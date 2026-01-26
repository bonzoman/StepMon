//
//  StepViewModel.swift
//  StepMon
//  실시간 걸음 수 표시
//  - 메인 화면에서 사용할 실시간 데이터용 클래스
//
//  Created by 오승준 on 1/25/26.
//

import SwiftUI
import WidgetKit // 위젯 갱신을 위해 필요

@Observable
class StepViewModel {
    var currentSteps: Int = 0
    
    func startUpdates() {
        // 1. 권한 요청 먼저 실행
        HealthKitManager.shared.requestAuthorization { success in
            if success {
                self.fetchTodaySteps()
            }
        }
    }
    
    func fetchTodaySteps() {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        
        HealthKitManager.shared.fetchStepCount(from: startOfDay, to: now) { steps in
            DispatchQueue.main.async {
                self.currentSteps = steps
                // 위젯과 공유하기 위해 UserDefaults(App Group)에 저장
                // "group.com.yourname.StepMon" 부분은 Capabilities에서 설정한 이름과 같아야 합니다.
                if let sharedDefaults = UserDefaults(suiteName: "group.com.bnz.StepMon") {
                    sharedDefaults.set(steps, forKey: "widgetSteps")
                    // 위젯 갱신 요청
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
        }
    }
}
