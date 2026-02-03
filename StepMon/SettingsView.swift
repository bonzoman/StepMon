import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Query var preferences: [UserPreference]
    
    var body: some View {
        NavigationStack {
            Form {
                if let pref = preferences.first {
                    
                    // 1. 집계 범위 및 기준 설정
                    Section {
                        // [수정] 집계 범위: 30, 60, 90, 120분 선택 (Segmented Picker)
                        VStack(alignment: .leading, spacing: 8) {
                            Label("걸음 수 집계 범위", systemImage: "clock.arrow.2.circlepath")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Picker("집계 범위", selection: Bindable(pref).checkIntervalMinutes) {
                                Text("30분").tag(30)
                                Text("60분").tag(60)
                                Text("90분").tag(90)
                                Text("120분").tag(120)
                            }
                            .pickerStyle(.segmented) // 버튼 형태로 직관적 선택
                        }
                        .padding(.vertical, 4)
                        
                        // [수정] 기준 걸음 수: 100~1000보, 100단위 증감
                        Stepper(value: Bindable(pref).stepThreshold, in: 100...1000, step: 100) {
                            Label {
                                HStack(spacing: 4) {
                                    Text("최소 활동 기준:")
                                    // 현재 설정값 강조
                                    Text("\(pref.stepThreshold)보").fontWeight(.bold)
                                        .foregroundStyle(.blue)
                                }
                            } icon: {
                                Image(systemName: "figure.walk")
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.vertical, 4)
                        
                    } header: {
                        //Text(".")
                    }
                    footer: {
                        Text("설정된 시간(\(Text("\(pref.checkIntervalMinutes)분)").foregroundStyle(.blue)) 동안 \(Text("\(pref.stepThreshold)보").foregroundStyle(.blue)) 미만으로 걸으면 알림을 보냅니다.")
                    }
                    
                    // 2. 알림 시간 설정
                    Section {
                        Toggle(isOn: Bindable(pref).isNotificationEnabled) {
                            Label {
                                Text("알림 활성화")
                            } icon: {
                                Image(systemName: pref.isNotificationEnabled ? "bell.fill" : "bell.slash.fill")
                                    .foregroundStyle(pref.isNotificationEnabled ? .blue : .gray)
                            }
                        }
                        .tint(.blue)
                        
                        if pref.isNotificationEnabled {
                            DatePicker(selection: Bindable(pref).startTime, displayedComponents: .hourAndMinute) {
                                Label("알림 시작", systemImage: "sun.max.fill")
                                    .foregroundStyle(.orange)
                            }
                            
                            DatePicker(selection: Bindable(pref).endTime, displayedComponents: .hourAndMinute) {
                                Label("알림 종료", systemImage: "moon.stars.fill")
                                    .foregroundStyle(.indigo)
                            }
                            
                            // [추가] 필수 안내 문구 (주의사항)
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                                    .padding(.top, 2)
                                
                                Text("앱을 강제 종료하거나 취침 등 장시간 미사용 시 알림을 위해 앱을 실행시켜 주세요.")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("알림 시간 설정")
                    } footer: {
                        if !pref.isNotificationEnabled {
                            Text("현재 모든 응원 알림이 꺼져 있습니다.")
                                .foregroundStyle(.orange)
                        }
                    }
                    
                    // 3. 알림 히스토리 (모든 사용자에게 노출)
                    // 기존 슈퍼유저 섹션을 일반 섹션으로 변경 또는 통합
                    Section {
                        NavigationLink(destination: NotificationHistoryView()) {
                            Label {
                                Text("체크 히스토리(최근 30)")
                                    .fontWeight(.medium)
                            } icon: {
                                Image(systemName: "list.bullet.clipboard")
                                    .foregroundStyle(.blue)
                            }
                        }
                    } header: {
                        Text("기록 관리")
                    }
                }
            }
            .navigationTitle("설정")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}
