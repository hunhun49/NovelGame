# [기획서 06] 레이어 기반 비주얼 렌더링 및 AI 연동 시스템

## 1. 시스템 개요 (System Overview)
본 시스템은 정적인 통이미지 방식의 한계를 극복하고, **배경(Background)**, **캐릭터(Character)**, **이펙트(FX)**, **UI**를 독립된 레이어로 분리합니다. Gemini 3 Flash의 실시간 지시에 따라 각 레이어를 개별적으로 업데이트하여 역동적인 시각적 경험을 제공하는 것을 목적으로 합니다.

---

## 2. 레이어 스택 구조 (Layer Stack Architecture)

웹 브라우저의 `z-index`를 활용하여 아래 순서대로 레이어를 수직 적층합니다.

| 레이어 명칭 | Z-index | 역할 및 구성 요소 | 추천 포맷 |
| :--- | :--- | :--- | :--- |
| **0. Background** | `0` | 장소, 시간대(낮/밤), 날씨 배경 | WebP (80% Qual) |
| **1. Character** | `10` | 캐릭터 전신/상반신 (표정, 의상) | WebP (Transparent) |
| **2. Screen FX** | `20` | 비, 눈, 화면 흔들림, 비네팅, 블러 | CSS / Canvas |
| **3. UI / Dialog** | `30` | 대화창, 이름표, 선택지, 시스템 메뉴 | HTML / CSS |
| **4. Overlay** | `40` | 페이드 인/아웃, 암전, 연출용 텍스트 | HTML / CSS |

---

## 3. AI 데이터 연동 및 트리거 로직

Gemini 3에서 전달된 JSON 응답 데이터를 프론트엔드 상태 관리자(Store)가 해석하여 각 레이어의 `src`나 `class`를 업데이트합니다.

### 3.1 AI 출력 규격 (데이터 바인딩 예시)
```json
{
  "content": {
    "dialogue": "선배, 여기서 뭐 해요? 같이 가기로 했잖아요!"
  },
  "visual_args": {
    "background_id": "classroom_sunset",
    "character_id": "airi",
    "expression": "surprised",
    "transition_type": "crossfade",
    "camera_effect": "shake_light"
  }
}