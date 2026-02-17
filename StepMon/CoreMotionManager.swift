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

class CoreMotionManager {
    static let shared = CoreMotionManager()
    private let pedometer = CMPedometer()
    
    private init() {}
    
    // 1. 권한 확인 및 가용성 체크
    func checkAvailability() -> Bool {
        return CMPedometer.isStepCountingAvailable()
    }
    
    // 2. 특정 기간(과거~현재)의 걸음 수 조회 (백그라운드 작업용)
    // CoreMotion은 쿼리 방식이 매우 빠르며 최근 데이터 반영이 즉각적입니다.
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
    
    // 3. 실시간 걸음 수 업데이트 (UI용 - 앱이 켜져있을 때 사용)
    // startUpdates를 사용하면 걸을 때마다 콜백이 옵니다.
    func startMonitoring(from start: Date, updateHandler: @escaping (Int) -> Void) {
        guard checkAvailability() else { return }
        
        pedometer.startUpdates(from: start) { data, error in
            guard let data = data, error == nil else { return }
            
            let steps = data.numberOfSteps.intValue
            updateHandler(steps)
        }
        //print("🚶‍♂️ CMPedometer 업데이트 시작됨")
    }
    
    // 모니터링 중지
    func stopMonitoring() {
        pedometer.stopUpdates()
        //print("🚶‍♂️ CMPedometer 업데이트 중지됨")
    }
}
