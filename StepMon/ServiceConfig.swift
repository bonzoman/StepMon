import Foundation

struct ServiceConfig {
    #if DEBUG
    // 로컬 개발 서버 (MacBook IP)
    nonisolated static let baseURL = "http://192.168.0.50:5555"
    #else
    // OCI 운영 서버 (OCL LB)
    nonisolated static let baseURL = "https://stepmon.stimi.xyz" //"http://158.179.161.230"
    #endif

    nonisolated static let deviceRegisterURL = "\(baseURL)/api/device/register"
    nonisolated static let deviceSettingsURL = "\(baseURL)/api/device/settings"
}
