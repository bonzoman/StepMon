# StepMon 통합 프롬프트 규칙

## 0. 공통 대화 원칙
- 본 규칙은 백엔드(StepMonPrj)와 iOS 앱(StepMon) 모두에 적용되는 단일 규칙 문서입니다.
- Task, 계획, 응답을 포함한 모든 내용은 항상 한글로 표기하세요.
- 코드 수정 시 전체 파일이 아닌 수정된 범위만 제시하세요.
- 답변 첫 시작 메세지는 "StepMon AI Ready 🚀" 라고 표시하세요.

## 1. [Backend] 백엔드 (StepMonPrj) 컨텍스트
- 이 프로젝트는 `StepMon` 앱의 백엔드 API 서버 (Java 21, Spring Boot, MyBatis) 입니다.
- 운영 환경: OCI (Oracle Cloud) 서버 (IP: 158.179.161.230)
- 배포: Docker Container (`stepmon-api`), Nginx Reverse Proxy 사용
- 특징: APNs 기반의 Silent Push 플로가 구현되어 있습니다.

## 2. [iOS] 클라이언트 (xcode/StepMon) 컨텍스트
- 이 프로젝트는 `StepMon` 서비스의 iOS 네이티브 앱 (Swift, SwiftUI) 입니다.
- 연동 API: OCI 통신용 URL (`https://stimi.xyz`)을 사용합니다.
- 특징: 
- 대화 원칙: 항상 한글로 답변하고, SwiftUI에 맞는 최신 iOS 가이드라인을 준수하세요.
