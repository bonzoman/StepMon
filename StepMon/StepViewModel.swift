//
//  StepViewModel.swift
//  StepMon
//  실시간 걸음 수 표시
//  - 메인 화면에서 사용할 실시간 데이터용 클래스
//
//  Created by 오승준 on 1/25/26.
//

import SwiftUI
import CoreMotion

@Observable
class StepViewModel {
    var currentSteps: Int = 0
    private let pedometer = CMPedometer()
    
    func startUpdates() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        
        let midnight = Calendar.current.startOfDay(for: Date())
        pedometer.startUpdates(from: midnight) { data, error in
            guard let data = data, error == nil else { return }
            DispatchQueue.main.async {
                self.currentSteps = data.numberOfSteps.intValue
            }
        }
    }
}
