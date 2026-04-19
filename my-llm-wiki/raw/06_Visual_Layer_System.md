# [기획 06] VN 레이어 구조와 Godot 씬 구성

## 1. 목표

현재 프로젝트의 본편 씬은 `하나의 Stage Panel` 이 아니라 명시적인 VN 레이어 구조를 가진다.  
이 구조는 일반 장면과 CG 장면을 같은 씬 안에서 안정적으로 전환하기 위한 것이다.

## 2. 현재 씬 계층

현재 [godot-novel-maker/scenes/novel_scene.tscn](../godot-novel-maker/scenes/novel_scene.tscn) 기준 권장 구조는 다음과 같다.

```text
NovelScene
|- BackgroundLayer
|- CharacterLayer
|  |- LeftSlot
|  |- CenterSlot
|  |- RightSlot
|- CgLayer
|- FxLayer
|- UiLayer
|  |- TopBar
|  |- VnDialogLayer          ← 대사창 + 입력창 (기획 11 참고)
|     |- SpeakerRow
|     |- DialogBox
|     └─ PlayerInputPanel
|- OverlayLayer
```

## 3. 레이어 역할

### 3.1 BackgroundLayer

- 일반 배경 렌더링
- `layered` 와 `cg` 모두에서 기본 베이스 역할

### 3.2 CharacterLayer

- `left`, `center`, `right` 슬롯만 사용
- `layered` 모드에서만 표시

### 3.3 CgLayer

- 이벤트 CG 전용 레이어
- `cg` 모드에서만 표시

### 3.4 FxLayer

- 화면 효과 전용
- shake, flash, dim, vignette 같은 후처리 연출 확장 지점

### 3.5 UiLayer

- 상태 스트립 (`TopBar`)
- VN 대사창 (`VnDialogLayer` — 화자탭, 메세지박스, 타이핑 이펙트)
- 플레이어 입력창 (대사창 하단, 클릭 시 세로 확장)
- 버튼
- 설정 패널 진입점

→ 상세 구조는 [기획 11 — VN 스타일 대사창 & 플레이어 입력 UI](./11_VN_Dialog_Scene.md) 참고

### 3.6 OverlayLayer

- 검은 화면 전환, 시스템 메시지, 장면 마스크 등 상위 오버레이

## 4. 모드별 표시 규칙

### 4.1 Layered 모드

- BackgroundLayer: 표시
- CharacterLayer: 표시
- CgLayer: 숨김

### 4.2 CG 모드

- BackgroundLayer: 유지 가능
- CharacterLayer: 숨김
- CgLayer: 표시

이 방식이면 CG 장면 후 일반 장면으로 복귀하기 쉽다.

## 5. 캐릭터 슬롯 정책

초기 버전은 자유 좌표계보다 고정 슬롯이 맞다.

현재 슬롯:

- `left`
- `center`
- `right`

장점:

- 백엔드 출력 enum 이 단순해짐
- UI 와 충돌 가능성이 줄어듦
- fallback 구현이 쉬움

현재 구현은 지원하지 않음:

- `far_left`
- `close_up`
- 자유 x/y 좌표
- 크기 비율 직접 지정

## 6. 상태 스트립

현재 씬에는 작은 상태 스트립이 있다.  
여기에는 다음 정보가 들어간다.

- 백엔드 모드
- 현재 location
- 현재 scene mode
- 최근 validation/fallback 메시지

이 스트립의 목적은 개발 중 디버깅이다.  
정식 버전에서는 숨기거나 개발자 모드로 이동할 수 있다.

## 7. 설정 패널 접근

현재는 본편 씬 안에서도 설정 패널을 열 수 있다.

이유:

- 실행 중 backend URL 수정 가능
- stub 모드 즉시 전환 가능
- 자산 라이브러리 재로드 가능

즉, 게임을 완전히 재시작하지 않고도 런타임 컨텍스트를 바꿀 수 있다.

## 8. 현재 fallback 연출

자산 문제는 치명 오류 대신 시각적 복구로 처리한다.

- 잘못된 배경: 이전 배경 유지
- 잘못된 스프라이트: 슬롯 비우기 또는 중립 fallback
- 잘못된 CG: layered 로 강등

이 규칙은 `NarrativeDirector` 와 `AssetLibrary` 가 함께 담당한다.

## 9. 확장 아이디어

다음 단계에서 추가할 수 있는 것:

- `AnimationPlayer` 기반 전환
- 입장/퇴장 애니메이션
- 립싱크 또는 눈깜빡임
- 상태 스트립 개발자 모드화
- 모바일 대응 UI 재배치

하지만 지금 우선순위는 레이어 확장보다 `백엔드 계약 고정` 이다.
