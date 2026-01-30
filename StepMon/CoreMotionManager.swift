//
//  CoreMotionManager.swift
//  StepMon
//  CoreMotion(CMPedometer) 연동 담당
//  - 아이폰의 모션 프로세서를 통해 직접 걸음 수를 가져옵니다.
//
//  Created by 오승준 on 1/27/26.
//

import Foundation
import CoreMotion

// Swift의 싱글턴(singleton) 패턴 예시.
// Java에서는 보통 `private static final CoreMotionManager INSTANCE = new CoreMotionManager();`처럼 작성합니다.
// Swift에서는 `static let shared`로 단일 인스턴스를 제공하는 것이 관례입니다.
class CoreMotionManager {
    static let shared = CoreMotionManager()
    // CMPedometer는 iOS의 걸음 수 센서 API입니다. (Java의 센서 매니저와 유사한 역할)
    private let pedometer = CMPedometer()
    
    // 생성자를 private으로 막아 외부에서 새 인스턴스를 못 만들게 합니다.
    // Java의 `private CoreMotionManager()`와 같은 의미입니다.
    private init() {}
    
    // 1. 권한 확인 및 가용성 체크
    func checkAvailability() -> Bool {
        // Swift는 `return`을 간결하게 표현할 수 있지만, 여기서는 명시적으로 유지합니다.
        return CMPedometer.isStepCountingAvailable()
    }
    
    // 2. 특정 기간(과거~현재)의 걸음 수 조회 (백그라운드 작업용)
    // CoreMotion은 쿼리 방식이 매우 빠르며 최근 데이터 반영이 즉각적입니다.
    // completion은 비동기 콜백입니다.
    // Java에서는 `interface Callback { void onResult(int steps); }`를 정의하고 전달하는 방식과 유사합니다.
    // `@escaping`은 콜백이 함수 밖으로 "탈출"하여 나중에 실행될 수 있음을 컴파일러에 알리는 키워드입니다.
    func querySteps(from start: Date, to end: Date, completion: @escaping (Int) -> Void) {
        guard checkAvailability() else {
            print("❌ 기기에서 걸음 수 측정을 지원하지 않습니다.")
            completion(0)
            return
        }
        
        // 클로저(closure)는 Java의 람다와 유사합니다.
        pedometer.queryPedometerData(from: start, to: end) { data, error in
            if let error = error {
                print("CoreMotion 쿼리 에러: \(error.localizedDescription)")
                completion(0)
                return
            }
            
            // Optional 체이닝(`data?`)과 nil 병합 연산자(`??`)는
            // Java에서의 null 체크 + 기본값 처리 로직을 간결하게 표현합니다.
            let steps = data?.numberOfSteps.intValue ?? 0
            completion(steps)
        }
    }
    
    // 3. 실시간 걸음 수 업데이트 (UI용 - 앱이 켜져있을 때 사용)
    // startUpdates를 사용하면 걸을 때마다 콜백이 옵니다.
    func startMonitoring(from start: Date, updateHandler: @escaping (Int) -> Void) {
        guard checkAvailability() else { return }
        
        pedometer.startUpdates(from: start) { data, error in
            guard let data = data, error == nil else { return }
            
            let steps = data.numberOfSteps.intValue
            updateHandler(steps)
        }
    }
    
    // 모니터링 중지
    func stopMonitoring() {
        pedometer.stopUpdates()
    }
}
