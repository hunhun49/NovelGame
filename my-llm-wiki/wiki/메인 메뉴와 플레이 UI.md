# 메인 메뉴와 플레이 UI
## Summary
메인 메뉴는 실행 준비 상태를 게이트로 삼고, 실제 플레이 화면은 VN형 대화 박스와 레이어 기반 연출을 관리한다. 저장/불러오기, 설정, 온보딩 오버레이도 모두 UI 안에 내장돼 있다.

## Key Points
- `MainMenu`는 퀵세이브 존재 여부, 수동 세이브 여부, 자산 라이브러리 유효성, backend 준비 상태, 세계관/캐릭터 개수를 조합해 버튼 활성화를 결정한다.
- `StorySetupPanel`은 `세계관 선택 -> 메인 캐릭터 선택 -> 플레이어 캐릭터 선택`의 3단계 흐름이다. 플레이어 캐릭터는 선택한 메인 캐릭터와 별도 후보군에서 고른다.
- `NovelScene`은 배경, 캐릭터 슬롯, CG, 카메라 dim 효과, VN 대사 박스, 입력 패널, 게임 메뉴, 온보딩 오버레이를 한 화면에서 관리한다.
- 대사 출력은 narration/dialogue/action을 문장 단위 세그먼트로 쪼개 타이핑 효과와 클릭 진행으로 보여 준다.
- 입력 패널은 모든 세그먼트가 끝난 뒤에만 열리고, 라이브러리 미설정이나 backend 미준비 상태에서는 생성 버튼이 잠긴다.
- 플레이 중 저장/불러오기는 같은 `SaveLoadPanel`을 재사용하고, 불러오기 직후에는 `GameState`와 오디오 상태를 즉시 재렌더링한다.

## Related
- [[프로젝트 구조와 실행]]
- [[스토리 턴 파이프라인]]
- [[세이브와 세션 상태]]
- [[콘텐츠 제작 도구]]

## Sources
- godot-novel-maker/scripts/ui/MainMenu.gd
- godot-novel-maker/scripts/ui/StorySetupPanel.gd
- godot-novel-maker/scripts/ui/NovelScene.gd
- godot-novel-maker/scripts/ui/SettingsPanel.gd
- godot-novel-maker/scripts/ui/SaveLoadPanel.gd
- godot-novel-maker/scenes/main.tscn
- godot-novel-maker/scenes/novel_scene.tscn
