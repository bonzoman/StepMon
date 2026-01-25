//
//  UserPreference.swift
//  StepMon
//
//  Created by 오승준 on 1/24/26.
//

// UserPreference.swift
import Foundation
import SwiftData

@Model
class UserPreference {
    var checkIntervalMinutes: Int
    var stepThreshold: Int
    var startTime: Date // 알림 허용 시작 시간 (예: 오전 9시)
    var endTime: Date   // 알림 허용 종료 시간 (예: 오후 10시)
    
    init(checkIntervalMinutes: Int = 60,
         stepThreshold: Int = 100,
         startTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!, 
         endTime: Date = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date())!) {
        
        self.checkIntervalMinutes = checkIntervalMinutes
        self.stepThreshold = stepThreshold
        self.startTime = startTime
        self.endTime = endTime
    }
}
