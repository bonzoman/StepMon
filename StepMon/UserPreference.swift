import Foundation
import SwiftData

@Model
class UserPreference {
    // 기존 설정
    var checkIntervalMinutes: Int
    var stepThreshold: Int
    var startTime: Date
    var endTime: Date
    
    // 게임 데이터
    var lifeWater: Int
    var treeLevel: Int
    var workerLevel: Int
    
    var treeInvestment: Int
    var workerInvestment: Int
    
    var lastCheckedSteps: Int
    var lastAccessDate: Date
    var dailyEarnedWater: Int
    
    // 백그라운드 알림 체크용 데이터 (구간 걸음 수 & 체크 시간)
    var bgCheckSteps: Int = 0      // 알림 체크 당시의 '구간 걸음 수'
    var bgCheckDate: Date = Date() // 알림 체크한 시간
    var isNotificationEnabled: Bool = false // 알림 마스터 스위치 상태
    var lastWinDate: Date? = nil // 마지막 대박 당첨 시간
    var lastAdDate: Date? = nil // 마지막 광고 시청 시간
    
    // 슈퍼유저 판별 로직
    var isSuperUser: Bool {
        let calendar = Calendar.current
        let startComp = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComp = calendar.dateComponents([.hour, .minute], from: endTime)
        
        return startComp.hour == 0 && startComp.minute == 2 &&
               endComp.hour == 23 && endComp.minute == 58
    }
    
    init(checkIntervalMinutes: Int = 60,
         stepThreshold: Int = 100,
         isNotificationEnabled: Bool = true,
         startTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!,
         endTime: Date = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date())!) {
        
        self.checkIntervalMinutes = checkIntervalMinutes
        self.stepThreshold = stepThreshold
        self.isNotificationEnabled = isNotificationEnabled
        self.startTime = startTime
        self.endTime = endTime
        
        self.lifeWater = 0
        self.treeLevel = 1
        self.workerLevel = 1
        
        self.treeInvestment = 0
        self.workerInvestment = 0
        
        self.lastCheckedSteps = 0
        self.lastAccessDate = Date()
        self.dailyEarnedWater = 0
        
        // 추가된 필드 초기화
        self.bgCheckSteps = 0
        self.bgCheckDate = Date()
        self.lastWinDate = nil
        self.lastAdDate = nil // 초기값은 광고를 본 적 없는 상태
    }
}

@Model
class NotificationHistory {
    var timestamp: Date
    var steps: Int
    var threshold: Int
    var isNotified: Bool
    var intervalMinutes: Int // [추가] 기록 시점의 집계 범위(분) 저장
    
    init(timestamp: Date, steps: Int, threshold: Int, isNotified: Bool, intervalMinutes: Int) {
        self.timestamp = timestamp
        self.steps = steps
        self.threshold = threshold
        self.isNotified = isNotified
        self.intervalMinutes = intervalMinutes
        
    }
}
