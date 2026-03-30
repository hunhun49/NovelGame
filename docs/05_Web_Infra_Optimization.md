# [기획서 05] 고성능 웹 배포 환경 및 비용/성능 최적화

## 1. 프론트엔드 연출 아키텍처
- **Framework:** Next.js 15+ (App Router).
- **State Management:** Zustand 또는 상태 기반 라이브러리를 통한 실시간 스탯 반영.
- **Text Streaming:** Server-Sent Events(SSE) 기술을 적용하여 글자가 써지는 동안에도 배경음악(BGM)과 효과음(SFX)이 동기화되도록 설계.

## 2. 백엔드 및 AI 파이프라인
- **Runtime:** Node.js 에지 런타임 사용으로 지연 시간 최소화.
- **Gemini Tiering:** - 기본 대화/묘사: **Gemini 3 Flash** (비용 절감, 속도).
  - 복잡한 플롯 분석/이미지 생성 프롬프트 정제: **Gemini 3 Pro** (고도의 추론).
  - 이미지 생성: **Gemini 3.1 Flash Image** (가성비 일러스트).

## 3. 운영 및 안전 (Safety & Scaling)
- **Safety Filter:** 유저가 입력한 설정이 서비스 운영 가이드라인을 위반하는지 Gemini의 세이프티 세팅으로 1차 필터링.
- **Caching Strategy:** 동일한 세계관 설정에 대한 반복 질문은 Redis 캐시를 활용하여 API 호출 비용 절감.