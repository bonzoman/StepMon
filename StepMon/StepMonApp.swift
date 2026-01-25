//
//  StepMonApp.swift
//  StepMon
//
//  Created by 오승준 on 1/24/26.
//

import SwiftUI
import SwiftData

@main
struct StepMonitorApp: App {
    // 1. 컨테이너를 여기서 직접 생성하여 제어
    let container: ModelContainer
    
    init() {
        do {
            container = try ModelContainer(for: UserPreference.self)
            
            // 2. 초기 데이터 확인 및 생성
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<UserPreference>()
            if (try? context.fetch(descriptor).count) == 0 {
                context.insert(UserPreference()) // 기본값 생성
            }
            
            // 3. 백그라운드 매니저 초기화 및 등록 (매우 중요: init에서 실행되어야 함)
            BackgroundStepManager.shared.registerBackgroundTask(container: container)
            
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container) // 뷰 계층에도 주입
    }
}
