import SwiftUI
import SwiftData

struct GardenView: View {
    @Bindable var pref: UserPreference
    
    @State private var showUpgradeSheet = false
    @State private var isPulsing = false
    @State private var workerOffset: CGFloat = 0

    // [추가] 터치 효과를 위한 상태 변수
    @State private var bigSplashID = UUID()
    @State private var smallSplashID = UUID()
    @State private var showSplash: Bool = false
    @State private var showBigSplash: Bool = false
    @State private var floatingText: String? = nil
    @State private var floatingOffset: CGFloat = 0
    @State private var floatingOpacity: Double = 0
    private var treeIndex: Int {
        GameResourceManager.getTreeImageIndex(level: pref.treeLevel)
    }

    var body: some View {
        GeometryReader { geometry in // [추가] 부모 뷰의 크기 정보 가져오기
            let availableWidth = geometry.size.width
            
            // 이미지 너비 계산
            let calculatedWidth: CGFloat = {
                let baseWidth: CGFloat = 180
                if treeIndex >= 13 {
                    let growthStep = CGFloat(treeIndex - 13)
                    // availableWidth(화면 너비)를 기준으로 최대 크기 제한
                    return min(baseWidth + (growthStep * 25), availableWidth * 1.2)
                } else {
                    return baseWidth
                }
            }()

            VStack(spacing: 10) {
                
                // --- [메인 조립 스테이지] ---
                ZStack(alignment: .bottom) {
                    // 화면 너비를 동적으로 가져오기 위한 배경 레이어
                    GeometryReader { geometry in
                        Color.clear.onAppear { /* 너비 확보용 */ }
                    }
                    
                    // 1. 배경 (하늘)
                    Circle()
                        .fill(LinearGradient(colors: [.blue.opacity(0.15), .green.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 300, height: 300)
                    
                    // 2. 바닥 (땅)
                    Ellipse()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: treeIndex >= 13 ? 300 : 260, height: 50) // 땅도 조금 넓혀줌
                        .offset(y: -10)

                    // 3. 중앙 나무
                    Image(GameResourceManager.getMainTreeImage(level: pref.treeLevel))
                        .resizable()
                        .scaledToFit()
                    // [기본 성장] 레벨이 오르면 기본 덩치도 커짐
                        .frame(width: calculatedWidth) // 계산된 너비 적용
                        .scaleEffect(isPulsing ? 1.03 : 1.0)// 숨쉬기
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 10)
                    //.offset(y: -40)
                        .offset(y: treeIndex >= 13 ? -10 : -30)//나무가 아무리 커져도 바닥(땅) 근처에 머물도록 고정값 또는 작은 비율 적용
                        .zIndex(2)
                        .overlay {
                            // [핵심] .id(UUID)를 통해 터치할 때마다 새로운 뷰로 인식시켜 애니메이션 강제 재생
                            if showBigSplash {
                                SplashEffectView(isBig: true, isSuper: pref.isSuperUser)
                                    .id(bigSplashID)
                            }
                            if showSplash {
                                SplashEffectView(isBig: false, isSuper: false)
                                    .id(smallSplashID)
                            }
                            // [추가] 플로팅 보상 텍스트
                            if let text = floatingText {
                                Text(text)
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .foregroundStyle(.blue)
                                    .offset(y: floatingOffset)
                                    .opacity(floatingOpacity)
                            }
                        }
                    // [추가] 터치 이벤트
                        .onTapGesture {
                            handleTreeTap()
                        }
                    //.animation(.spring(response: 0.6, dampingFraction: 0.7), value: pref.treeLevel)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6), value: treeIndex)
                    
                    
                    // 4. 일꾼들 (기존 유지)
                    ForEach(0..<getWorkerCount(level: pref.workerLevel), id: \.self) { index in
                        workerView(at: index)
                    }
                }
                // [핵심] ZStack에 유연한 높이를 부여하여 나무가 커질 때 잘리지 않게 함
                .frame(height: 350 + (treeIndex >= 13 ? CGFloat(treeIndex - 13) * 7 : 0))
                
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
            // [해결 3] GeometryReader 내부에서 가로 중앙 정렬 보장
            .frame(width: availableWidth)
        }
        // 전체 뷰의 높이가 콘텐츠에 맞춰 늘어나도록 설정
        .frame(height: 460 + (treeIndex >= 13 ? CGFloat(treeIndex - 13) * 8 : 0))
    }
    

    
    // [추가] 나무 터치 로직: 1시간 1회 랜덤 보상
    private func handleTreeTap() {
        let now = Date()
            
        // Binding 에러 방지를 위해 값을 상수에 담기
        let lastWin = pref.lastWinDate ?? Date.distantPast
        
        // 슈퍼유저라면 무조건 true, 일반 유저라면 1시간(3600초) 체크
        let canWin = pref.isSuperUser || now.timeIntervalSince(lastWin) >= 3600
        
        if canWin {
            // 🎉 [대박 당첨] 30, 40, 50 중 랜덤
            let rewards = [30, 40, 50]
            let bonus = rewards.randomElement() ?? 30
            pref.lifeWater += bonus
            pref.lastWinDate = now
            
            // 플로팅 텍스트 실행
            showFloatingText(amount: bonus)
            
            bigSplashID = UUID()
            showBigSplash = true
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                showBigSplash = false
            }
        } else {
            smallSplashID = UUID()
            // 💧 [일반 터치] 효과만 발생
            showSplash = true
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showSplash = false
            }
        }
    }

    
    func showFloatingText(amount: Int) {
        floatingText = "+\(amount)"
        floatingOffset = -50
        floatingOpacity = 1.0
        
        withAnimation(.easeOut(duration: 0.8)) {
            floatingOffset = -150 // 위로 솟구침
            floatingOpacity = 0 // 사라짐
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            floatingText = nil
        }
    }
    
    struct SplashEffectView: View {
        @State private var animate = false
        var isBig: Bool
        var isSuper: Bool
        
        var body: some View {
            ZStack {
                ForEach(0..<(isSuper ? 35 : (isBig ? 20 : 8)), id: \.self) { i in
                    Image(systemName: "drop.fill")
                        .foregroundStyle(isSuper ? .yellow : (isBig ? .cyan : .blue.opacity(0.8)))
                        .font(.system(size: isSuper ? CGFloat.random(in: 15...28) : (isBig ? 18 : 10)))
                        .offset(y: animate ? (isSuper ? -130 : (isBig ? -110 : -60)) : 0)
                        .rotationEffect(.degrees(Double(i) * (isSuper ? 10.2 : (isBig ? 18 : 45))))
                        .scaleEffect(animate ? 2.0 : 1.0)
                        .opacity(animate ? 0 : 1)
                }
            }
            .onAppear {
                // 연타를 위해 아주 빠른 duration(0.4~0.5초) 적용
                withAnimation(.easeOut(duration: isSuper ? 0.4 : 0.5)) {
                    animate = true
                }
            }
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
