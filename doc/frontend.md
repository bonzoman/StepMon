# iOS 앱 (StepMon)

레포: `/Users/sjo/xcode/StepMon`

## 스택

- Swift / SwiftUI / iOS 18.6+ deployment target
- **SwiftData** (로컬 영속), HealthKit, CoreMotion(`CMPedometer`), WidgetKit, BackgroundTasks
- **Google Mobile Ads SDK** (SPM) — 보상형 광고
- 외부 라이브러리 최소화. 네트워킹은 순수 `URLSession` (async/await).

## 타겟 / 번들 ID

| 타겟 | 번들 ID | 비고 |
|---|---|---|
| StepMon (앱 본체) | `com.bnz.StepMon` (prod) / `com.bnz.StepMon.debug` (debug) | |
| StepMonWidgetExtension | `com.bnz.StepMon.StepMonWidget` | App Group `group.com.bnz.stepmon` 공유 |
| StepMonTests / UITests | — | |

Capabilities: Push Notifications, Background Modes(remote-notification, background-fetch, background-processing), HealthKit, App Groups.
Entitlements 파일: [StepMon/StepMon.entitlements](../StepMon/StepMon.entitlements)

## 폴더 구조 (핵심만)

`StepMon/` 아래 평탄 구조. 그룹화 안 되어 있고 파일명으로 역할 구분.

| 파일 | 역할 |
|---|---|
| [StepMonApp.swift](../StepMon/StepMonApp.swift) | `@main`, AppDelegate, APNs 등록, ATT 동의, AdMob init |
| [UserPreference.swift](../StepMon/UserPreference.swift) | SwiftData 모델 3종 (`UserPreference`, `NotificationHistory`, `AppLogEntry`) |
| [ContentView.swift](../StepMon/ContentView.swift) | 메인 홈 (걸음 수 + 진척도) |
| [SettingsView.swift](../StepMon/SettingsView.swift) | 알림/임계값/시간대 설정 |
| [GardenView.swift](../StepMon/GardenView.swift) | 정원 게임 화면 |
| [StepHistoryView.swift](../StepMon/StepHistoryView.swift) / [NotificationHistoryView.swift](../StepMon/NotificationHistoryView.swift) | 통계·이력 |
| [LogViewerView.swift](../StepMon/LogViewerView.swift) | 디버그 로그 (superuser only) |
| [CoreMotionManager.swift](../StepMon/CoreMotionManager.swift) | `CMPedometer` 래퍼 (실시간/구간 쿼리) |
| [HealthKitManager.swift](../StepMon/HealthKitManager.swift) | HealthKit 권한 + N일치 걸음 fetch |
| [BackgroundStepManager.swift](../StepMon/BackgroundStepManager.swift) | BGTask 등록·핸들러, silent push 처리, 임계 미달 시 로컬 알림 |
| [DeviceTokenUploader.swift](../StepMon/DeviceTokenUploader.swift) | `/api/device/register` 호출 |
| [DeviceSettingsUploader.swift](../StepMon/DeviceSettingsUploader.swift) | `/api/device/settings` 호출 |
| [ServiceConfig.swift](../StepMon/ServiceConfig.swift) | DEBUG/RELEASE 백엔드 URL 분기 |
| [RewardedAdManager.swift](../StepMon/RewardedAdManager.swift) | AdMob 보상형 광고 |
| [AppLog.swift](../StepMon/AppLog.swift) | SwiftData 기반 로그 (300건 트림) |

## 데이터 모델 (SwiftData)

- **`UserPreference`** — 단 1행. 설정(임계값, 체크간격 30/60/90/120분, 알림창 start/endMinutes) + 게임 상태(정원/나무/일꾼 레벨, 물 재화).
- **`NotificationHistory`** — 체크 이벤트 1건/행. `timestamp`, `steps`, `threshold`, `notified`, `source`(`bgTask`/`silentPush`/`fg`).
- **`AppLogEntry`** — 디버그 로그. 색상 코드(normal/red/yellow/gray/green/blue) 포함, 300건 초과 시 자동 삭제.

UserDefaults 에 별도 보관:
- `bnz.stepmon.installId` (UUID, 영구)
- `bnz.stepmon.deviceToken` (마지막 업로드된 토큰 — 중복 업로드 방지)
- `bnz.stepmon.pendingDeviceReg` / `pendingDeviceSettings` (실패 시 재시도용)
- App Group `group.com.bnz.stepmon` → 위젯이 읽는 걸음 수

## 네트워킹 규칙

- timeout 8s, 재시도 5회 (지수 백오프 1·2·4·8·16s + 0~300ms 지터).
- 모든 페이로드 JSON, `Content-Type: application/json`.
- 실패는 silent fail + UserDefaults 에 pending 으로 보관해서 다음 트리거 때 재시도.
- 자세한 페이로드 스펙은 [backend.md#api](backend.md#api) 참조.

## 백그라운드/포그라운드 분리

| 상태 | 사용 API | 동작 |
|---|---|---|
| Foreground | `CMPedometer.startUpdates` | 실시간 UI 업데이트 |
| Background (BGTask) | `CMPedometer.queryPedometerData` 1회 | `bnz.stepmon.stepcheck.refresh`, OS 가 ~15분+ 단위로 깨움 |
| Background (silent push) | 동일 | 서버가 깨움. 즉시 체크. |

체크 후 `notified` 결정 로직:
- 직전 알림으로부터 15분 미만 → 스킵
- 현재 시각이 알림창 밖 → 스킵
- 임계 미달 → 로컬 알림 발송 + 기록

## 빌드 / 실행

```bash
# 시뮬레이터
xcodebuild -scheme StepMon -destination "platform=iOS Simulator,name=iPhone 16"
# 실기기
xcodebuild -scheme StepMon -destination "generic/platform=iOS"
```

서명: 자동 (팀 ID 사용, `.xcconfig` 없음). 프로비저닝 프로파일 없이 Xcode 가 자동 처리.

DEBUG 로컬 백엔드 사용 시:
1. 맥북에서 백엔드 `local` 프로필로 띄움 (port 5555).
2. iPhone 실기기와 같은 Wi-Fi.
3. [ServiceConfig.swift](../StepMon/ServiceConfig.swift) 의 `192.168.0.50` 을 본인 맥 IP 로 수정 (또는 그대로 매칭되게 IP 설정).

## 작업 시 주의

- **App Group 공유 키 변경 금지** — 위젯이 깨짐. `group.com.bnz.stepmon` 그대로 유지.
- **BGTask Identifier 변경 시** — Info.plist `BGTaskSchedulerPermittedIdentifiers` 와 `registerBackgroundTask` 호출부 양쪽 수정 필요.
- **신규 SwiftData 모델 추가** — `ModelContainer` 스키마에 등록 필수 (`StepMonApp.swift`).
- **`AppLog` 는 메인 스레드 외에서 호출 금지** — actor isolation 보장 안 됨. 비동기 컨텍스트면 `Task { @MainActor in ... }`.
- 광고 SDK 초기화는 ATT 동의 후에만 의미 있음 — 순서 바꾸면 광고 매칭률 하락.
