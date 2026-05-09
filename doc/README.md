# StepMon 프로젝트 문서

다른 세션에서 이 폴더만 보고 추가/수정 작업을 시작할 수 있도록 정리한 핵심 문서.

## 구성

- [architecture.md](architecture.md) — 시스템 전체 구조, 앱↔서버 데이터 플로우, 핵심 시퀀스
- [frontend.md](frontend.md) — iOS 앱 (`/Users/sjo/xcode/StepMon`)
- [backend.md](backend.md) — Spring Boot 백엔드 (`/Users/sjo/IdeaProjects/StepMonPrj`), DB 스키마, API 계약
- [operations.md](operations.md) — OCI 운영, 배포(GitLab CI), 로컬 개발 환경, 모니터링

## 한 줄 요약

**StepMon** = 만보계 게이미피케이션 iOS 앱. 일일 걸음 수 목표 달성을 정원 게임으로 보상.
**StepMonPrj** = APNs silent push 트리거용 Spring Boot 백엔드. 디바이스 토큰 등록/스케줄 푸시.

## 두 레포 위치

| 역할 | 경로 | 비고 |
|---|---|---|
| iOS 앱 | `/Users/sjo/xcode/StepMon` | Xcode, SwiftUI + SwiftData |
| 백엔드 | `/Users/sjo/IdeaProjects/StepMonPrj` | Spring Boot 3.4 / Java 21 / MyBatis |

## 문서 작성 원칙

- 변경 시 **이 폴더 안에서 갱신**. CLAUDE.md에 길게 적지 말 것.
- 코드를 보면 알 수 있는 것(파일 목록, 메서드 시그니처)은 적지 않음. **왜·언제·어디서 시작할지**만.
- 절대 경로와 클래스명은 명시. 검색 가능해야 함.
