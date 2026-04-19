# 코드베이스 위키 인덱스
## Summary
이 위키는 `raw/` 설계 메모가 아니라 실제 프로젝트 코드 기준으로 다시 정리한 문서 묶음이다. 기준 소스는 `godot-novel-maker/`의 Godot 클라이언트와 `backend/`의 FastAPI/Ollama 백엔드다.

## Key Points
- 실행 구조는 `Godot 클라이언트 -> FastAPI 백엔드 -> Ollama`이며, stub 모드와 데모 라이브러리로 로컬 단독 실행도 가능하다.
- 핵심 상태는 `GameState`, `NarrativeDirector`, `AiClient`, `AssetLibrary`, `StoryProfileStore` 같은 autoload 서비스에 모여 있다.
- 위키 문서는 실제 클래스와 엔드포인트 책임을 기준으로 나눴고, 각 문서의 `Sources`에 근거 파일을 직접 적었다.

## Related
- [[프로젝트 구조와 실행]]
- [[Godot 전역 서비스]]
- [[스토리 턴 파이프라인]]
- [[메인 메뉴와 플레이 UI]]
- [[콘텐츠 제작 도구]]
- [[자산 라이브러리와 오디오]]
- [[세이브와 세션 상태]]
- [[백엔드 API와 모델 파이프라인]]

## Sources
- README.md
- godot-novel-maker/project.godot
- godot-novel-maker/classes/GameState.gd
- godot-novel-maker/classes/NarrativeDirector.gd
- backend/main.py
