# 백엔드 API와 모델 파이프라인
## Summary
백엔드는 FastAPI 하나로 매우 작지만, 실제로는 health 체크, prewarm, 프롬프트 조립, Ollama 호출, 응답 정규화, 세션 요약 캐시까지 모두 포함한다. 이 계층이 Godot와 Ollama 사이의 계약 어댑터 역할을 한다.

## Key Points
- `main.py`는 `/health`, `/v1/backend/prewarm`, `/v1/story/turn` 세 엔드포인트만 제공한다.
- `OllamaModelAdapter`는 `/api/tags`와 `/api/ps`를 함께 읽어 모델이 pull됐는지, VRAM에 얼마나 남아 있는지, context length가 충분한지, keep-alive 만료가 임박했는지까지 확인한다.
- prewarm은 기본적으로 `empty_request` 전략을 먼저 쓰고, 실패하거나 warm 검증이 통과하지 않으면 `single_token_probe`로 fallback한다.
- `prompt_memory.build_turn_prompt()`는 현재 `build_direct_kr_prompt()`를 사용한다. 즉 출력은 바로 한국어 JSON을 만들도록 강하게 제한하고, recent 대화와 prompt summary cache를 함께 넣는다.
- `normalize_turn_response()`는 AI가 낸 자산 ID, scene mode, character state, 대사 문자열을 다시 보정한다. 잘못된 character_id나 존재하지 않는 sprite_id는 여기서 잘린다.
- 파싱 실패나 저신호 응답에는 `build_fallback_response()`가 기본 장면을 만들어 준다. 따라서 서버는 실패 대신 최소한의 플레이 가능한 턴을 반환하려고 설계돼 있다.
- `compare_models.py`는 고정 fixture로 여러 모델을 비교하는 오프라인 평가 스크립트다. 구조적 오류, 금지 마커, 저신호 반복까지 체크한다.

## Related
- [[프로젝트 구조와 실행]]
- [[스토리 턴 파이프라인]]
- [[세이브와 세션 상태]]

## Sources
- backend/main.py
- backend/app/settings.py
- backend/app/model_adapter.py
- backend/app/prompt_memory.py
- backend/app/response_normalization.py
- backend/app/session_store.py
- backend/tools/compare_models.py
