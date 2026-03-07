//
//  StepHistoryViewModel.swift
//  StepMon
//
//  Created by Antigravity on 3/7/26.
//

import SwiftUI
import Observation

@Observable
class StepHistoryViewModel {
    var weeklySteps: [DailyStep] = []
    var monthlySteps: [DailyStep] = []
    var isLoading: Bool = false
    
    var averageWeeklySteps: Int {
        guard !weeklySteps.isEmpty else { return 0 }
        let total = weeklySteps.reduce(0) { $0 + $1.steps }
        return total / weeklySteps.count
    }
    
    var averageMonthlySteps: Int {
        guard !monthlySteps.isEmpty else { return 0 }
        let total = monthlySteps.reduce(0) { $0 + $1.steps }
        return total / monthlySteps.count
    }
    
    func fetchHistory() async {
        isLoading = true
        
        // 30일 데이터를 HealthKit에서 한 번에 가져옴
        let allData = await HealthKitManager.shared.fetchDailySteps(days: 30)
        
        await MainActor.run {
            self.weeklySteps = Array(allData.suffix(7))
            self.monthlySteps = allData
            self.isLoading = false
        }
    }
}
