# [기획서 06] 레이어 기반 비주얼 렌더링 및 Godot 씬 구조

## 1. 시스템 개요
비주얼 노벨 화면은 단일 이미지 표시가 아니라, 여러 레이어가 합성된 결과물입니다. 본 프로젝트는 Godot에서 이를 명시적으로 분리하여 관리합니다.

목표:
- 일반 장면과 CG 장면을 모두 자연스럽게 출력
- 레이어 전환과 이펙트를 독립적으로 제어
- UI와 연출 로직을 분리

---

## 2. 권장 씬 트리 방향
구체적인 클래스 설계 전 단계에서는 아래 정도의 씬 구성을 가정합니다.

```text
NovelRoot
|- BackgroundLayer
|- CharacterLayer
|- CgLayer
|- FxLayer
|- UiLayer
|- OverlayLayer
```

설명:
- `BackgroundLayer`: 장소/시간/날씨 배경
- `CharacterLayer`: 스탠딩 캐릭터
- `CgLayer`: 장면 CG
- `FxLayer`: 비네팅, 흔들림, 파티클
- `UiLayer`: 대화창, 선택지, 이름표
- `OverlayLayer`: 암전, 페이드, 장면 텍스트

---

## 3. 출력 모드별 레이어 동작

### 3.1 Layered Mode
- `BackgroundLayer`: visible
- `CharacterLayer`: visible
- `CgLayer`: hidden

### 3.2 CG Mode
- `BackgroundLayer`: optional or dimmed
- `CharacterLayer`: hidden
- `CgLayer`: visible

이렇게 분리하면 CG 장면 이후 다시 일반 장면으로 복귀하기 쉽습니다.

---

## 4. 캐릭터 배치 규칙
초기 버전은 자유 좌표 배치보다 **고정 슬롯 방식**이 현실적입니다.

추천 슬롯:
- `left`
- `center`
- `right`

장점:
- AI가 복잡한 좌표를 생성할 필요가 없음
- 자산과 UI의 충돌이 줄어듦
- VN 문법에 익숙한 화면 구성 유지

장기적으로는 `left_far`, `center_close` 같은 세분화도 가능합니다.

---

## 5. 해상도 및 기준 화면
V1 기준 권장 방향:
- 기준 해상도: `1920x1080`
- 비율: `16:9`
- UI는 스케일 대응
- CG와 배경은 16:9 기준 제작 권장

이유:
- 데스크톱 VN에 가장 무난함
- 자산 제작 기준을 통일하기 쉬움

---

## 6. 전환 효과
전환은 엔진 고유 문법으로 제한하는 편이 좋습니다.

추천 enum:
- `cut`
- `fade`
- `crossfade`
- `fade_to_cg`
- `cg_to_layered`
- `flash`

AI는 enum만 선택하고, 실제 애니메이션은 Godot에서 처리합니다.

---

## 7. 카메라 및 화면 효과
미연시에서는 실제 3D 카메라보다 **화면 연출 효과**가 더 중요합니다.

예:
- `shake_light`
- `shake_heavy`
- `zoom_in_soft`
- `vignette_dark`
- `blur_focus`

이 값들은 `FxLayer`에서 처리합니다.

---

## 8. 누락 자산 대응
렌더러는 자산이 없을 때도 항상 화면을 유지해야 합니다.

원칙:
- 배경 누락: 이전 배경 유지
- 스프라이트 누락: 해당 캐릭터만 비표시
- CG 누락: 일반 장면 모드로 폴백
- FX 누락: 효과 없이 진행

---

## 9. 구현 아이디어
- 전환 효과는 `AnimationPlayer` 기반으로 시작하면 단순합니다.
- 슬롯형 캐릭터 배치는 `Control` 기반 앵커 또는 `Node2D` 기준 둘 다 가능하지만, UI와 함께 다루기 쉬운 쪽으로 통일하는 것이 좋습니다.
- 화면 모드 전환은 렌더러가 직접 판단하지 말고, `NarrativeDirector`가 결정한 값을 그대로 따르는 구조가 깔끔합니다.
