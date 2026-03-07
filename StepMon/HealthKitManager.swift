//
//  HealthKitManager.swift
//  StepMon
//
//  Created by Antigravity on 3/7/26.
//

import Foundation
import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    
    private init() {}
    
    // 걸음 수 데이터 타입
    private let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    
    // 1. 권한 요청
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [stepType])
            return true
        } catch {
            print("HealthKit Authorization Error: \(error.localizedDescription)")
            return false
        }
    }
    
    // 2. 최근 N일간의 일별 걸음수 조회
    func fetchDailySteps(days: Int) async -> [DailyStep] {
        let success = await requestAuthorization()
        guard success else { return [] }
        
        let now = Date()
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now)) else {
            return []
        }
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: nil,
                options: .cumulativeSum,
                anchorDate: calendar.startOfDay(for: startDate),
                intervalComponents: DateComponents(day: 1)
            )
            
            query.initialResultsHandler = { _, results, error in
                if let error = error {
                    print("HealthKit Query Error: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }
                
                var dailySteps: [DailyStep] = []
                
                results?.enumerateStatistics(from: startDate, to: now) { statistics, _ in
                    let steps = Int(statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                    dailySteps.append(DailyStep(date: statistics.startDate, steps: steps))
                }
                
                continuation.resume(returning: dailySteps)
            }
            
            healthStore.execute(query)
        }
    }
}
