# 운영 / 배포 / 로컬 개발

## 환경 매핑

| 구성요소 | 로컬 (맥북) | 운영 (OCI) |
|---|---|---|
| 백엔드 호스트 | localhost | OCI 컴퓨트 `Stepmon-API` |
| 도메인 | `192.168.0.50:5555` | `https://stepmon.stimi.xyz` → OCI LB → 인스턴스:5555 (직접) |
| 백엔드 실행 | `mvn spring-boot:run` | Docker 컨테이너 `stepmon-api` |
| Spring 프로필 | `local` | `prod` |
| MySQL | 로컬 MySQL 8 :3306 | 컨테이너 `mysql-db` (MySQL 8.0), Docker network `mysql_default` |
| APNs | Sandbox | Production |
| iOS 빌드 | Xcode DEBUG | Xcode RELEASE / TestFlight / App Store |

## OCI 운영

### 인스턴스 / 인프라

| | 값 |
|---|---|
| 인스턴스명 | `Stepmon-API` |
| Shape | `VM.Standard.A1.Flex` (3 OCPU, 18GB RAM, **ARM64**) |
| OS | Ubuntu 22.04 aarch64 |
| 리전 / AD | `ap-chuncheon-1` / `mYmY:AP-CHUNCHEON-1-AD-1` |
| VCN / 서브넷 | `vcn-stepmon` (10.0.0.0/16) / `subnet-stepmon` (10.0.0.0/24) |
| Load Balancer | `stimi_lb` (Flexible 10Mbps), 공인 IP **`158.179.161.230`** |
| TLS | LB 에 와일드카드 `*.stimi.xyz` 인증서. 80→443 리다이렉트. **LB↔인스턴스 사이는 평문 HTTP** |
| SSH | `ssh -i ssh-key-2026-03-01.key ubuntu@158.179.161.230` |

운영 사용자: `ubuntu`. 운영 디렉터리: `/home/ubuntu/stepmon/keys/` (APNs `.p8` → 컨테이너 `/keys` 마운트).

### LB 라우팅 (Routing Policy: `Stimi_Routing_Policy`)

| Host 헤더 | Backend Set | 도착지 |
|---|---|---|
| `stepmon.stimi.xyz` | `StepMon_BS` (= `bs_lb_2026-0305-1419`) | 인스턴스:**5555** (Spring Boot 직접) |
| `creator.stimi.xyz` | `StimiCreator_BS` | 인스턴스:**5556** (별도 서비스) |
| `stimi.xyz` / `www.stimi.xyz` | `Stimi_Homepage_BS` | 인스턴스:**80** (Nginx 정적 홈페이지) |
| 그 외 (Default) | `StepMon_BS` | :5555 |

**LB 헬스체크**: `GET :5555/health` (HTTP). Spring Security 에서 `permitAll` 필수 — 막으면 LB 가 인스턴스를 unhealthy 로 떨어뜨려 서비스 중단됨.

### 같은 호스트에 함께 사는 컨테이너

Docker daemon 공유. 모두 `restart: always`.

| 컨테이너 | 이미지 | 포트 | 용도 |
|---|---|---|---|
| `stepmon-api` | 자체 빌드 | 5555 | 우리 백엔드 |
| `stimicreator-api` | 자체 빌드 | 5556 | 별도 서비스 |
| `mysql-db` | mysql:8.0 | 3306 (외부 노출) | DB. `~/mysql/data` 영속 |
| `nginx-proxy` | nginx:latest | 80, 443 | `stimi.xyz` 정적 HTML 만 서빙. **API 프록시 안 함** |
| `gitlab` | gitlab/gitlab-ce | 3030, 2222 | self-hosted GitLab (메모리 ~6GB) |
| `gitlab-runner` | gitlab/gitlab-runner | — | 도커 executor (`docker.sock` 마운트) |

> 주의: 배포로 인한 디스크 누적이 stepmon/stimicreator 양쪽 daemon 공유 영향. CI 의 `docker image prune` + `builder prune --until=72h` 가 그 대책.

