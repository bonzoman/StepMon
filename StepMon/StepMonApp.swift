import SwiftUI
import SwiftData
import UserNotifications
import AppTrackingTransparency // ATT 임포트 추가
import GoogleMobileAds // AdMob 임포트 추가

// 1. 앱이 켜져있을 때 알림 처리를 위한 AppDelegate 클래스 정의
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        // ✅ 알림 센터 delegate
        let center = UNUserNotificationCenter.current()
        center.delegate = self
            
        // ✅ 로컬 알림 권한(배너/사운드/뱃지) + ✅ 푸시 토큰 발급을 위한 등록
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("❌ 알림 권한 요청 에러:", error)
                return
            }
            print("✅ 알림 권한:", granted)

            // 권한 승인 여부와 별개로 토큰 등록은 시도 가능(실패하면 didFail이 호출됨)
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
            
        return true
    }


    // ✅ deviceToken 발급 성공: 여기 찍힌 문자열을 SpringBoot의 deviceToken에 그대로 넣으면 됨
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("🔥 APNs deviceToken:", token)

        // 원하면 저장도 가능 (UserDefaults 등)
        // UserDefaults.standard.set(token, forKey: "apnsDeviceToken")
        
        // ✅ 현재 알림 허용 여부도 같이 실어 보냄
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let enabled = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)

            Task {
                await DeviceTokenUploader.shared.upsert(
                    deviceToken: token,
                    isNotificationEnabled: enabled
                )
            }
        }
    }
    
    
    // ✅ deviceToken 발급 실패
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ APNs 등록 실패:", error)
    }
    
    // ✅ 앱이 켜져있을 때 로컬 알림(또는 푸시 알림)을 어떻게 보여줄지
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    // ✅ Silent Push(= content-available: 1) 수신 지점
    // 서버 payload 예: { aps:{content-available:1}, reason:"stepcheck" }
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Silent Push 구분용(선택)
        let reason = userInfo["reason"] as? String ?? "unknown"
        print("📩 RemoteNotification 수신 reason=\(reason) userInfo=\(userInfo)")

        // ✅ 여기서 걸음수 체크 로직 실행
        BackgroundStepManager.shared.handleSilentPush(reason: reason) { ok in
            completionHandler(ok ? .newData : .failed)
        }        
    }
    
    
}

@main
struct StepMonitorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase // 앱 상태 감시용
    
    let container: ModelContainer
    
    init() {
        // ... (생략된 기존 초기화 코드 동일)
        do {
            container = try ModelContainer(for: UserPreference.self,
                                           NotificationHistory.self,
                                           AppLogEntry.self)
            AppLog.configure(container: container)
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<UserPreference>()
            if (try? context.fetch(descriptor).count) == 0 {
                context.insert(UserPreference())
            }
            BackgroundStepManager.shared.registerBackgroundTask(container: container)
            Task { await DeviceTokenUploader.shared.flushIfNeeded() }
            Task { await DeviceSettingsUploader.shared.flushIfNeeded() }
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
        // ✅ 앱 상태가 활성화될 때마다 호출되지만, 시스템이 권한 팝업을 띄울 필요가 있을 때만 띄워줍니다.
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                requestTrackingAuthorization()
            }
        }
    }

    private func requestTrackingAuthorization() {
        // 약간의 지연을 주어 앱 UI가 안정된 후 팝업이 뜨도록 함
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { status in
                print("🔍 ATT 권한 상태: \(status.rawValue)")
                
                // 권한 응답 후(또는 이미 결정된 후) AdMob SDK 초기화
                MobileAds.shared.start(completionHandler: nil)
            }
        }
    }
}
