import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query private var preferences: [UserPreference]
    
    @State private var viewModel = StepViewModel()
    @State private var showSettings = false
    
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
                            
                            // [우측/수정됨] 백그라운드 체크 정보 (구간 걸음 수)
                            if let pref = preferences.first {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("알림 체크") // 제목 변경
                                        .font(.caption2)
                                        .foregroundStyle(.black.opacity(0.5))
                                    
                                    HStack(spacing: 4) {
                                        // 여기 표시되는 값이 알림에 떴던 그 값(구간 걸음 수)입니다.
                                        Text("\(pref.bgCheckSteps)보")
                                            .fontWeight(.bold)
                                        Text("•")
                                        Text(timeFormatter.string(from: pref.bgCheckDate))
                                    }
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.black.opacity(0.7))
                                }
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
                    
                    // 2. 게임 정보 및 풍경
                    if let pref = preferences.first {
                        VStack(spacing: 5) {
                            HStack {
                                Image(systemName: "drop.fill")
                                    .foregroundStyle(.blue)
                                Text("\(pref.lifeWater)")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .contentTransition(.numericText())
                                Text("생명수")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            
                            HStack {
                                Text("오늘 획득: \(pref.dailyEarnedWater) / \(maxDailyWater)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                
                                ProgressView(value: Double(pref.dailyEarnedWater), total: Double(maxDailyWater))
                                    .progressViewStyle(.linear)
                                    .frame(width: 100)
                                    .tint(pref.isSuperUser ? .orange : .blue)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 25)
                        .background(.regularMaterial)
                        .clipShape(Capsule())
                        
                        GardenView(pref: pref)
                        
                    } else {
                        ProgressView().padding()
                    }
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear {
                viewModel.startUpdates()
                requestNotificationPermission()
            }
            .onChange(of: viewModel.currentSteps) { _, newSteps in
                if let pref = preferences.first {
                    calculateLifeWater(pref: pref, currentSteps: newSteps)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    viewModel.fetchTodaySteps()
                } else if newPhase == .background {
                    BackgroundStepManager.shared.scheduleAppRefresh()
                }
            }
        }
    }
    
    // 생명수 계산 로직
    func calculateLifeWater(pref: UserPreference, currentSteps: Int) {
        let calendar = Calendar.current
        
        if !calendar.isDate(pref.lastAccessDate, inSameDayAs: Date()) {
            pref.dailyEarnedWater = 0
            pref.lastCheckedSteps = 0
            pref.lastAccessDate = Date()
        }
        
        let diff = currentSteps - pref.lastCheckedSteps
        
        if diff > 0 {
            let efficiency = GameResourceManager.getWorkerEfficiency(level: pref.workerLevel)
            let multiplier = 1.0
            
            let earned = Int(Double(diff) * efficiency * 0.1 * multiplier)
            
            if earned > 0 {
                let availableSpace = maxDailyWater - pref.dailyEarnedWater
                let finalEarned = min(earned, availableSpace)
                
                if finalEarned > 0 {
                    pref.lifeWater += finalEarned
                    pref.dailyEarnedWater += finalEarned
                    pref.lastCheckedSteps = currentSteps
                }
            } else {
                pref.lastCheckedSteps = currentSteps
            }
        } else if diff < 0 {
            pref.lastCheckedSteps = currentSteps
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}