### MySQL (`mysql-db`)

- 호스트 볼륨: `~/mysql/data`(영속), `~/mysql/conf.d`(my.cnf), `~/mysql/logs`
- 설정: `utf8mb4` / `utf8mb4_unicode_ci`, `innodb_buffer_pool_size=1G`, `max_connections=150`, `TZ=Asia/Seoul`
- 외부 접속: 3306 보안목록 오픈 (DBeaver/IntelliJ 로 직접 접속 가능)
- 사용자: `g2m@%` (비번은 GitLab CI 변수 `DB_PASS_VAR` 와 일치해야 함), DB: `g2mDB`

### GitLab (self-hosted)

- Web: `http://158.179.161.230:3030` (root 계정)
- Git remote: `ssh://git@158.179.161.230:2222/bonzoman/stepmonprj.git`
- GitHub mirror: `https://github.com/bonzoman/StepMonPrj.git` (로컬에서 양쪽 push)
- Runner 기본 이미지: `maven:3.9.6-eclipse-temurin-21`
- CI 변수: `DB_PASS_VAR`, `TELEGRAM_BOT_TOKEN` (Settings > CI/CD > Variables)

### Docker 구성

- 이미지: 멀티스테이지 (maven 21 → temurin 21 JRE).
- 런타임 옵션: `-XX:+UseZGC -Xmx512m -Dspring.profiles.active=prod`.
- 컨테이너명: `stepmon-api`. 항상 `--restart always`.
- 네트워크: `mysql_default` (외부 정의). `mysql-db` 컨테이너에 같은 네트워크로 접근.
- 포트 매핑: `5555:5555`.
- 마운트: `/home/ubuntu/stepmon/keys:/keys`.

### 배포 (GitLab CI, 수동)

`.gitlab-ci.yml` 파이프라인 — `build` → `deploy` (deploy 는 `when: manual`).

GitLab UI 에서 [Build > Pipelines] → ▶️ 클릭으로 배포.

deploy 가 하는 일:
1. 기존 `stepmon-api` 컨테이너 강제 제거.
2. 새 이미지로 `docker run` (위 옵션 그대로).
3. `docker image prune -f` — dangling 이미지 정리.
4. `docker builder prune -f --filter until=72h` — 72시간 초과 빌드 캐시 정리. (실패 무시)

CI 에 등록된 환경 변수:
- `DB_PASS_VAR` — MySQL `g2m` 비밀번호
- `TELEGRAM_BOT_TOKEN` — 운영 텔레그램 봇

### 무중단 X

현재 단일 컨테이너 + 강제 재시작. 배포 시 수 초간 다운타임 있음.

iOS 클라는 실패 시 자체 재시도(지수 백오프)가 있어서 짧은 다운타임은 흡수됨. 단 스케줄러는 그 동안 안 돌아감 (5분 주기라 큰 문제 없음).

## 모니터링

별도 APM 없음. 텔레그램 봇이 유일한 알림 채널.

`MyTelegramBot` 으로 보내는 이벤트:
- 서버 시작/종료
- 스케줄러 실패 / 10분 이상 멈춤 → 자동 재시작
- 일일 정리 결과
- 임의의 예외 (try-catch 하는 위치에 한함)

수동 헬스체크: `GET /health` , 텔레그램 테스트: `GET /sendtel`.

로그: Log4j2 → 컨테이너 stdout. `docker logs stepmon-api -f` 로 확인.

## 로컬 개발 환경 (맥북)

### 필요한 것

- Xcode 16 이상 (iOS 18.6 SDK)
- JDK 21 (Temurin 권장)
- Maven 3.9+
- MySQL 8 (Homebrew: `brew install mysql`)
- (선택) Docker Desktop — 컨테이너 빌드 검증용

### 1회 셋업

```bash
# MySQL 시작
brew services start mysql

# DB / 사용자 생성
mysql -u root <<SQL
CREATE DATABASE g2mDB DEFAULT CHARSET utf8mb4;
CREATE USER 'g2m'@'localhost' IDENTIFIED BY 'g2m1!g2m2@';
GRANT ALL ON g2mDB.* TO 'g2m'@'localhost';
SQL

# 스키마: OCI MySQL 에서 mysqldump --no-data 로 DDL 받아 import 권장.
```

