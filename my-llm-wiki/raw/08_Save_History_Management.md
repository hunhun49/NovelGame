# [기획 08] 퀵세이브와 상태 복원 설계

## 1. 목표

이 프로젝트의 저장은 단순한 위치 저장이 아니라 `현재 VN 상태 전체를 다시 렌더링할 수 있는 스냅샷` 이어야 한다.

현재 구현은 이 목표에 맞춰 퀵세이브를 설계한다.

## 2. 현재 저장 범위

현재 `SaveManager.quick_save()` 는 `GameState.build_save_payload()` 결과를 저장한다.

포함되는 핵심 정보:

- 플레이어 이름
- 현재 씬 이름
- 현재 location
- 현재 rating lane
- 관계 수치
- 플래그
- 현재 시각 상태
- 현재 콘텐츠 텍스트
- 최근 대화 로그
- 마지막 요약
- 마지막 상태 메시지
- fallback 메시지
- 설정 스냅샷
- 라이브러리 스냅샷

즉, `Continue` 는 단순히 이야기 위치만 복원하는 것이 아니라 화면 상태도 다시 그릴 수 있어야 한다.

## 3. 현재 저장 파일

현재 퀵세이브 경로:

- `user://saves/quick_save.json`

현재는 슬롯 기반 manual save 보다 `quick save / continue` 가 우선 구현되어 있다.

## 4. payload 예시

```json
{
  "player_name": "Player",
  "current_scene_name": "novel_scene",
  "current_location_id": "prototype_room_night",
  "current_rating_lane": "general",
  "relationship_scores": {
    "prototype_heroine": 1
  },
  "flags": {
    "prototype_session_started": true
  },
  "current_visual_state": {
    "scene_mode": "layered",
    "background_id": "prototype_room_night",
    "cg_id": "",
    "character_slots": {
      "left": {},
      "center": {
        "character_id": "prototype_heroine",
        "sprite_id": "prototype_heroine_neutral",
        "position": "center"
      },
      "right": {}
    },
    "transition": "fade",
    "camera_fx": "none"
  },
  "current_content": {
    "narration": "The room settles into silence.",
    "speaker_name": "Prototype_heroine",
    "dialogue": "I was waiting for you.",
    "action": "She takes one slow step closer."
  },
  "conversation_log": [],
  "last_summary": "The first conversation turn started.",
  "last_status_message": "Turn applied.",
  "last_fallback_messages": [],
  "settings_snapshot": {
    "asset_library_path": "D:/VNAssets/TestLibrary",
    "backend_mode": "stub",
    "backend_base_url": "http://127.0.0.1:8000",
    "use_stub_backend": true,
    "last_validation_status": "valid"
  },
  "library_snapshot": {
    "root_path": "D:/VNAssets/TestLibrary",
    "validation_status": "valid",
    "background_count": 3,
    "sprite_count": 4,
    "cg_count": 1
  }
}
```

## 5. 설정과 저장의 분리

설정은 별도로 `user://settings.json` 에 저장된다.

이 분리의 의미:

- 저장 파일이 없어도 backend URL 과 library path 는 유지
- 저장을 불러오지 않아도 마지막 환경 설정은 유지
- quick save 는 게임 상태 복원에 집중

즉, 설정은 런타임 환경이고 세이브는 서사 상태다.

## 6. 라이브러리 변경 시 주의점

세이브는 자산 파일을 직접 복사하지 않고 ID 와 스냅샷만 저장한다.

따라서 나중에 라이브러리가 바뀌면:

- 저장된 배경 ID 가 사라질 수 있음
- 저장된 스프라이트 ID 가 사라질 수 있음
- 저장된 CG ID 가 사라질 수 있음

이 경우 현재 정책:

- 가능한 범위에서 fallback 적용
- 복구 불가 자산은 숨기거나 이전 상태 유지
- 게임은 크래시하지 않는 것이 우선

## 7. 현재 구현의 의미

지금 백엔드가 연결되지 않아도 save/load 구조를 먼저 잡은 이유는 명확하다.

- 턴 응답 계약이 고정되면 저장 구조도 고정된다.
- 시각 상태 복원까지 성공해야 VN 셸이 완성된다.
- 이후 실제 모델을 붙여도 세이브 구조를 크게 흔들지 않게 된다.

## 8. 다음 확장 방향

이후 추가할 수 있는 것:

- 수동 save 슬롯
- 썸네일 저장
- 특정 시점 rollback
- branching history 보기
- library version 기록 강화

하지만 현재 우선순위는 여전히 `실제 백엔드 서버 추가` 다.
