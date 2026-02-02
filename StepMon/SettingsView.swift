import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Query var preferences: [UserPreference]
    
    var body: some View {
        NavigationStack {
            Form {
                if let pref = preferences.first {
                    
                    // 1. 알림 조건 설정 섹션
                    Section {
                        // 검사 간격 설정
                        VStack(alignment: .leading, spacing: 8) {
                            Label("얼마나 자주 확인할까요?", systemImage: "timer")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            HStack {
                                Text("\(pref.checkIntervalMinutes)분 마다")
                                    .fontWeight(.bold)
                                    .foregroundStyle(.blue)
                                    .frame(width: 80, alignment: .leading)
                                
                                Slider(value: Binding(
                                    get: { Double(pref.checkIntervalMinutes) },
                                    set: { pref.checkIntervalMinutes = Int($0) }
                                ), in: 15...120, step: 15)
                                .tint(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        // 기준 걸음 수 설정
                        Stepper(value: Bindable(pref).stepThreshold, in: 50...1000, step: 50) {
                            Label {
                                HStack(spacing: 4) {
                                    Text("최소 활동 기준:")
                                    Text("\(pref.stepThreshold)보").fontWeight(.bold)
                                }
                            } icon: {
                                Image(systemName: "figure.walk")
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.vertical, 4)
                        
                    } header: {
                        Text("똑똑한 알림 설정")
                    } footer: {
                        Text("설정한 시간마다 걸음 수를 체크해서, 기준보다 적게 걸었을 때만 응원 알림을 보내드려요.")
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
                    } footer: {
                        Text("밤늦은 시간이나 이른 아침에는 알림이 울리지 않도록 설정할 수 있어요.")
                    }
                    
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
