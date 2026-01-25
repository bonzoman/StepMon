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

    init(checkIntervalMinutes: Int = 60, stepThreshold: Int = 100) {
        self.checkIntervalMinutes = checkIntervalMinutes
        self.stepThreshold = stepThreshold
    }
}
