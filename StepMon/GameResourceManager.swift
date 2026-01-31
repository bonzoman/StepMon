import Foundation

struct GameResourceManager {
    
    // --- [이미지 파일명 반환] ---
    
    // 나무: 총 23단계 이미지 (main_tree_1 ~ main_tree_23)
    static func getMainTreeImage(level: Int) -> String {
        let index = getTreeImageIndex(level: level)
        return "main_tree_\(index)"
    }
    
    // 일꾼: 10단계 이미지 (main_worker_1 ~ main_worker_10)
    // 1~100레벨을 10구간으로 나누어 매핑
    static func getMainWorkerImage(level: Int) -> String {
        let stage = min(max((level - 1) / 10 + 1, 1), 10)
        return "main_worker_\(stage)"
    }
    
    // --- [알고리즘: 구간별 이미지 인덱스 계산] ---
    
    // Lv 1~29 (10단위) -> Lv 30~59 (5단위) -> Lv 60~100 (3단위)
    static func getTreeImageIndex(level: Int) -> Int {
        switch level {
        case 0..<30:
            // [구간 1] Lv 1, 11, 21 ... (총 3장)
            // 인덱스: 1, 2, 3
            return (level / 10) + 1
            
        case 30..<60:
            // [구간 2] Lv 30, 35, 40 ... (총 6장)
            // 인덱스: 4 ~ 9
            return 4 + ((level - 30) / 5)
            
        default:
            // [구간 3] Lv 60, 63, 66 ... (총 14장)
            // 인덱스: 10 ~ 23
            let calculated = 10 + ((level - 60) / 3)
            return min(calculated, 23) // 최대 23번 이미지 고정
        }
    }
    
    // --- [알고리즘: 미세 성장용 진행률 계산] ---
    
    // 현재 이미지가 유지되는 구간 안에서 몇 % 성장했는지 (0.0 ~ 0.99)
    // 이 값을 GardenView에서 scaleEffect에 사용하여 나무를 조금씩 키움
    static func getLevelProgressInStep(level: Int) -> Double {
        switch level {
        case 0..<30:
            // 10레벨 동안 0.0 -> 1.0 도달
            return Double(level % 10) / 10.0
        case 30..<60:
            // 5레벨 동안 0.0 -> 1.0 도달
            return Double((level - 30) % 5) / 5.0
        default:
            // 3레벨 동안 0.0 -> 1.0 도달
            return Double((level - 60) % 3) / 3.0
        }
    }
    
    // --- [팝업용 아이콘 (기존 유지)] ---
    static func getTreeImageName(level: Int) -> String {
        switch level {
        case 0...29: return "tree_phase_1"
        case 30...59: return "tree_phase_2"
        default: return "tree_phase_3"
    }
    }
    
    static func getWorkerImageName(level: Int) -> String {
        switch level {
        case 0...29: return "worker_phase_1"
        case 30...59: return "worker_phase_2"
        default: return "worker_phase_3"
        }
    }
    
    // 효율 계산 (기존 유지)
    static func getWorkerEfficiency(level: Int) -> Double {
        return 1.0 + (Double(level) * 0.01)
    }
}
