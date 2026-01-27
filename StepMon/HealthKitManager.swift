//
//  HealthKitManager.swift
//  StepMon
//  HealthKit 연동 담당
//  Created by 오승준 on 1/26/26.
//

import Foundation
import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    let healthStore = HKHealthStore()
    
    // 읽기 데이터 타입 정의 (걸음 수)
    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    
    private init() {}
    
    // 1. 권한 요청
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }
        let typesToRead: Set = [stepType]
        // 쓰기 권한은 필요 없다면 nil로 설정 (필요하면 추가)
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if let error = error { print("HealthKit 권한 오류: \(error)") }
            completion(success)
        }
    }
    
    // 2. 특정 기간의 걸음 수 가져오기 (최종 수정됨)
    func fetchStepCount(from start: Date, to end: Date, completion: @escaping (Int) -> Void) {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        // [.cumulativeSum, .separateBySource] 옵션을 사용하여
        // Apple이 내부적으로 기기 간 중복을 제거하고 합산한 결과를 가져오도록 유도
        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: [.cumulativeSum, .separateBySource]
        ) { _, result, error in
            
            guard let result = result, let sum = result.sumQuantity() else {
                completion(0)
                return
            }
            
            let steps = Int(sum.doubleValue(for: HKUnit.count()))
            completion(steps)
        }
        
        healthStore.execute(query)
    }

    // 3. 오늘의 총 걸음 수 (편의 함수)
    func fetchTodayTotalSteps(completion: @escaping (Int) -> Void) {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        
        fetchStepCount(from: startOfDay, to: now) { steps in
            print("오늘 총 걸음 수: \(steps)")
            completion(steps)
        }
    }
}
