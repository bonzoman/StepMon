import SwiftUI
import SwiftData
import UserNotifications // [필수] 알림 프레임워크 추가

// 1. [추가] 앱이 켜져있을 때 알림 처리를 위한 AppDelegate 클래스 정의
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 알림 센터의 대리자(delegate)를 나 자신(self)으로 설정
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // [핵심] 앱이 실행 중일 때 알림이 오면 호출되는 함수
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 앱이 켜져 있어도 배너(알림창), 소리, 배지를 모두 표시하도록 설정
        completionHandler([.banner, .sound, .badge])
    }
}

@main
struct StepMonitorApp: App {
    // 2. [추가] 위에서 만든 AppDelegate를 앱에 연결
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // 기존 로직 유지
    let container: ModelContainer
    
    init() {
        do {
            container = try ModelContainer(for: UserPreference.self)
            
            // 초기 데이터 확인 및 생성
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<UserPreference>()
            if (try? context.fetch(descriptor).count) == 0 {
                context.insert(UserPreference()) // 기본값 생성
            }
            
            // 백그라운드 매니저 초기화 및 등록
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
