import SwiftUI
import SwiftData
import UIKit
import Combine

struct UpgradeSheetView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var pref: UserPreference
    
    // [추가] 광고 매니저 연결 (@State로 선언하여 수명 주기 관리)
    private let adManager = RewardedAdManager.shared
    
    @State private var isWatchingAd = false // 광고 시청 상태(로딩 인디케이터용)
    @State private var now = Date() // 쿨타임 실시간 갱신용
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let adRewardAmount = 50 // 광고 보상량
    let coolDownTime: TimeInterval = 1 // (1초)
    

    
    // 상태에 따른 안내 문구 로직
    var statusMessage: String {
        if pref.isSuperUser {
            return String(localized: "슈퍼유저 모드: 생명수 소모 없이 즉시 레벨업")
        } else if pref.lifeWater >= 10 {
            // [수정] 나무와 일꾼 모두 만렙인 경우 안내 문구 변경
            if pref.treeLevel >= 100 && pref.workerLevel >= 100 {
                return String(localized: "모든 정원 관리가 완료되었습니다!")
            }
            return String(localized: "버튼을 눌러 생명수를 주입하세요.")
        } else {
            return String(localized: "생명수가 부족해요!")
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
//                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                    VStack(spacing: 16) {
                        Text("💧 보유 생명수")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                        
                        Text("\(pref.lifeWater)")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.blue)
                            .contentTransition(.numericText())
                        
                        if pref.isSuperUser {
                            Text("⚡️ SUPER USER ACTIVE ⚡️")
                                .font(.caption2)
                                .fontWeight(.black)
                                .foregroundStyle(.orange)
                        }
                        
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle((!pref.isSuperUser && pref.lifeWater < 10) ? .red : .secondary)
                        
                    }
                    
                    //Divider()
                    
                    // 1. 만보기 나무
                    let treeCost = getCost(level: pref.treeLevel)
                    UpgradeRow(
                        title: String(localized: "만보기 나무"),
                        level: pref.treeLevel,
                        maxLevel: 100, // [추가] 만렙 기준 전달
                        imageName: GameResourceManager.getMainTreeImage(level: pref.treeLevel),
                        buttonColor: .green,
                        totalCost: treeCost,
                        currentInvest: pref.treeInvestment
                    ) {
                        invest(target: .tree, totalCost: treeCost)
                    }
                    
                    // 2. 스텝몬 일꾼
                    let workerCost = getCost(level: pref.workerLevel)
                    UpgradeRow(
                        title: String(localized: "스텝몬 일꾼"),
                        level: pref.workerLevel,
                        maxLevel: 100, // [추가] 만렙 기준 전달
                        imageName: GameResourceManager.getMainWorkerImage(level: pref.workerLevel),
                        buttonColor: .blue,
                        totalCost: workerCost,
                        currentInvest: pref.workerInvestment
                    ) {
                        invest(target: .worker, totalCost: workerCost)
                    }
                    
                    // 일꾼 효율 설명
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text("일꾼 레벨이 오르면 생명수 획득 효율이 증가합니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal) // 좌우 여백만 적용
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                if pref.lifeWater < 10 {
                    adFloatingBar
                }
            }
            .navigationTitle("정원 관리소")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            // 뷰 진입 시 광고 미리 로드
            .onAppear {
                if !adManager.isAdLoaded {
                    adManager.loadAd()
                }
            }
        }
    }
    
    // --- [하단 고정 플로팅 바 뷰 블록] ---
    private var adFloatingBar: some View {
        let lastAd = pref.lastAdDate ?? Date.distantPast
        let timeElapsed = now.timeIntervalSince(lastAd)
        let isCoolDownActive = timeElapsed < coolDownTime
        
        // 광고가 로드되었는지 여부
        let isLoaded = adManager.isAdLoaded
        
        return VStack(spacing: 0) {
            Divider()
            
            VStack(spacing: 8) {
                // [수정] 로드 실패 시 재시도 할 수 있도록 분기 처리
                Button(action: {
                    if isLoaded {
                        showRealAd() // 로드됨 -> 광고 시청
                    } else {
                        adManager.loadAd() // 로드 안됨 -> 재시도 요청
                    }
                }) {
                    HStack {
                        if isWatchingAd {
                            ProgressView().tint(.white).padding(.trailing, 5)
                            Text("광고 준비 중...")
                        } else if isCoolDownActive {
                            let remaining = Int(coolDownTime - timeElapsed)
                            Image(systemName: "timer")
                            Text("(쿨타임) \(remaining / 60)분 \(remaining % 60)초")
                        } else if isLoaded {
                            // [상태 1] 광고 준비 완료
                            Image(systemName: "play.tv.fill")
                            Text("광고 보고 \(adRewardAmount) 💧 받기")
                        } else {
                            // [상태 2] 로드 실패 또는 로딩 중 (버튼 활성화해서 재시도 유도)
                            Image(systemName: "arrow.clockwise")
                            Text("광고 불러오기")
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    // 버튼 색상: 로드됨(파랑) vs 로드안됨(주황/회색) vs 쿨타임(회색)
                    .background(
                        isCoolDownActive ? Color.gray :
                            (isLoaded ? Color.blue : Color.orange) // 로드 안됐으면 주황색으로 강조
                    )
                    .cornerRadius(12)
                }
                // 쿨타임이거나 시청 중일 때만 비활성화 (로드 실패 시에는 클릭 가능해야 함)
                .disabled(isCoolDownActive || isWatchingAd)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .background(.ultraThinMaterial)
        }
        .transition(.move(edge: .bottom))
        .onReceive(timer) { _ in self.now = Date() }
    }
    
    // UpgradeRow 컴포넌트
    @ViewBuilder
    func UpgradeRow(title: String, level: Int, maxLevel: Int, imageName: String, buttonColor: Color, totalCost: Int, currentInvest: Int, action: @escaping () -> Void) -> some View {
        
        let isMax = level >= maxLevel // 만렙 여부 확인
        
        HStack(spacing: 12) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 45, height: 45)
                .background(Circle().fill(buttonColor.opacity(0.1)))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.primary)
                
                HStack {
                    Text(isMax ? "MAX" : "Lv.\(level)") // 만렙시 MAX 표시
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(currentInvest) / \(totalCost)")
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundStyle(.gray)
                }
                
                // 만렙이면 게이지를 꽉 채움
                ProgressView(value: isMax ? 1.0 : Double(currentInvest), total: isMax ? 1.0 : Double(totalCost))
                    .progressViewStyle(.linear)
                    .tint(isMax ? .orange : buttonColor)
                    .scaleEffect(x: 1, y: 0.8, anchor: .center) //게이지 두께 얇게 조정
            }
            
            Spacer()
            
            Button(action: action) {
                VStack(spacing: 0) {
                    if isMax {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14)) // 아이콘 크기 고정
                        Text("완료")
                            .font(.system(size: 8)) // 텍스트 크기 고정
                            .bold()
                    } else if pref.isSuperUser {
                        Text("UP")
                            .font(.subheadline)
                            .bold()
                    } else {
                        Image(systemName: "drop.fill")
                            //.font(.system(size: 12))
                        Text("10")
                            .font(.caption)
//                            .font(.system(size: 10))
                            .bold()
                    }
                }
                .frame(width: 40, height: 40) // [수정] 버튼 크기 고정 (높이 축소)

            }
            .buttonStyle(.borderedProminent)
            .tint(isMax ? .gray : buttonColor) // 만렙시 회색 버튼
            .disabled(isMax || (!pref.isSuperUser && pref.lifeWater < 10)) // 만렙시 비활성화
            
            
        }
        .padding(.vertical, 10) // [수정] 상하 여백 축소
        .padding(.horizontal, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
    
    func getCost(level: Int) -> Int {
        return level * 100
    }
    
    enum InvestmentTarget { case tree, worker }
    
    func invest(target: InvestmentTarget, totalCost: Int) {
        // [추가] 만렙 도달 시 더 이상 투자 불가
        if target == .tree && pref.treeLevel >= 100 { return }
        if target == .worker && pref.workerLevel >= 100 { return }
        
        if pref.isSuperUser {
            if target == .tree {
                pref.treeLevel += 1
                pref.treeInvestment = 0
            } else {
                pref.workerLevel += 1
                pref.workerInvestment = 0
            }
            triggerSuccessHaptic()
            return
        }
        
        let costAmount = 10
        guard pref.lifeWater >= costAmount else { return }
        
        pref.lifeWater -= costAmount
        
        if target == .tree {
            pref.treeInvestment += 10
            if pref.treeInvestment >= totalCost {
                pref.treeLevel += 1
                pref.treeInvestment = 0
                triggerSuccessHaptic()
            } else {
                triggerTapHaptic()
            }
        } else {
            pref.workerInvestment += 10
            if pref.workerInvestment >= totalCost {
                pref.workerLevel += 1
                pref.workerInvestment = 0
                triggerSuccessHaptic()
            } else {
                triggerTapHaptic()
            }
        }
    }
    
    func triggerTapHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    func triggerSuccessHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    
    // [변경] 실제 광고 표시 함수
    private func showRealAd() {
        // 이미 광고 시청 시도 중이면 중복 실행 방지
        guard !isWatchingAd else { return }
        
        isWatchingAd = true // 버튼 비활성화 및 로딩 표시
        
        adManager.showAd {
            // 보상 지급 콜백
            self.giveReward()
            self.isWatchingAd = false
        }
        
        // [안전장치] 만약 광고 호출 자체가 실패했을 경우를 대비해 2초 후 강제 해제
        // (정상 실행 시에는 adManager의 delegate에서 상태를 관리하게 됩니다)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.isWatchingAd {
                self.isWatchingAd = false
            }
        }
    }
    
    // [추가] 보상 지급 로직 분리
    private func giveReward() {
        pref.lifeWater += adRewardAmount
        pref.lastAdDate = Date()
        self.now = Date() // 뷰 즉시 갱신
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
}
