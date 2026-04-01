# [기획 01] Godot 클라이언트와 AI 백엔드 계약

## 1. 목적

이 문서는 현재 구현된 Godot 클라이언트가 어떤 JSON 계약으로 백엔드와 통신하는지 정리한다.

중요한 전제:

- 현재 저장소에는 백엔드 서버 구현이 없다.
- 따라서 클라이언트 단독 개발 단계에서는 `stub backend` 가 기본 개발 경로다.
- 실제 서버를 붙일 때는 이 문서의 계약을 그대로 맞춰야 한다.

## 2. 현재 클라이언트 역할

Godot 클라이언트는 다음 역할을 맡는다.

- 플레이어 입력 수집
- 현재 상태와 최근 대화 정리
- 현재 상태에 맞는 자산 후보군 필터링
- 백엔드에 턴 생성 요청 전송
- 응답 JSON 검증
- 잘못된 자산 ID에 대해 fallback 적용
- VN 레이어 렌더링

즉, 백엔드는 자유 텍스트를 아무렇게나 주는 서비스가 아니라 `구조화된 턴 생성기` 여야 한다.

## 3. 요청 경로

클라이언트는 설정값 기준으로 아래 경로를 사용한다.

- Health check: `GET {backend_base_url}/health`
- Turn request: `POST {backend_base_url}/v1/story/turn`

기본값:

- `backend_base_url = http://127.0.0.1:8000`

## 4. 요청 payload

현재 `NarrativeDirector` 가 조립하는 top-level 구조는 다음과 같다.

```json
{
  "persona": {
    "player_name": "Player",
    "relationship_scores": {
      "prototype_heroine": 0
    }
  },
  "world": {
    "location_id": "prototype_room_night",
    "rating_lane": "general",
    "flags": {}
  },
  "runtime_state": {
    "pending_player_input": "hello",
    "scene_mode": "layered",
    "current_visual_state": {},
    "settings_snapshot": {},
    "library_snapshot": {}
  },
  "recent_conversation": [],
  "asset_candidates": {
    "backgrounds": [],
    "sprites": [],
    "cgs": []
  }
}
```

### 4.1 `persona`

- `player_name`
- `relationship_scores`

현재 구현은 단순하지만, 이후 캐릭터 취향, 플레이어 설정, 톤 선호도까지 넣을 수 있다.

### 4.2 `world`

- `location_id`
- `rating_lane`
- `flags`

`rating_lane` 은 현재 자산 필터링과 장면 수위 제한에 동시에 사용된다.

### 4.3 `runtime_state`

- `pending_player_input`
- `scene_mode`
- `current_visual_state`
- `settings_snapshot`
- `library_snapshot`

백엔드는 여기서 현재 장면이 `layered` 인지 `cg` 인지, 어떤 배경이 이미 깔려 있는지 참고할 수 있다.

### 4.4 `recent_conversation`

최근 대화 10개가 전달된다.  
각 항목은 `role`, `text`, `metadata` 구조를 가진다.

### 4.5 `asset_candidates`

전체 자산 라이브러리를 보내지 않는다.  
`AssetLibrary` 가 현재 상태에 맞춰 걸러낸 후보만 전달한다.

예:

- 배경: 현재 location 에 맞는 후보 우선
- 스프라이트: 현재 등장 중인 캐릭터 후보 우선
- CG: 플래그 조건을 만족한 후보만

## 5. 응답 payload

백엔드는 반드시 아래 네 섹션을 모두 포함해야 한다.

```json
{
  "content": {
    "narration": "The room settles into silence.",
    "dialogue": "I was waiting for you.",
    "action": "She takes one slow step closer."
  },
  "direction": {
    "scene_mode": "layered",
    "background_id": "prototype_room_night",
    "character_states": [
      {
        "character_id": "prototype_heroine",
        "sprite_id": "prototype_heroine_neutral",
        "position": "center"
      }
    ],
    "cg_id": "",
    "transition": "fade",
    "camera_fx": "none"
  },
  "state_update": {
    "relationship_delta": {
      "prototype_heroine": 1
    },
    "set_flags": [
      "prototype_session_started"
    ],
    "content_rating": "general"
  },
  "memory_hint": {
    "summary_candidate": "The first conversation turn started."
  }
}
```

## 6. 현재 검증 규칙

`AiClient` 는 응답을 바로 렌더링하지 않고 먼저 아래를 검사한다.

- `content`, `direction`, `state_update`, `memory_hint` 가 모두 dictionary 인가
- `content.narration`, `dialogue`, `action` 이 문자열인가
- `direction.scene_mode` 가 `layered` 또는 `cg` 인가
- `direction.character_states` 가 배열인가
- 각 character state 의 `position` 이 `left`, `center`, `right` 중 하나인가
- 각 character state 의 `character_id`, `sprite_id` 가 비어 있지 않은가
- `state_update.content_rating` 이 존재하는가

이 단계에서 틀리면 클라이언트는 해당 턴을 실패 처리한다.

## 7. 자산 ID 검증과 fallback

스키마가 맞아도 자산 ID 는 다시 검증한다.

- 알 수 없는 `background_id`: 이전 배경 유지
- 알 수 없는 `sprite_id`: 해당 슬롯 숨김 또는 중립 fallback 사용
- 알 수 없는 `cg_id`: `layered` 모드로 강등
- 현재 rating lane 보다 높은 자산: 사용 불가
- CG flag 조건 불충족: `layered` 모드로 강등

즉, 백엔드는 자산을 "명령"하는 것이 아니라 "제안"한다. 최종 적용은 클라이언트가 검증 후 결정한다.

## 8. stub 모드

백엔드가 아직 없을 때는 `Settings > Use Stub Backend` 로 개발한다.

stub 모드 특징:

- `/health` 나 HTTP 서버가 없어도 동작
- 현재 asset 후보를 기준으로 테스트 응답 생성
- 입력 텍스트에 `#cg` 가 들어가면 가능한 경우 `cg` 모드 응답 생성

이 모드는 클라이언트 UI, 레이어 렌더링, fallback, save/load 를 먼저 검증하기 위한 것이다.

## 9. 실제 백엔드 구현 체크리스트

실제 서버를 붙일 때 최소 요구사항:

1. `GET /health` 가 200 을 반환해야 한다.
2. `POST /v1/story/turn` 이 위 스키마로 응답해야 한다.
3. `state_update.content_rating` 을 항상 채워야 한다.
4. `scene_mode` 는 `layered | cg` 만 사용해야 한다.
5. `character_states[].position` 은 `left | center | right` 만 사용해야 한다.
6. 전달되지 않은 자산 ID 를 즉석 생성하지 말고 `asset_candidates` 안에서만 고르는 것이 좋다.

## 10. 현재 상태 요약

현재 문제의 본질은 `클라이언트 버그` 라기보다 `백엔드 부재` 다.

- 클라이언트는 이미 HTTP 연결 지점을 가지고 있다.
- 하지만 이 저장소에는 그 지점에 응답해 줄 서버가 없다.
- 따라서 다음 구현 우선순위는 `Python/FastAPI 로컬 서버 추가` 다.
