import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL // URL 오픈을 위한 환경 변수 추가
    @Query var preferences: [UserPreference]
    
    // ✅ 초기값 스냅샷 저장용
    @State private var baseline: SettingsBaseline?

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
                                    Text("최소 걸음 수:")
                                    // 현재 설정값 강조
                                    Text("\(pref.stepThreshold)").fontWeight(.bold)
                                        .foregroundStyle(.blue)
                                }
                            } icon: {
                                Image(systemName: "figure.walk")
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.vertical, 4)
                        
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
                            // 시작 시간: 종료 시간 이전으로 제한
                            DatePicker(selection: Bindable(pref).startTime, in: ...pref.endTime, displayedComponents: .hourAndMinute) {
                                Label("알림 시작", systemImage: "sun.max.fill")
                                    .foregroundStyle(.orange)
                            }

                            // 종료 시간: 시작 시간 이후로 제한
                            DatePicker(selection: Bindable(pref).endTime, in: pref.startTime..., displayedComponents: .hourAndMinute) {
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
                        
//                        // ✅ 추가: BG 로그 보기
//                        NavigationLink(destination: LogViewerView()) {
//                            Label {
//                                Text("BG 로그 보기")
//                                    .fontWeight(.medium)
//                            } icon: {
//                                Image(systemName: "doc.text.magnifyingglass")
//                                    .foregroundStyle(.secondary)
//                            }
//                        }
                        
                    } header: {
                        Text("기록 관리")
                    }
                    
                    // 4. 고객 지원 (추가된 섹션)
                    Section {
                        Button(action: {
                            sendEmail()
                        }) {
                            Label {
                                Text("[스탭몬] 문의 및 제안")
                                    .foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: "envelope.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
//                    header: {
//                        Text("지원")
//                    }
                    
                }
            }
            .navigationTitle("설정")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") {
                        guard let pref = preferences.first else {
                            dismiss()
                            return
                        }

                        let current = SettingsBaseline(pref: pref, timeZone: TimeZone.current.identifier)

                        // baseline 없으면(이상케이스) 그냥 닫기
                        guard let baseline else {
                            dismiss()
                            return
                        }

                        // ✅ 변경 없으면 업로드 없이 닫기
                        if current == baseline {
                            dismiss()
                            return
                        }

                        // ✅ 변경 있으면 1회 업로드 후 닫기
                        Task {
                            await DeviceSettingsUploader.shared.upsert(
                                isNotificationEnabled: pref.isNotificationEnabled,
                                startMinutes: minutesOfDay(pref.startTime),
                                endMinutes: minutesOfDay(pref.endTime),
                                timeZone: TimeZone.current.identifier
                            )
                            dismiss()
                        }
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                if baseline == nil, let pref = preferences.first {
                    baseline = SettingsBaseline(pref: pref, timeZone: TimeZone.current.identifier)
                }
            }
        }
    }
    
    // 이메일 발송 로직
    private func sendEmail() {
        let address = "bonzoman@gmail.com" // 수신할 이메일 주소 입력
        let subject = "[스탭몬] 문의 및 제안".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = ""
        
        if let url = URL(string: "mailto:\(address)?subject=\(subject)&body=\(body)") {
            openURL(url)
        }
    }
    

    private func minutesOfDay(_ date: Date) -> Int {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        return h * 60 + m
    }
    
    private struct SettingsBaseline: Equatable {
        let isNotificationEnabled: Bool
        let startMinutes: Int
        let endMinutes: Int
        let timeZone: String

        init(pref: UserPreference, timeZone: String) {
            self.isNotificationEnabled = pref.isNotificationEnabled
            self.startMinutes = SettingsBaseline.minutesOfDay(pref.startTime)
            self.endMinutes = SettingsBaseline.minutesOfDay(pref.endTime)
            self.timeZone = timeZone
        }

        private static func minutesOfDay(_ date: Date) -> Int {
            var cal = Calendar.current
            cal.timeZone = TimeZone.current
            let comps = cal.dateComponents([.hour, .minute], from: date)
            return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        }
    }


}



