# [기획서 03] 실시간 비주얼 오케스트레이션 및 자산 선택 시스템

## 1. 시스템 개요
비주얼 출력은 AI 이미지 생성이 아니라, **유저가 업로드한 이미지 자산을 장면 문맥에 맞게 선택하는 시스템**으로 설계합니다.

이때 이미지는 두 가지 큰 출력 방식으로 나뉩니다.

1. **Layered Mode**
   - 일반 배경 + 캐릭터 스프라이트 조합
2. **CG Mode**
   - 특정 이벤트용 장면 일러스트 단독 출력

---

## 2. 자산 카테고리

### 2.1 Background
- 장소
- 시간대
- 날씨
- 분위기

예:
- `school_rooftop_day`
- `apartment_night_rain`

### 2.2 Character Sprite
- 캐릭터 ID
- 표정
- 포즈
- 의상
- 상태

예:
- `airi_uniform_smile_01`
- `airi_uniform_blush_01`
- `airi_pajama_tired_01`

### 2.3 Scene CG
- 특정 이벤트 장면용 일러스트
- 캐릭터와 구도, 분위기가 하나의 완성된 컷으로 묶여 있음

예:
- 고백 장면
- 전투 피니시
- 성인 장면
- 회상 컷

### 2.4 Overlay / FX
- 암전
- 빛 번짐
- 비네팅
- 화면 흔들림
- 혈흔 오버레이

---

## 3. 출력 모드 설계

### 3.1 Layered Mode
일반적인 미연시 플레이 화면입니다.

구성:
- 배경 1장
- 캐릭터 스프라이트 0~3장
- UI 대화창
- 선택적 FX

사용 장면:
- 평상시 대화
- 탐색
- 관계 형성
- 일상 이벤트

### 3.2 CG Mode
강조하고 싶은 이벤트 순간에 사용하는 장면 모드입니다.

구성:
- CG 1장
- 선택적 UI
- 선택적 오버레이/카메라 효과

사용 장면:
- 고백
- 키스
- 전투 절정
- 공포 연출
- 성인용 이벤트

---

## 4. 업로드 시 필요한 메타데이터

### 4.1 배경 메타데이터
- `background_id`
- `location`
- `time_of_day`
- `weather`
- `mood_tags`
- `rating`

### 4.2 캐릭터 스프라이트 메타데이터
- `sprite_id`
- `character_id`
- `expression`
- `pose`
- `outfit`
- `state_tags`
- `rating`

### 4.3 CG 메타데이터
- `cg_id`
- `event_type`
- `character_ids`
- `mood_tags`
- `required_flags`
- `blocked_flags`
- `rating`

CG는 특히 `required_flags`와 `rating` 분리가 중요합니다. 조건이 맞지 않으면 후보군에 올라오면 안 됩니다.

---

## 5. AI와 자산 라이브러리의 연결 방식
AI가 전체 자산을 직접 탐색하게 두지 않고, 엔진이 먼저 후보를 추린 뒤 그 안에서 선택하게 만듭니다.

흐름:
1. 게임 상태 확인
2. 현재 장면 유형 판단
3. 조건에 맞는 후보 자산 필터링
4. 후보 ID 목록을 AI에 전달
5. AI가 최종 선택
6. Asset Resolver가 선택 결과 검증
7. Renderer가 장면 반영

이 구조가 필요한 이유:
- 잘못된 자산 참조 방지
- 장면 일관성 유지
- 성인용/일반용 자산 분리 제어

---

## 6. 구조화 출력 예시

### 6.1 Layered Mode
```json
{
  "direction": {
    "scene_mode": "layered",
    "background_id": "school_rooftop_sunset",
    "character_states": [
      {
        "character_id": "airi",
        "sprite_id": "airi_uniform_blush_01",
        "position": "center"
      }
    ],
    "cg_id": null,
    "transition": "crossfade"
  }
}
```

### 6.2 CG Mode
```json
{
  "direction": {
    "scene_mode": "cg",
    "background_id": null,
    "character_states": [],
    "cg_id": "airi_confession_night_01",
    "transition": "fade_to_cg"
  }
}
```

---

## 7. Fallback 규칙
자산 시스템은 실패해도 플레이를 끊지 않는 방향이 중요합니다.

### 7.1 배경 누락
- 이전 배경 유지
- 없으면 기본 배경 사용

### 7.2 스프라이트 누락
- 해당 캐릭터를 숨기거나 기본 표정으로 대체

### 7.3 CG 누락
- `layered mode`로 되돌리고, 배경 + 스프라이트 조합으로 대체

### 7.4 rating 불일치
- 상위 수위 자산은 절대 하위 등급 장면에 노출하지 않음
- 조건을 만족하는 낮은 등급 자산만 재선택

---

## 8. 운영 아이디어
- 업로드 도구는 단순 파일 추가만이 아니라 **메타데이터 태깅 UI**가 핵심입니다.
- 성인용 자산은 별도 표시와 잠금이 필요합니다.
- 같은 장면에 대해 복수의 자산을 등록해두면, 엔진이 감정/관계 상태에 따라 다른 비주얼을 고를 수 있습니다.
- 장기적으로는 자동 태깅 보조 기능을 붙일 수 있지만, V1은 수동 태깅이 더 안전합니다.
