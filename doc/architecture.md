# 시스템 아키텍처

## 큰 그림

```
┌────────────────────┐  HTTPS   ┌──────────────┐   HTTP   ┌──────────────────────┐
│  iOS App (StepMon) │ ───────▶ │  OCI LB      │ ───────▶ │  Spring Boot API     │
│  - SwiftUI         │ stepmon. │  stimi_lb    │  :5555   │  (Docker stepmon-api)│
│  - SwiftData       │ stimi.   │  *.stimi.xyz │  (직접)  │  Ubuntu 22.04 aarch64│
│  - HealthKit       │ xyz:443  │  TLS 종단    │          │                      │
│  - CoreMotion      │          └──────────────┘          │  ┌────────────────┐ │
│  - WidgetKit       │                                    │  │ MyBatis        │ │
└────────┬───────────┘                                    │  └────┬───────────┘ │
         │                                                │       ▼              │
         │   APNs silent push                             │  ┌────────────────┐ │
         │   (content-available:1)                        │  │ mysql-db (8.0) │ │
         │ ◀──────────  Apple APNs  ◀──────────────────── │  │  g2mDB         │ │
         │                                                │  └────────────────┘ │
         │                                                │  ┌────────────────┐ │
         │                                                │  │ Pushy (APNs)   │ │
         │                                                │  │ Telegram Bot   │ │
         │                                                │  └────────────────┘ │
         │                                                └──────────────────────┘
         │
         │  사용자가 앱에서 직접: BG App Refresh 자체 트리거
         ▼
   걸음 수 체크 → 임계 미달 시 로컬 알림
```

**LB 라우팅**: 호스트 헤더 기반. `stepmon.stimi.xyz` → :5555 (이 서비스). `creator.stimi.xyz` → :5556 (별도). `stimi.xyz`/`www` → Nginx :80 (정적 홈페이지). Nginx 는 API 프록시가 아님. 자세한 매핑은 [operations.md](operations.md#lb-라우팅-routing-policy-stimi_routing_policy).

## 데이터 플로우 (핵심 시나리오)

### 1) 앱 최초 실행 / APNs 토큰 갱신
1. iOS가 `application:didRegisterForRemoteNotificationsWithDeviceToken` 발생.
2. `DeviceTokenUploader` → `POST /api/device/register` 호출.
3. 페이로드: `installId`(앱 영구 UUID), `deviceToken`, 알림창(start/endMinutes), `timeZone`, `appVersion`.
4. 실패 시 UserDefaults `bnz.stepmon.pendingDeviceReg` 에 보관 → 다음 기회에 재시도(지수 백오프).

### 2) 사용자가 설정 변경
1. `SettingsView` 에서 알림 ON/OFF·시간대 변경.
2. `DeviceSettingsUploader` → `POST /api/device/settings` 호출 (디바이스 토큰 미전송, installId만으로 식별).
3. 동일 페일오버 정책.

### 3) 백엔드 스케줄 푸시 (서버 주도 체크)
1. `PushScheduler.schedulePush()` 가 5분마다 실행 (UTC 기준).
2. `DeviceQuery.findPushTargets()` 가 푸시 대상 조회:
   - `is_active = true`
   - `is_notification_enabled = true`
   - 현재 시각이 디바이스 `timeZone` 기준 알림창 안에 있음
   - `last_seen_at` 30일 이내, `push_fail_count < 5`
3. Pushy 라이브러리로 APNs silent push 일괄 발송. 페이로드: `{aps:{content-available:1}, reason:"stepcheck"}`.
4. 실패 시 `push_fail_count` 증가, 5회 누적 시 `deactivate`.

### 4) 앱이 silent push 수신 (핵심)
1. iOS 가 백그라운드에서 `application:didReceiveRemoteNotification:fetchCompletionHandler:` 깨움.
2. `BackgroundStepManager.handleSilentPush()` 호출.
3. `CoreMotion`(또는 fallback `HealthKit`)으로 직전 체크 이후 ~ 현재 걸음 수 조회.
4. `UserPreference.stepThreshold` 미달이면 **로컬 알림** 발송 (서버는 콘텐츠 전송 안 함, 트리거만 함).
5. 결과를 `NotificationHistory` 에 기록 (source = `silentPush`).

### 5) BG App Refresh (앱 주도 체크)
- 동일한 체크 로직을 OS 가 임의 간격(~15분 이상) 으로 깨워서 실행.
- `BGTaskIdentifier = bnz.stepmon.stepcheck.refresh`.
- 소스 = `bgTask` 로 기록.
- 백엔드 푸시가 실패해도 자체적으로 동작 (이중화).

### 6) 위젯
- 앱이 걸음 수를 App Group `group.com.bnz.stepmon` 의 UserDefaults 에 50보 단위로 갱신.
- WidgetKit 가 그것을 읽어 락스크린/홈스크린에 표시.

## 인증 모델

- **API (`/api/**`) — 인증 없음.** `installId` 만으로 디바이스 식별. 토큰은 단순 식별자.
- **관리자 페이지 (`/`, `/admin/**`) — Form Login (Spring Security session).** `user_account` 테이블 기반.
- iOS 앱에는 사용자 계정 개념 자체가 없음.

## 환경 분기

| | DEBUG 빌드 | RELEASE 빌드 |
|---|---|---|
| 앱 → 백엔드 URL | `http://192.168.0.50:5555` (사내 맥북) | `https://stepmon.stimi.xyz` |
| APNs | Sandbox | Production |
| 백엔드 프로필 | `local` | `prod` |
| 백엔드 위치 | 맥북 로컬 | OCI VM (Docker) |

자세한 설정은 [operations.md](operations.md) 참조.

## 결정 / 트레이드오프 메모

- **JPA가 아닌 MyBatis** — 인서트/배치 푸시 타겟 쿼리 같은 건 단순 SQL이 명확. 도메인 객체도 거의 없음(DTO만).
- **JWT/OAuth 안 씀** — 사용자 계정이 없으니 불필요. installId 가 사실상 디바이스의 영구 식별자.
- **Silent push 만 보내고 콘텐츠는 로컬에서** — 서버가 사용자 걸음 수를 모름. 프라이버시 + 단순성. 단, APNs 전달 실패율이 곧 알림 누락이라 BG App Refresh 로 이중화.
- **Telegram 봇 모니터링** — 별도 APM 없이 스케줄러 실패/시작/배치 결과를 텔레그램으로 푸시. 1인 운영 환경 최적.
