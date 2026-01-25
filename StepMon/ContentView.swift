//
//  ContentView.swift
//  StepMon
//
//  Created by 오승준 on 1/24/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query private var preferences: [UserPreference]
    
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
                SettingsView()
            }
            .onAppear {
                viewModel.startUpdates()
                requestNotificationPermission()
            }
            // 앱이 백그라운드로 갈 때 작업 스케줄링
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .background {
                    BackgroundStepManager.shared.scheduleAppRefresh()
                }
            }
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}


