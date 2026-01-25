//
//  SettingsView.swift
//  StepMon
//
//  Created by 오승준 on 1/25/26.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Query var preferences: [UserPreference]
    
    var body: some View {
        NavigationStack {
            Form {
                if let pref = preferences.first {
                    Section("알림 조건") {
                        VStack(alignment: .leading) {
                            Text("검사 간격: \(pref.checkIntervalMinutes)분")
                            Slider(value: Binding(
                                get: { Double(pref.checkIntervalMinutes) },
                                set: { pref.checkIntervalMinutes = Int($0) }
                            ), in: 15...120, step: 15)
                        }
                        
                        Stepper("기준 걸음 수: \(pref.stepThreshold)", value: Bindable(pref).stepThreshold, in: 50...1000, step: 50)
                    }
                    
                    // --- [추가된 섹션] ---
                    Section("방해 금지 시간 설정") {
                        DatePicker("알림 시작", selection: Bindable(pref).startTime, displayedComponents: .hourAndMinute)
                        DatePicker("알림 종료", selection: Bindable(pref).endTime, displayedComponents: .hourAndMinute)
                        
                        Text("설정된 시간 사이에만 알림이 울립니다.")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    // ------------------
                }
            }
            .navigationTitle("설정")
            .toolbar {
                Button("완료") { dismiss() }
            }
        }
    }
}
