import SwiftUI
import GoogleMobileAds

// UI와 연결되므로 MainActor로 지정하여 스레드 안전성 보장
@MainActor
@Observable
class RewardedAdManager: NSObject {
    static let shared = RewardedAdManager()
    
    private var rewardedAd: RewardedAd?
    // [추가] 보상 획득 상태 및 콜백 저장 변수
    private var didEarnReward: Bool = false
    private var onRewardEarned: (() -> Void)?
    
    #if DEBUG
    let adUnitID = "ca-app-pub-3940256099942544/1712485313" //test용
    #else
    let adUnitID = "ca-app-pub-9944760674540476/7777142844" //real
    #endif
    
    var isAdLoaded: Bool = false
    
    override init() {
        super.init()
        
        #if DEBUG
        // 개발(Debug) 모드일 때만 테스트 기기 ID를 등록합니다.
        // 앱스토어 출시용(Release) 빌드에서는 이 코드가 아예 컴파일되지 않습니다.
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
            "e6cb35419a7823db52908fda46dd062f",//시뮬레이터
            "6c5b007f130807df0a7a134e246dd5b2" //iPhone177
        ]
        print("🛠️ 개발 모드: 테스트 기기 ID 등록 완료")
        #endif // DEBUG
    }
    
    func loadAd() {
                
        let request = Request()
        
        RewardedAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ 광고 로드 실패: \(error.localizedDescription)")
                    self.isAdLoaded = false
                    return
                }
                
                self.rewardedAd = ad
                self.rewardedAd?.fullScreenContentDelegate = self
                self.isAdLoaded = true
                print("✅ 광고 로드 성공!")
            }
        }
    }
    
    func showAd(completion: @escaping () -> Void) {
        guard let root = getRootViewController() else {
            print("❌ 최상위 뷰 컨트롤러를 찾을 수 없습니다.")
            return
        }
        
        if let ad = rewardedAd {
            // 1. 상태 초기화 및 콜백 저장
            self.didEarnReward = false
            self.onRewardEarned = completion
            
            ad.present(from: root) { [weak self] in
                // 2. 구글이 "보상 요건 충족"을 알리는 시점 (플래그만 변경)
                self?.didEarnReward = true
                print("✨ 보상 요건 충족됨 (아직 지급 전)")
            }
        } else {
            print("⚠️ 광고가 준비되지 않았습니다.")
            self.loadAd()
        }
    }
    
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        
        var topController = window.rootViewController
        
        // 현재 화면에 가장 위에 떠 있는(presented) 컨트롤러를 끝까지 찾아 올라갑니다.
        while let presentedController = topController?.presentedViewController {
            topController = presentedController
        }
        
        return topController
    }
}

// MARK: - FullScreenContentDelegate
extension RewardedAdManager: FullScreenContentDelegate {
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("🚪 광고 창 닫힘.")
        
        // 3. 광고가 정상적으로 닫혔고, 보상 요건도 충족했을 때만 최종 보상 지급
        if didEarnReward {
            print("💰 최종 보상 지급 실행")
            onRewardEarned?()
        }
        
        // 초기화 및 재로드
        self.didEarnReward = false
        self.onRewardEarned = nil
        self.rewardedAd = nil
        self.loadAd()
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        self.isAdLoaded = false
        self.didEarnReward = false
        self.onRewardEarned = nil
        self.loadAd()
    }
}
