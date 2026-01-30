//
//  ContentView.swift
//  StepMon
//
//  Created by 오승준 on 1/24/26.
//

import SwiftUI
import SwiftData

// SwiftUI의 View는 Java의 UI 클래스(Activity/Fragment)와 비슷한 역할을 하지만,
// 선언형(Declarative) 방식으로 UI를 기술합니다.
struct ContentView: View {
    // @Environment는 외부 환경값을 주입받습니다.
    // Java에서는 Application/Context에서 상태를 가져오는 패턴과 유사합니다.
    @Environment(\.scenePhase) private var scenePhase
    // @Query는 SwiftData에서 데이터를 가져오는 속성 래퍼입니다.
    // Java의 ORM(예: Room)에서 DAO를 통해 조회하는 흐름을 축약한 형태로 볼 수 있습니다.
    @Query private var preferences: [UserPreference]
    
    // @State는 View 내부에서만 관리되는 상태입니다.
    // Java에서의 필드 상태와 유사하지만, 값이 바뀌면 UI가 자동으로 다시 그려집니다.
    @State private var viewModel = StepViewModel()
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                // 걸음 수 시각화
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    
                    Text("\(viewModel.currentSteps)")
                        .font(.system(size: 70, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    
                    VStack {
                        Spacer()
                        Text("오늘의 걸음")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.bottom, 60)
                    }
                }
                .frame(width: 250, height: 250)
                
                Spacer()
                
                if let pref = preferences.first {
                    Text("현재 설정: \(pref.checkIntervalMinutes)분 동안 \(pref.stepThreshold)걸음 미만 시 알림")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .navigationTitle("Step Monitor")
            .toolbar {
                Button(action: { showSettings = true }) {
                    Label("설정", systemImage: "gear")
                }
            }
            .sheet(isPresented: $showSettings) {
                // $showSettings는 바인딩(Binding)입니다.
                // Java에서 다이얼로그의 상태를 참조로 공유하는 방식과 유사합니다.
                SettingsView()
            }
            .onAppear {
                // onAppear는 뷰가 화면에 나타날 때 호출됩니다.
                // Java의 onStart()/onResume()에 대응되는 시점으로 생각할 수 있습니다.
                viewModel.startUpdates()
                requestNotificationPermission()
            }
            // 앱이 백그라운드로 갈 때 작업 스케줄링
            .onChange(of: scenePhase) { oldPhase, newPhase in
                switch newPhase {
                case .active:
                    // 1. 앱이 다시 활성화될 때(화면 켜질 때) 즉시 걸음 수 갱신
                    print("앱 활성화: 걸음 수 새로고침")
                    viewModel.fetchTodaySteps()
                    
                case .background:
                    // 2. 앱이 백그라운드로 갈 때 작업 스케줄링 (기존 로직)
                    BackgroundStepManager.shared.scheduleAppRefresh()
                    
                default:
                    break
                }
            }
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}

