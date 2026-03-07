//
//  CoreMotionManager.swift
//  StepMon
//  CoreMotion(CMPedometer) 연동 담당
//  - 아이폰의 모션 프로세서를 통해 직접 걸음 수를 가져옵니다.
//
//  Created by 오승준 on 1/27/26.
//

import Foundation
import CoreMotion
import SwiftUI

struct DailyStep: Identifiable {
    let id = UUID()
    let date: Date
    let steps: Int
}

class CoreMotionManager {
    static let shared = CoreMotionManager()
    private let pedometer = CMPedometer()
    
    private init() {}
    
    // 1. 권한 확인 및 가용성 체크
    func checkAvailability() -> Bool {
        return CMPedometer.isStepCountingAvailable()
    }
    
    // 2. 특정 기간(과거~현재)의 걸음 수 조회 (백그라운드 작업용)
    func querySteps(from start: Date, to end: Date, completion: @escaping (Int) -> Void) {
        guard checkAvailability() else {
            print("❌ 기기에서 걸음 수 측정을 지원하지 않습니다.")
            completion(0)
            return
        }
        
        pedometer.queryPedometerData(from: start, to: end) { data, error in
            if let error = error {
                print("CoreMotion 쿼리 에러: \(error.localizedDescription)")
                completion(0)
                return
            }
            
            let steps = data?.numberOfSteps.intValue ?? 0
            completion(steps)
        }
    }
    
    // 3. 실시간 걸음 수 업데이트 (UI용)
    func startMonitoring(from start: Date, updateHandler: @escaping (Int) -> Void) {
        guard checkAvailability() else { return }
        
        pedometer.startUpdates(from: start) { data, error in
            guard let data = data, error == nil else { return }
            
            let steps = data.numberOfSteps.intValue
            updateHandler(steps)
        }
    }
    
    // 모니터링 중지
    func stopMonitoring() {
        pedometer.stopUpdates()
    }
    
    // 4. 최근 N일간의 일별 걸음수 조회 (Swift Concurrency 사용)
    func queryDailySteps(days: Int) async -> [DailyStep] {
        let calendar = Calendar.current
        let now = Date()
        var results: [DailyStep] = []
        
        for i in 0..<days {
            guard let targetDate = calendar.date(byAdding: .day, value: -i, to: now) else { continue }
            let start = calendar.startOfDay(for: targetDate)
            let end: Date
            
            if i == 0 {
                end = now
            } else {
                end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: targetDate) ?? targetDate
            }
            
            let steps = await withCheckedContinuation { continuation in
                querySteps(from: start, to: end) { steps in
                    continuation.resume(returning: steps)
                }
            }
            results.append(DailyStep(date: start, steps: steps))
        }
        
        return results.reversed()
    }
}

