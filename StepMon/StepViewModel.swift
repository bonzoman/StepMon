//
//  StepViewModel.swift
//  StepMon
//
//  Created by 오승준 on 1/25/26.
//

import SwiftUI
import WidgetKit
// HealthKit 제거

// @Observable은 SwiftUI에서 상태 변화를 자동으로 감지하게 해줍니다.
// Java에서의 Observable/Observer 패턴과 유사하지만, 언어/프레임워크 차원에서 간단하게 제공됩니다.
@Observable
class StepViewModel {
    // Swift의 기본 타입(Int)은 값 타입(value type)입니다.
    // Java의 int와 비슷하지만, Swift는 null이 없고 기본값을 직접 지정해야 합니다.
    var currentSteps: Int = 0
    
    func startUpdates() {
        // 오늘 자정부터 현재까지의 걸음 수 추적 시작
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        
        // 실시간 업데이트 시작
        // [weak self]는 클로저가 self를 약한 참조로 캡처하도록 합니다.
        // Java에서 익명 클래스/람다에서 외부 객체를 참조할 때 발생할 수 있는 메모리 누수를 방지하는 방식과 유사합니다.
        CoreMotionManager.shared.startMonitoring(from: startOfDay) { [weak self] steps in
            // UI 상태 업데이트는 메인 스레드에서 해야 합니다.
            // Java에서는 Handler/Looper를 통해 메인 스레드로 전환하는 것과 유사합니다.
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
            // UserDefaults는 iOS의 키-값 저장소입니다.
            // Java의 SharedPreferences와 거의 같은 개념입니다.
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
