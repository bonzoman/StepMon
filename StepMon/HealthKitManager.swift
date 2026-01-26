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
    
    // 읽고 쓸 데이터 타입 정의 (걸음 수)
    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    
    private init() {}
    
    // 1. 권한 요청
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }
        
        let typesToShare: Set = [stepType]
        let typesToRead: Set = [stepType]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if let error = error { print("HealthKit 권한 오류: \(error)") }
            completion(success)
        }
    }
    
    // 2. 특정 기간의 걸음 수 가져오기
    func fetchStepCount(from start: Date, to end: Date, completion: @escaping (Int) -> Void) {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                completion(0)
                return
            }
            // count 단위로 변환
            let steps = Int(sum.doubleValue(for: HKUnit.count()))
            completion(steps)
        }
        
        healthStore.execute(query)
    }
}
