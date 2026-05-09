# 백엔드 (StepMonPrj)

레포: `/Users/sjo/IdeaProjects/StepMonPrj`

## 스택

- Java 21 / Spring Boot 3.4.3 / Maven
- **MyBatis 3.0.3** (annotation 기반 SQL, JPA 미사용)
- MySQL 8 (DB 명: `g2mDB`)
- **Pushy 0.15.4** — APNs 클라이언트
- Spring Security (form login, session) — 관리자 페이지만
- Caffeine 캐시, Log4j2, Thymeleaf + HTMX (관리자 UI), SpringDoc OpenAPI
- telegrambots-spring-boot-starter — 모니터링 알림

## 패키지 구조

```
src/main/java/com/bnz/stepmon/
├── Application.java                # @SpringBootApplication, @EnableScheduling, TimeZone=UTC
├── biz/
│   ├── ApnsService.java            # 단건/배치 푸시
│   ├── DeviceService.java          # 등록/설정 변경 비즈
│   ├── PushScheduler.java          # 5분 주기 푸시 + 일일 정리
│   ├── auth/CustomUserDetailsService.java
│   └── spec/                       # DTO records (DeviceRegisterReqDto 등) + MyTelegramBot
├── config/
│   ├── SecurityConfig.java         # Form login, /api/** permitAll
│   ├── ApnsConfig.java             # Pushy ApnsClient bean
│   ├── ApnsProperties.java         # apns.* 프로퍼티 바인딩
│   ├── WebConfig.java
│   └── OpenApiConfig.java
├── controller/
│   ├── DeviceController.java       # /api/device/*
│   ├── ApnsController.java         # /api/apns/silent (수동 발송)
│   ├── AdminDeviceController.java  # /admin/devices (Thymeleaf+HTMX 대시보드)
│   ├── HealthController.java       # /health, /sendtel (텔레그램 테스트)
│   └── LoginController.java
├── domain/UserAccount.java         # 유일한 도메인 엔티티 (관리자 계정)
├── sql/
│   ├── DeviceQuery.java            # @Mapper, 인라인 SQL
│   └── UserAccountQuery.java
└── util/StringUtil.java
```

## DB 스키마

마이그레이션 도구 없음(Flyway/Liquibase 미사용). 수동 관리. **변경 시 OCI MySQL 에 직접 DDL 실행 필요.**

### `device_registration` (메인)

| 컬럼 | 타입 | 비고 |
|---|---|---|
| install_id | VARCHAR PK | 앱이 생성한 영구 UUID |
| device_token | VARCHAR | APNs 토큰 (갱신 가능) |
| is_notification_enabled | BOOL | |
| start_minutes / end_minutes | INT | 자정 기준 분 단위 알림창 |
| time_zone | VARCHAR | 예: `Asia/Seoul` |
| app_version | VARCHAR | |
| platform | VARCHAR | `iOS` 고정 (현재) |
| last_push_at | DATETIME | 마지막 푸시 시각 |
| push_fail_count | INT | 5 이상이면 자동 비활성 |
| is_active | BOOL | |
| deactivated_at / deactivated_reason | | 비활성 사유 추적 |
| first_seen_at / last_seen_at | DATETIME | |

도메인 객체 없음 — DTO 만 사용.

### `user_account` (관리자)

| 컬럼 | 비고 |
|---|---|
| user_id (PK), password (bcrypt), user_name, role, created_at, updated_at | |

