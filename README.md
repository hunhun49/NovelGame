# Project Infinite Persona

> **A Godot-based local AI visual novel engine with real-time text generation and user-supplied art assets.**

---

## About This Project
**Infinite Persona**는 고정 스크립트 분기형 미연시가 아니라, 플레이어가 정의한 세계관과 캐릭터 페르소나를 바탕으로 매 턴 서사를 생성하는 **로컬 실행형 AI 비주얼 노벨 엔진**입니다.

이 프로젝트의 핵심은 다음 두 가지를 분리하는 것입니다.

1. **실시간 생성되는 것:** 텍스트, 장면 지시, 상태 변화
2. **사전에 준비되는 것:** 배경, 캐릭터 스프라이트, 장면 CG, UI, 사운드

즉, AI는 이미지를 새로 만드는 대신 유저가 업로드한 자산 라이브러리에서 현재 장면에 맞는 요소를 선택하고, 엔진은 이를 전통적인 미연시 문법에 맞게 출력합니다.

---

## Core Experience
- **실시간 서사 생성:** 선택지 고정형이 아닌 자유 입력 기반 전개
- **무한한 페르소나:** 캐릭터 말투, 관계 거리, 감정 반응을 동적으로 유지
- **자산 오케스트레이션:** 배경/스탠딩/CG를 상황에 따라 전환
- **타임라인 플레이:** 대화 흐름, 상태 변화, 장면 전환을 세이브 단위로 되돌리기

---

## Product Direction

### 1. Godot 기반 로컬 클라이언트
- 브라우저 우선 구조 대신 **Godot 데스크톱 실행 파일**을 기본 타깃으로 합니다.
- 저장/불러오기, 유저 자산 관리, 레이어 연출, 로컬 파일 접근을 안정적으로 처리합니다.

### 2. 텍스트만 실시간 생성
- AI는 `narration`, `dialogue`, `action`과 같은 텍스트와 장면 지시용 JSON만 생성합니다.
- 이미지 생성은 범위에서 제외합니다.

### 3. 유저 업로드 자산 기반 비주얼 출력
- 일반 장면은 **배경 + 캐릭터 스프라이트** 조합으로 출력합니다.
- 중요한 이벤트 장면은 **장면 CG** 단독 출력 모드로 전환합니다.
- AI는 현재 컨텍스트와 후보 자산 목록을 보고 적절한 자산 ID를 선택합니다.

### 4. 로컬 우선 AI 연결
- 1차 목표는 로컬 또는 자체 호스팅 텍스트 생성 백엔드와의 연동입니다.
- 필요 시 외부 API 어댑터를 둘 수 있으나 제품 구조는 외부 API 종속을 전제로 하지 않습니다.

---

## Scope of Version 1
- Godot 4 기반 데스크톱 클라이언트
- 캐릭터/세계관/플레이어 설정 입력
- 실시간 텍스트 생성 및 스트리밍 출력
- 배경/스프라이트/CG 자산 업로드와 태깅
- JSON 기반 장면 제어
- 오토세이브, 수동 세이브, 타임라인 롤백
- BGM/SFX 레이어 제어
- 성인용 콘텐츠를 고려한 등급/자산 분리 구조

---

## Non-Goals for Version 1
- 실시간 AI 이미지 생성
- 브라우저 우선 서비스 운영
- 멀티플레이어
- 자동 결제/상점/과금 시스템
- 완전 자동 자산 분류

---

## Proposed Tech Direction
- **Engine:** Godot 4
- **Primary Scripting:** GDScript
- **AI Backend:** local REST/WebSocket adapter
- **Data:** JSON first, SQLite optional for scale-up
- **Assets:** user-managed local library with metadata

백엔드는 구체적으로 다음 중 하나를 연결할 수 있도록 추상화하는 방향을 가정합니다.
- 로컬 모델 서버
- 자체 Python 서비스
- 필요 시 선택적 외부 API 어댑터

---

## Documentation Map
- [docs/01_Prompt_Congnition_Arch.md](docs/01_Prompt_Congnition_Arch.md): AI 인지 및 출력 구조
- [docs/02_Dynamic_Voice_Design.md](docs/02_Dynamic_Voice_Design.md): 캐릭터 화법 설계
- [docs/03_Visual_Orchestration.md](docs/03_Visual_Orchestration.md): 자산 선택과 장면 연출
- [docs/04_Narrative_Memory_System.md](docs/04_Narrative_Memory_System.md): 서사 기억과 정합성 유지
- [docs/05_Web_Infra_Optimization.md](docs/05_Web_Infra_Optimization.md): Godot 로컬 런타임과 성능 방향
- [docs/06_Visual_Layer_System.md](docs/06_Visual_Layer_System.md): 레이어 렌더링 구조
- [docs/07_Sound_Orchestration.md](docs/07_Sound_Orchestration.md): 오디오 제어 설계
- [docs/08_Save_History_Management.md](docs/08_Save_History_Management.md): 세이브 및 히스토리 관리
- [docs/09_Anti_Filter_Safety_Mechanism.md](docs/09_Anti_Filter_Safety_Mechanism.md): 성인용 운영 정책과 콘텐츠 가드레일

---

## License
This project is licensed under the MIT License.
