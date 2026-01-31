import SwiftUI
import SwiftData
import UIKit // Haptic 피드백을 위해 필요

struct UpgradeSheetView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var pref: UserPreference
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) { // 전체 간격 25 -> 20으로 축소
                    
                    // [상단] 보유 생명수 + 안내 문구 (통합 및 축소)
                    VStack(spacing: 5) { // 내부 간격 타이트하게
                        Text("💧 보유 생명수")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                        
                        Text("\(pref.lifeWater)")
                            .font(.system(size: 36, weight: .black, design: .rounded)) // 폰트 40 -> 36 축소
                            .foregroundStyle(.blue)
                            .contentTransition(.numericText())
                        
                        if pref.isSuperUser {
                            Text("⚡️ SUPER USER ACTIVE ⚡️")
                                .font(.caption2)
                                .fontWeight(.black)
                                .foregroundStyle(.orange)
                        }
                        
                        // [이동됨] 하단에 있던 안내 문구를 여기로 배치
                        Text(pref.isSuperUser ? "슈퍼유저 모드: 생명수 소모 없이 즉시 레벨업" : "버튼을 눌러 생명수를 주입하세요 (1회당 10)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 5)
                    }
                    .padding(.top, 10) // 상단 여백 축소
                    
                    Divider()
                    
                    // 1. 만보기 나무
                    let treeCost = getCost(level: pref.treeLevel)
                    UpgradeRow(
                        title: "만보기 나무",
                        level: pref.treeLevel,
                        imageName: GameResourceManager.getMainTreeImage(level: pref.treeLevel),
                        buttonColor: .green,
                        totalCost: treeCost,
                        currentInvest: pref.treeInvestment
                    ) {
                        invest(target: .tree, totalCost: treeCost)
                    }
                    
                    // 2. 비트몬 일꾼
                    let workerCost = getCost(level: pref.workerLevel)
                    UpgradeRow(
                        title: "비트몬 일꾼",
                        level: pref.workerLevel,
                        imageName: GameResourceManager.getMainWorkerImage(level: pref.workerLevel),
                        buttonColor: .blue,
                        totalCost: workerCost,
                        currentInvest: pref.workerInvestment
                    ) {
                        invest(target: .worker, totalCost: workerCost)
                    }
                    
                    // 일꾼 효율 설명 (심플 버전)
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text("일꾼 레벨이 오르면 걸음당 생명수 획득 효율이 증가합니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20) // 하단 여백 확보
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("정원 관리소")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
    
    // UpgradeRow 컴포넌트
    @ViewBuilder
    func UpgradeRow(title: String, level: Int, imageName: String, buttonColor: Color, totalCost: Int, currentInvest: Int, action: @escaping () -> Void) -> some View {
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
                    Text("Lv.\(level)")
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(currentInvest) / \(totalCost)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.gray)
                }
                
                ProgressView(value: Double(currentInvest), total: Double(totalCost))
                    .progressViewStyle(.linear)
                    .tint(buttonColor)
            }
            
            Spacer()
            
            Button(action: action) {
                VStack {
                    if pref.isSuperUser {
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
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .frame(minWidth: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(buttonColor)
            .disabled(!pref.isSuperUser && pref.lifeWater < 10)
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
}