도메인: [domain/UserAccount.java](file:///Users/sjo/IdeaProjects/StepMonPrj/src/main/java/com/bnz/stepmon/domain/UserAccount.java)

## API

base URL: `http://localhost:5555` (local) / `https://stepmon.stimi.xyz` (prod)

### iOS 클라이언트용 (인증 없음)

#### `POST /api/device/register`
디바이스 토큰 + 설정 upsert. `installId` 가 PK.
```json
{
  "installId": "UUID",
  "deviceToken": "hex-string",
  "isNotificationEnabled": true,
  "startMinutes": 480,
  "endMinutes": 1320,
  "timeZone": "Asia/Seoul",
  "platform": "iOS",
  "appVersion": "1.0.3",
  "sentAt": "2026-05-09T12:34:56Z"
}
```
응답: `DeviceResDto` (저장된 상태). 200 OK.

#### `POST /api/device/settings`
설정만 변경 (디바이스 토큰 미포함). 페이로드는 위에서 `deviceToken` 만 빠진 형태.

### 관리자/디버그용

| 메서드 | 경로 | 용도 |
|---|---|---|
| GET | `/health` | 헬스체크 |
| GET | `/sendtel` | 텔레그램 알림 테스트 |
| POST | `/api/apns/silent` | 수동으로 silent push 발송 (관리자) |
| GET | `/admin/devices` | 디바이스 검색 대시보드 (Thymeleaf) |
| GET/POST | `/admin/devices/table[/search]` | HTMX 테이블 fragment |
| GET | `/login`, `/logout` | 로그인 폼 |
| GET | `/swagger-ui.html`, `/v3/api-docs/**` | API 문서 |

## 스케줄러 (`PushScheduler`)

- **`schedulePush()`** — fixedDelay 5분, initialDelay 5분. `findPushTargets()` 결과 전체에 silent push 발송. `AtomicBoolean` 으로 중복 실행 방지.
- **`dailyCleanup()`** — 매일 03:00 UTC. `last_seen_at` > 90일 디바이스 비활성화.
- **헬스체크 모니터** — 10분 주기로 메인 스케줄러가 살아있는지 확인. 10분 이상 멈췄으면 알림 + 자동 재시도.
- 실패 시 텔레그램으로 알림.

## 인증 (`SecurityConfig`)

- `/api/**` → permitAll (CSRF disabled — iOS 호환)
- 그 외 → authenticated, form login (`/login`)
- HTMX 호환: `HX-Redirect` 헤더로 리다이렉트
- 비밀번호 인코더: `DelegatingPasswordEncoder` (디폴트 bcrypt)
- HTTPS 는 OCI LB 가 종단. LB↔인스턴스는 평문 HTTP. `server.forward-headers-strategy: native` (prod)
- **`/health` 는 반드시 permitAll** — LB 헬스체크 경로. 막으면 LB 가 인스턴스를 unhealthy 처리해 서비스 중단

## 설정 프로필

기본 active: `local`. 프로덕션 컨테이너에서는 `-Dspring.profiles.active=prod` (Dockerfile).

| 키 | local | prod |
|---|---|---|
| `server.port` | 5555 | 5555 |
| `spring.datasource.url` | localhost:3306/g2mDB | env `SPRING_DATASOURCE_URL` (mysql-db:3306, Docker 내부) |
| `spring.datasource.username/password` | g2m / g2m1!g2m2@ (하드코딩) | env |
| `apns.use-sandbox` | true | false |
| `apns.team-id` / `key-id` / `key-path` | 동일 (`keys/AuthKey_M48CNFDVZQ.p8`) | 동일 (단 path 는 `/keys/...` — Docker 마운트) |
| `telegram.bot.token` / `chat.id` | 테스트 봇/채널 | env (운영 봇/채널) |

설정 파일:
- [application.yml](file:///Users/sjo/IdeaProjects/StepMonPrj/src/main/resources/application.yml)
- [application-local.yml](file:///Users/sjo/IdeaProjects/StepMonPrj/src/main/resources/application-local.yml)
- [application-prod.yml](file:///Users/sjo/IdeaProjects/StepMonPrj/src/main/resources/application-prod.yml)

## 외부 자원

- **APNs 키**: `keys/AuthKey_M48CNFDVZQ.p8` (PKCS#8). 로컬 레포에 커밋되어 있음. 운영 컨테이너는 `/home/ubuntu/stepmon/keys` 를 `/keys` 로 마운트.
- **텔레그램 봇 토큰**: 환경 변수 `TELEGRAM_BOT_TOKEN`.
- **DB 비밀번호**: 환경 변수 `DB_PASS_VAR` → `SPRING_DATASOURCE_PASSWORD`.

## 빌드 / 로컬 실행

```bash
# 빌드
mvn clean package -DskipTests

# 로컬 실행
mvn spring-boot:run -Dspring-boot.run.arguments="--spring.profiles.active=local"

# 또는 jar 직접
java -Dspring.profiles.active=local -jar target/StepMon-0.0.1-SNAPSHOT.jar
```

전제: 로컬 MySQL 8, `g2mDB` 생성, 사용자 `g2m`/`g2m1!g2m2@`. 스키마는 OCI 의 운영 DB 에서 dump 후 import 추천.

## 작업 시 주의

- **DTO 는 record** — 새 필드 추가 시 record 시그니처 변경 → 모든 호출부/검증 어노테이션 동시 수정.
- **DDL 변경**: 마이그레이션 도구 없음. 직접 OCI MySQL 에 적용 + 로컬 DB 동기화.
- **APNs 키 만료**: 키 자체에는 만료 없음(영구). 단 키 파일이 바뀌면 `application-*.yml` 의 `apns.key-id` + 파일도 같이 교체.
- **`/api/**` 는 항상 permitAll** — 인증 추가하면 iOS 클라가 깨짐.
- **timezone 처리** — DB 와 서버 둘 다 UTC. 알림창은 디바이스가 보낸 `time_zone` 으로 변환해서 비교.
- `findPushTargets` SQL 변경 시 **테스트 데이터로 사전 검증 필수**. 잘못 손대면 새벽 푸시·미알림 사고로 직결.
