import SwiftUI
import SwiftData

struct GardenView: View {
    @Bindable var pref: UserPreference
    
    @State private var showUpgradeSheet = false
    @State private var isPulsing = false
    @State private var workerOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 10) {
            
            // --- [메인 조립 스테이지] ---
            ZStack(alignment: .bottom) {

                // 1. 배경 (하늘)
                Circle()
                    .fill(LinearGradient(colors: [.blue.opacity(0.15), .green.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 300, height: 300)
                
                // 2. 바닥 (땅)
                Ellipse()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 260, height: 50)
                    .offset(y: -10)
                
                // 3. 중앙 나무 (성장 로직 적용)
                let progress = GameResourceManager.getLevelProgressInStep(level: pref.treeLevel)
                
                Image(GameResourceManager.getMainTreeImage(level: pref.treeLevel))
                    .resizable()
                    .scaledToFit()
                    // [기본 성장] 레벨이 오르면 기본 덩치도 커짐
                    .frame(width: 180 + CGFloat(pref.treeLevel / 2))
                    
                    // [미세 성장] 다음 이미지 교체 전까지 15% 정도 부풀어 오름 (Interpolation)
                    // 예: Lv.1(1.0배) -> Lv.5(1.07배) -> Lv.9(1.13배) -> Lv.10(이미지 교체 & 1.0배 리셋)
                    .scaleEffect(isPulsing ? (1.03 + (progress * 0.15)) : (1.0 + (progress * 0.15)))
                    
                    // [그림자] 나무가 커지면 그림자도 진해짐
                    .shadow(color: .black.opacity(0.1 + (progress * 0.05)), radius: 10, x: 0, y: 10)
                    .offset(y: -40)
                    .zIndex(2)
                    // 부드러운 애니메이션
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: pref.treeLevel)
                
                // 4. 일꾼들 (기존 유지)
                ForEach(0..<getWorkerCount(level: pref.workerLevel), id: \.self) { index in
                    workerView(at: index)
                }
            }
            .frame(height: 320)
            .onAppear {
                // 숨쉬기 애니메이션
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
                // 일꾼 움직임
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    workerOffset = 5
                }
            }
            
            // --- [버튼 구역] ---
            VStack(spacing: 10) {
                Text("Lv.\(pref.treeLevel) 생명의 숲")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.secondary)
                
                Button(action: { showUpgradeSheet = true }) {
                    Label("가꾸기", systemImage: "leaf.fill")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(.green)
                .shadow(radius: 3)
            }
        }
        .padding()
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeSheetView(pref: pref)
                .presentationDetents([.fraction(0.7)])
                .presentationDragIndicator(.visible)
        }
    }
    
    // 일꾼 수 계산 (기존 로직 유지)
    func getWorkerCount(level: Int) -> Int {
        if level < 5 { return 1 }
        if level < 15 { return 2 }
        if level < 30 { return 3 }
        if level < 50 { return 4 }
        return 5
    }

    // 일꾼 뷰 조립 (기존 로직 유지)
    @ViewBuilder
    func workerView(at index: Int) -> some View {
        let positions: [(x: CGFloat, y: CGFloat, z: Double)] = [
            (80, 10, 3), (-80, 5, 3), (110, -20, 1), (-110, -15, 1), (0, 20, 4)
        ]
        let pos = positions[index % positions.count]
        
        Image(GameResourceManager.getMainWorkerImage(level: pref.workerLevel))
            .resizable()
            .scaledToFit()
            .frame(width: 70)
            .shadow(color: .black.opacity(0.1), radius: 3)
            .offset(x: pos.x, y: pos.y - (index % 2 == 0 ? workerOffset : -workerOffset))
            .zIndex(pos.z)
    }
}
