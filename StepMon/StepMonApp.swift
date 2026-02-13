import SwiftUI
import SwiftData
import UserNotifications
import GoogleMobileAds // AdMob 임포트 추가

// 1. 앱이 켜져있을 때 알림 처리를 위한 AppDelegate 클래스 정의
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        MobileAds.shared.start(completionHandler: nil) //AdMob SDK 초기화

        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}

@main
struct StepMonitorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    let container: ModelContainer
    
    init() {
        do {
            // [수정된 부분] NotificationHistory.self를 추가하여 두 모델을 모두 관리하도록 설정
            container = try ModelContainer(for: UserPreference.self, NotificationHistory.self)
            
            let context = ModelContext(container)
            
            // 초기 데이터 확인 및 생성
            let descriptor = FetchDescriptor<UserPreference>()
            if (try? context.fetch(descriptor).count) == 0 {
                context.insert(UserPreference())
            }
            
            // 백그라운드 매니저 초기화 및 등록
            BackgroundStepManager.shared.registerBackgroundTask(container: container)
            
            // ✅ 앱 시작 시 1회: 포그라운드 방식(pending 체크 후 submit)
            BackgroundStepManager.shared.scheduleAppRefreshForeground(reason: "app_init")
            AppLog.write("✅ app_init schedule FG")
            
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