### 백엔드 실행

```bash
cd /Users/sjo/IdeaProjects/StepMonPrj
mvn spring-boot:run -Dspring-boot.run.arguments="--spring.profiles.active=local"
```

→ `http://localhost:5555` 노출. Swagger UI: `http://localhost:5555/swagger-ui.html`.

iOS 실기기에서 접근하려면 맥북 IP 가 `192.168.0.50` 이거나, [ServiceConfig.swift](../StepMon/ServiceConfig.swift) 의 DEBUG URL 을 본인 IP 로 수정.

### iOS 빌드

```bash
cd /Users/sjo/xcode/StepMon
open StepMon.xcodeproj
# Xcode 에서 StepMon 스킴 선택 → 시뮬레이터 또는 실기기 빌드
```

푸시 알림은 **시뮬레이터에선 동작 안 함** (APNs 토큰 발급 안 됨). 푸시 플로우는 실기기 필수.

### Docker 로 백엔드 검증 (선택)

```bash
cd /Users/sjo/IdeaProjects/StepMonPrj
docker compose up --build
```

`docker-compose.yml` 은 운영용으로 작성됨 (`mysql_default` 네트워크 외부 의존, env 변수 필요). 로컬에서 그대로 쓰려면 네트워크/환경변수 손봐야 함.

## 자주 하는 운영 작업

### 디바이스 비활성 해제 / 푸시 강제 발송

- 관리자 로그인 → `/admin/devices` 에서 검색·관리.
- 단건 수동 푸시: `POST /api/apns/silent` (페이로드는 `ApnsController` 참고).

### DB 스키마 변경

1. 로컬에서 DDL 작성 → 적용해서 검증.
2. 백엔드 코드 변경 + 빌드 검증.
3. **OCI MySQL 에 직접 DDL 실행** (마이그레이션 도구 없음).
4. GitLab pipeline 수동 배포.

### APNs 키 갱신

1. Apple Developer 에서 새 `.p8` 발급 (Key ID 메모).
2. 로컬: `keys/AuthKey_<NEW>.p8` 추가, `application-*.yml` 의 `apns.key-id` + `key-path` 수정.
3. 운영: 새 파일을 `/home/ubuntu/stepmon/keys/` 에 scp + 재배포.
4. 구 키는 일정 기간 보관 후 Apple 콘솔에서 revoke.

### 백엔드 URL 변경 (도메인)

iOS 앱 [ServiceConfig.swift](../StepMon/ServiceConfig.swift) 수정 → RELEASE 빌드 후 App Store 또는 TestFlight 재배포 필수. 백엔드만 바꿔서는 적용 안 됨.

### 알림이 안 온다는 사용자 문의 대응

체크 순서:
1. `/admin/devices` 에서 install_id 또는 device_token 검색.
2. `is_active`, `is_notification_enabled`, `push_fail_count` 확인.
3. `last_seen_at` 이 30일 초과면 푸시 대상에서 제외됨 → 앱 재실행 유도.
4. `push_fail_count >= 5` 면 자동 비활성. 토큰 재등록 필요 (앱 재실행 시 자동).
5. 알림창(`start_minutes`/`end_minutes`) 과 디바이스 timezone 이 맞는지.
6. 그래도 안 되면 `POST /api/apns/silent` 로 단건 발송 후 `last_push_at` 갱신 여부 확인.

## 보안 주의

- `application-local.yml` 에 DB 비밀번호 하드코딩되어 있음. 레포 공개 금지 (현재 self-hosted GitLab).
- APNs `.p8` 키도 레포에 포함됨. 같은 이유.
- prod 비밀번호/토큰은 GitLab CI 변수로만 주입됨. 컨테이너에는 환경변수로만 존재.
- 관리자 페이지는 form login + bcrypt — 비밀번호 정기 교체 권장.
