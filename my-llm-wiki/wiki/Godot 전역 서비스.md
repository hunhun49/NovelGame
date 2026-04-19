# Godot 전역 서비스
## Summary
클라이언트의 핵심 로직은 `project.godot`에 autoload로 등록된 서비스 노드에 집중돼 있다. UI는 이 서비스들의 상태를 소비하고, 씬 전환이나 저장도 같은 계층에서 처리한다.

## Key Points
- `SettingsManager`는 `user://settings.json`을 관리하며 자산 루트, 백엔드 URL, stub 모드를 정규화한다.
- `AssetLibrary`는 외부 `manifest.json`을 읽어 배경, 스프라이트, CG, BGM, SFX를 인덱싱하고 후보 묶음과 검증 API를 제공한다.
- `StoryProfileStore`는 `user://content/worlds.json`, `characters.json`을 관리하고 세계관/캐릭터 편집 결과를 저장한다.
- `GameState`는 현재 장면, 관계도, 플래그, 시각/오디오 상태, 최근 대화, 선택한 세계관/캐릭터, 세션 ID, 롤백 스냅샷을 한 곳에 모은다.
- `SaveManager`, `AudioManager`, `SceneRouter`는 각각 저장, BGM/SFX 재생, 씬 전환에 집중한다.
- `NarrativeDirector`와 `AiClient`는 턴 요청 생성과 백엔드 통신을 맡는 런타임 중심 서비스다.

## Related
- [[스토리 턴 파이프라인]]
- [[자산 라이브러리와 오디오]]
- [[세이브와 세션 상태]]

## Sources
- godot-novel-maker/project.godot
- godot-novel-maker/classes/SettingsManager.gd
- godot-novel-maker/classes/AssetLibrary.gd
- godot-novel-maker/classes/StoryProfileStore.gd
- godot-novel-maker/classes/GameState.gd
- godot-novel-maker/classes/SaveManager.gd
- godot-novel-maker/classes/AudioManager.gd
- godot-novel-maker/classes/SceneRouter.gd
- godot-novel-maker/classes/AiClient.gd
- godot-novel-maker/classes/NarrativeDirector.gd
