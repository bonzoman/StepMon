import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query private var preferences: [UserPreference]
    
    // [추가] 히스토리 테이블의 최신 레코드 1개를 감시하는 쿼리
    // 데이터가 쌓이는 즉시 메인 화면이 갱신되도록 합니다.
    @Query(sort: \NotificationHistory.timestamp, order: .reverse)
    private var histories: [NotificationHistory]
    
    @State private var viewModel = StepViewModel()
    @State private var showSettings = false
    @State private var rewardPulse = 1.0
    @State private var rewardColor: Color = .blue
    
    // beginBackgroundTask 토큰
    @State private var bgTaskId: UIBackgroundTaskIdentifier = .invalid
    @State private var showLog = false
    @State private var showNotifTooltip = false
    
    @State private var recentSteps: Int? = nil
    @State private var recentCheckedAt: Date? = nil

    let targetStepsForBackground: Double = 10000.0
    
    var maxDailyWater: Int {
        return 2500
    }
    
    var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // --- [배경 효과] ---
                Color(red: 0.96, green: 0.96, blue: 0.94).ignoresSafeArea()
                
                let progress = min(Double(viewModel.currentSteps) / targetStepsForBackground, 1.0)
                LinearGradient(
                    colors: [
                        Color(red: 0.6, green: 0.9, blue: 0.8).opacity(0.8),
                        Color(red: 0.4, green: 0.8, blue: 0.4)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .opacity(0.05 + (progress * 0.95))
                .animation(.easeInOut(duration: 1.0), value: viewModel.currentSteps)
                
                // --- [메인 콘텐츠] ---
                ScrollView(showsIndicators: false) { // [추가] 스크롤 가능하게 변경
                    VStack(spacing: 20) {
                        // 헤더
                        HStack {
                            Spacer()
                            Text("Step Mon")
                                .font(.system(.largeTitle, design: .rounded))
                                .fontWeight(.heavy)
                                .foregroundStyle(
                                    LinearGradient(colors: [.green, .blue], startPoint: .leading, endPoint: .trailing)
                                )
                                .shadow(color: .white.opacity(0.5), radius: 2, x: 0, y: 1)
                            
                            
                            if preferences.first?.isSuperUser == true {
                                // ✅ 로그 버튼 추가 (설정 버튼 왼쪽)
                                Button(action: { showLog = true }) {
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .font(.title2)
                                        .foregroundStyle(.gray)
                                }
                                .padding(.leading, 8)
                            }
                            
                            
                            Button(action: { showSettings = true }) {
                                Image(systemName: "gearshape.fill")
                                    .font(.title2)
                                    .foregroundStyle(.gray)
                            }
                            .padding(.leading, 10)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        // 1. 걸음 수 정보 영역
                        VStack(spacing: 5) {
                            
                            HStack(alignment: .bottom) {
                                
                                // [좌측] 실시간 전체 걸음 수
                                HStack(alignment: .lastTextBaseline, spacing: 5) {
                                    Text("\(viewModel.currentSteps)")
                                        .font(.system(size: 60, weight: .black, design: .rounded))
                                        .contentTransition(.numericText())
                                        .minimumScaleFactor(0.5)
                                        .lineLimit(1)
                                        .foregroundStyle(.black)
                                    
                                    Text("걸음")
                                        .font(.headline)
                                        .foregroundStyle(.black.opacity(0.6))
                                        .padding(.bottom, 8)
                                }
                                
                                Spacer()
                                
                                if let pref = preferences.first, pref.isSuperUser {
                                    NavigationLink(destination: NotificationHistoryView()) {
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("알림 체크")
                                                .font(.caption2)
                                                .foregroundStyle(.black.opacity(0.5))
                                            
                                            HStack(spacing: 4) {
                                                // [핵심 변경] pref.bgCheckSteps 대신 히스토리의 가장 최신 값을 표시
                                                Text("\(histories.first?.steps ?? 0)")
                                                    .fontWeight(.bold)
                                                Text("•")
                                                Text(histories.first?.timestamp.formatted(date: .omitted, time: .shortened) ?? "--:--")
                                                
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundStyle(.black.opacity(0.3))
                                            }
                                            .font(.caption)
                                            .monospacedDigit()
                                            .foregroundStyle(.black.opacity(0.7))
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.leading, 8)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.bottom, 8)
                                }
                            }
                            .padding(.horizontal, 25)
                            
                            // 게이지 바
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .frame(width: geometry.size.width, height: 20)
                                        .opacity(0.1)
                                        .foregroundColor(.black)
                                    
                                    Capsule()
                                        .frame(width: min(CGFloat(viewModel.currentSteps) / 10000.0 * geometry.size.width, geometry.size.width), height: 20)
                                        .foregroundStyle(
                                            LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                                        )
                                        .animation(.spring, value: viewModel.currentSteps)
                                }
                            }
                            .frame(height: 20)
                            .padding(.horizontal, 20)
                        }
                        
                        if let pref = preferences.first {
                            HStack(spacing: 20) {
                                VStack(spacing: 8) {
                                    HStack {
                                        Image(systemName: "drop.fill")
                                            .foregroundStyle(rewardColor) // 색상 변화 대응
                                        
                                        Text("\(pref.lifeWater)")
                                            .font(.system(size: 24, weight: .bold, design: .rounded))
                                            .contentTransition(.numericText())
                                            .scaleEffect(rewardPulse) // 숫자 펄스 효과
                                            .lineLimit(1)              // 무조건 한 줄로 표시
                                            .minimumScaleFactor(0.5)   // 공간 부족 시 원래 크기의 50%까지 축소해서라도 다 보여줌
                                            .layoutPriority(1)         // 다른 텍스트보다 공간을 먼저 차지하도록 우선순위 부여
                                        Text("생명수")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("오늘 획득: \(pref.dailyEarnedWater) / \(maxDailyWater)")
                                            .font(.caption) // 크기 상향 (생명수 문구와 동일하게)
                                            .foregroundStyle(.secondary)
                                        
                                        ProgressView(value: Double(pref.dailyEarnedWater), total: Double(maxDailyWater))
                                            .progressViewStyle(.linear)
                                            .frame(minWidth: 140) // 너비 확대
                                            .tint(pref.isSuperUser ? .orange : .blue)
                                    }
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 25)
                                .background(.regularMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(rewardColor.opacity(rewardPulse > 1.0 ? 0.5 : 0), lineWidth: 2) // 테두리 번쩍임
                                )
                                .scaleEffect(rewardPulse) // 전체 바운스
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .layoutPriority(1) // 박스 영역에 우선순위 부여하여 너비 확보
                                
                                // [위치 B] 생명수 영역 우측 토글 (VStack 바깥쪽)
                                VStack(spacing: 6) {
                                    HStack(spacing: 4) {
                                        Text("알림")
                                            .font(.caption) // 크기 상향
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary) // 다크모드 시인성 개선
                                        
                                        Button {
                                            showNotifTooltip.toggle()
                                        } label: {
                                            Image(systemName: "questionmark.circle.fill")
                                                .font(.caption) // 아이콘 크기 상향
                                                .foregroundStyle(.blue.opacity(0.8))
                                        }
                                        .popover(isPresented: $showNotifTooltip) {
                                            Text("On적용시 설정된 시간(\(pref.checkIntervalMinutes)분) 동안 \(pref.stepThreshold)보 미만으로 걸으면 알림을 보냅니다.")
                                                .font(.subheadline)
                                                .multilineTextAlignment(.leading)
                                                .fixedSize(horizontal: false, vertical: true)
                                                .frame(width: 280) // 너비 명시로 줄바꿈 유도
                                                .padding()
                                                .presentationCompactAdaptation(.popover)
                                        }
                                    }
                                    
                                    Toggle("", isOn: Binding(
                                        get: { pref.isNotificationEnabled },
                                        set: { _ in toggleNotification(pref: pref) }
                                    ))
                                    .labelsHidden()
                                    .scaleEffect(0.9) // 크기 약간 확대
                                    .tint(.blue)
                                }
                            }
                            .padding(.horizontal, 20)
                            .frame(maxWidth: .infinity) // 전체 너비 활용
                            // [핵심] 생명수 변화 감지 로직
                            .onChange(of: pref.lifeWater) { old, new in
                                //let diff = new - old
                                // 보상이 10 이상(대박 당첨)일 때만 작동
                                //if diff >= 30 {
                                if new > old { // 30 이상 조건 삭제, 1이라도 증가하면 실행
                                    triggerHeaderPulse()
                                }
                            }
                            
                            
                            GardenView(pref: pref)
                                .padding(.bottom, 50) // 하단 여백 확보
                            
                        } else {
                            ProgressView().padding()
                        }
                        
                        //Spacer()
                    } //end Vstack
                }
                // ✅ 상단 고정 배너 (스크롤과 분리)
                .safeAreaInset(edge: .top) {
                    if let pref = preferences.first {
                        RecentStepsBanner(
                            intervalMinutes: pref.checkIntervalMinutes,
                            steps: recentSteps,
                            threshold: pref.stepThreshold
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 6)
                    }
                }
                
                
                
                
                
                
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showLog) {
                NavigationStack {
                    LogViewerView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("닫기") { showLog = false }
                            }
                        }
                }
            }

            .onAppear {
                viewModel.fetchTodaySteps()   // ✅ 오늘 0시~현재로 즉시 동기화 + 그 다음 실시간
                requestNotificationPermission()
            }
            .onChange(of: viewModel.currentSteps) { _, newSteps in
                if let pref = preferences.first {
                    calculateLifeWater(pref: pref, currentSteps: newSteps)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    
                    viewModel.fetchTodaySteps() // ✅ 자정 지나서 돌아오면 어제값 방지
                    
                    refreshRecentSteps() //최근 60분 걸음수 refresh
                    
                    //SettingsView에서 알람정보 upload 실패해서 pending건 있다면 재시도
                    Task { await DeviceSettingsUploader.shared.flushIfNeeded() }
                    
                case .background:
                    
                    AppLog.write("🟡 scenePhase = background", .yellow)

                    BackgroundStepManager.shared.scheduleAppRefreshBackground(reason: "scene_background")

                    break

                case .inactive:
                    break

                @unknown default:
                    break
                }
            }
        }
    }
    
    func triggerHeaderPulse() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
            rewardPulse = 1.4 // 확 커졌다가
            rewardColor = .cyan // 색상 변경
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring()) {
                rewardPulse = 1.0 // 복귀
                rewardColor = .blue
            }
        }
    }
    
    // 생명수 계산 로직
    func calculateLifeWater(pref: UserPreference, currentSteps: Int) {
        let calendar = Calendar.current
        
        // 날짜가 바뀌었으면 일일 획득량 초기화
        if !calendar.isDate(pref.lastAccessDate, inSameDayAs: Date()) {
            pref.dailyEarnedWater = 0
            pref.lastAccessDate = Date()
            
            // 어제 총량(예: 1만보)보다 현재(오늘 아침: 500보)가 적다면움직임 부족
            // 기준점을 0으로 잡아서 오늘 아침에 걸은 500보를 온전히 계산에 포함시킵니다.
            if currentSteps < pref.lastCheckedSteps {
                pref.lastCheckedSteps = 0
            }
        }
        
        let diff = currentSteps - pref.lastCheckedSteps
        
        if diff > 0 {
            let efficiency = GameResourceManager.getWorkerEfficiency(level: pref.workerLevel)
            
            let earned = Int(Double(diff) * efficiency * 0.1)
            // 중요: 생명수가 1방울이라도 만들어질 수 있을 때만 걸음 기록을 갱신합니다.
            if earned > 0 {
                let availableSpace = maxDailyWater - pref.dailyEarnedWater
                let finalEarned = min(earned, availableSpace)
                
                if finalEarned > 0 {
                    pref.lifeWater += finalEarned
                    pref.dailyEarnedWater += finalEarned
                }
                // 생명수로 변환된 시점에만 마지막 체크 지점을 업데이트 (자투리 걸음 보존)
                pref.lastCheckedSteps = currentSteps
            }
        } else if diff < 0 {
            // 걸음 수 측정기가 리셋된 경우 등에 대비
            pref.lastCheckedSteps = currentSteps
        }
    }
    
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    private func refreshRecentSteps() {
        guard let pref = preferences.first else { return }

        let now = Date()
        let interval = TimeInterval(pref.checkIntervalMinutes * 60)
        let start = now.addingTimeInterval(-interval)

        recentSteps = nil // "확인중..." 표시

        CoreMotionManager.shared.querySteps(from: start, to: now) { steps in
            DispatchQueue.main.async {
                self.recentSteps = steps
                self.recentCheckedAt = now
            }
        }
    }

    private func toggleNotification(pref: UserPreference) {
        pref.isNotificationEnabled.toggle()
        
        // 햅틱 피드백
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // 서버 동기화
        Task {
            await DeviceSettingsUploader.shared.upsert(
                isNotificationEnabled: pref.isNotificationEnabled,
                timeZone: TimeZone.current.identifier
            )
        }
    }
}


private struct RecentStepsBanner: View {
    let intervalMinutes: Int
    let steps: Int?
    let threshold: Int

    var body: some View {
        let s = steps ?? 0
        let below = (steps != nil) && (s < threshold)

        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(below ? .orange : .primary)

            if let steps {
                
                let styledSteps = Text("\(steps)보")
                        .foregroundColor(.orange)
                        .bold()
                //MARK: 최근 60분 동안 500보 걸었어요. (Localizable.xcstrings 파일에 "RECENT_STEPS_STRING" 문구 있음)
                Text("RECENT_STEPS_STRING \(intervalMinutes) \(styledSteps)")
            } else {
                Text("최근 걸음 수를 확인 중…")
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .font(.subheadline)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.thinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
