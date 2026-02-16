import Foundation

enum InstallIdManager {
    private static let key = "bnz.stepmon.installId"

    static var installId: String {
        if let v = UserDefaults.standard.string(forKey: key), !v.isEmpty {
            return v
        }
        let v = UUID().uuidString
        UserDefaults.standard.set(v, forKey: key)
        return v
    }
}
