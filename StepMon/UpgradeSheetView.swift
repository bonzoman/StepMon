import SwiftUI
import SwiftData
import UIKit
import Combine

struct UpgradeSheetView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var pref: UserPreference
    @State private var isWatchingAd = false // 광고 시청 상태
    @State private var now = Date() // 쿨타임 실시간 갱신용
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let adRewardAmount = 50 // 광고 보상량
    let coolDownTime: TimeInterval = 600 // 10분 (600초)
  
    // 상태에 따른 안내 문구 로직
    var statusMessage: String {
        if pref.isSuperUser {
            return "슈퍼유저 모드: 생명수 소모 없이 즉시 레벨업"
        } else if pref.lifeWater >= 10 {
            // [수정] 나무와 일꾼 모두 만렙인 경우 안내 문구 변경
            if pref.treeLevel >= 100 && pref.workerLevel >= 100 {
                return "모든 정원 관리가 완료되었습니다!"
            }
            return "버튼을 눌러 생명수를 주입하세요."
        } else {
            return "생명수가 부족해요!"
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 5) {
                        Text("💧 보유 생명수")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                        
                        Text("\(pref.lifeWater)")
                            .font(.system(size: 36, weight: .black, design: .rounded))
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
                        // 생명수가 부족하면 빨간색으로 경고, 아니면 회색
                            .foregroundStyle((!pref.isSuperUser && pref.lifeWater < 10) ? .red : .secondary)
                            //.padding(.top, 5)
                    }
                    //.padding(.top, 10)

                    
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
                .padding()
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
        }
    }
    
    // --- [하단 고정 플로팅 바 뷰 블록] ---
    private var adFloatingBar: some View {
        let lastAd = pref.lastAdDate ?? Date.distantPast
        let timeElapsed = now.timeIntervalSince(lastAd)
        let isCoolDownActive = timeElapsed < coolDownTime

        return VStack(spacing: 0) {
            Divider() // 구분선
            
            VStack(spacing: 8) {
                Button(action: { simulateAdReward() }) {
                    HStack {
                        if isWatchingAd {
                            ProgressView().tint(.white).padding(.trailing, 5)
                            Text("광고 시청 중...")
                        } else if isCoolDownActive {
                            let remaining = Int(coolDownTime - timeElapsed)
                            Image(systemName: "timer")
                            Text("(광고) \(remaining / 60)분 \(remaining % 60)초")
                        } else {
                            Image(systemName: "play.tv.fill")
                            Text("광고 보고 \(adRewardAmount) 💧 받기")
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isWatchingAd || isCoolDownActive ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(isWatchingAd || isCoolDownActive)
                .padding(.horizontal, 20)
                .padding(.top, 12)                
                .padding(.bottom, 12) // 기본 패딩만 주면 시스템이 알아서 하단 홈 바(Safe Area)와 겹치지 않게 밀어줍니다.
            }
            .background(.ultraThinMaterial) // 반투명 배경으로 리스트가 비쳐 보이게 처리
        }
        .transition(.move(edge: .bottom))
        .onReceive(timer) { _ in self.now = Date() }
    }
    
    
    // UpgradeRow 컴포넌트
    @ViewBuilder
    func UpgradeRow(title: String, level: Int, maxLevel: Int, imageName: String, buttonColor: Color, totalCost: Int, currentInvest: Int, action: @escaping () -> Void) -> some View {
        
        let isMax = level >= maxLevel // 만렙 여부 확인
        
        HStack {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .background(Circle().fill(buttonColor.opacity(0.1)))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                HStack {
                    Text(isMax ? "MAX" : "Lv.\(level)") // 만렙시 MAX 표시
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(currentInvest) / \(totalCost)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.gray)
                }
                
                // 만렙이면 게이지를 꽉 채움
                ProgressView(value: isMax ? 1.0 : Double(currentInvest), total: isMax ? 1.0 : Double(totalCost))
                    .progressViewStyle(.linear)
                    .tint(isMax ? .orange : buttonColor)
            }
            
            Spacer()
            
            Button(action: action) {
                VStack {
                    if isMax {
                        Image(systemName: "checkmark.seal.fill")
                        Text("완료")
                            .font(.caption2)
                            .bold()
                    } else if pref.isSuperUser {
                        Text("UP")
                            .font(.headline)
                            .bold()
                    } else {
                        Image(systemName: "drop.fill")
                        Text("10")
                            .font(.caption)
                            .bold()
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .frame(minWidth: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(isMax ? .gray : buttonColor) // 만렙시 회색 버튼
            .disabled(isMax || (!pref.isSuperUser && pref.lifeWater < 10)) // 만렙시 비활성화


        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
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
    
    // 버튼 색상 결정 함수
    private func getButtonColor(_ watching: Bool, _ cooling: Bool) -> Color {
        if watching || cooling { return .gray }
        return .blue
    }

    // 광고 시청 시뮬레이션 함수
    private func simulateAdReward() {
        isWatchingAd = true
        
        // 20년 차 선배님께 익숙한 비동기 처리 (3초 후 보상)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            pref.lifeWater += adRewardAmount
            
            //광고 시청 시간 기록 (이게 있어야 쿨타임이 작동합니다)
            pref.lastAdDate = Date()
            
            isWatchingAd = false
            
            // 햅틱 피드백 추가
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}
