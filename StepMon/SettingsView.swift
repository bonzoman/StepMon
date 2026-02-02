import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Query var preferences: [UserPreference]
    
    var body: some View {
        NavigationStack {
            Form {
                if let pref = preferences.first {
                    
                // SettingsView.swift 수정 부분
                Section {
                    // 1. 집계 시작 시간(범위) 설정으로 문구 변경
                    VStack(alignment: .leading, spacing: 12) {
                        Label("걸음 수 집계 범위 설정", systemImage: "clock.arrow.2.circlepath")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            // "최근 60분"와 같이 시작 지점을 강조
                            Text("최근 \(pref.checkIntervalMinutes)분")
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)
                                .frame(width: 120, alignment: .leading)
                            
                            Slider(value: Binding(
                                get: { Double(pref.checkIntervalMinutes) },
                                set: { pref.checkIntervalMinutes = Int($0) }
                            ), in: 15...120, step: 15)
                            .tint(.blue)
                        }
                        
//                        Text("체크 시점에 위에서 설정한 시간만큼 과거의 기록부터 현재까지 합산합니다.")
//                            .font(.caption2)
//                            .foregroundStyle(.gray)
                    }
                    .padding(.vertical, 4)
                    
                    // 2. 기준 걸음 수 (기존 유지)
                    Stepper(value: Bindable(pref).stepThreshold, in: 50...1000, step: 50) {
                        Label {
                            HStack(spacing: 4) {
                                Text("최소 걸음수:")
                                Text("\(pref.stepThreshold)보").fontWeight(.bold)
                            }
                        } icon: {
                            Image(systemName: "figure.walk")
                                .foregroundStyle(.green)
                        }
                    }
//                } header: {
//                    Text("알림 분석 설정")
                } footer: {
                    Text("설정된 범위 내 활동량이 기준보다 적을 때만 응원 알림을 보내드려요.")
                }
                
                    
                    // 2. 알림 시간대 설정 섹션
                    Section {
                        DatePicker(selection: Bindable(pref).startTime, displayedComponents: .hourAndMinute) {
                            Label("알림 시작", systemImage: "sun.max.fill")
                                .foregroundStyle(.orange)
                        }
                        
                        DatePicker(selection: Bindable(pref).endTime, displayedComponents: .hourAndMinute) {
                            Label("알림 종료", systemImage: "moon.stars.fill")
                                .foregroundStyle(.indigo)
                        }
                    } header: {
                        Text("알림 시간 설정")
                    }
//                    footer: {
//                        Text("밤늦은 시간이나 이른 아침에는 알림이 울리지 않도록 설정할 수 있어요.")
//                    }
                    
                    // 3. 슈퍼유저 전용 섹션 (00:02 ~ 23:58 조건 충족 시 노출)
                    if pref.isSuperUser {
                        Section {
                            NavigationLink(destination: NotificationHistoryView()) {
                                Label {
                                    Text("알림 체크 히스토리 (최근 100개)")
                                        .fontWeight(.medium)
                                } icon: {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundStyle(.orange)
                                }
                            }
                        } header: {
                            Text("시스템 관리 (SuperUser)")
                        }
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
