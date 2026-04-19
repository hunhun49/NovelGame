# [기획 05] Godot 로컬 런타임과 백엔드 연결 전략

## 1. 문서 목적

파일명은 예전 이름을 유지하지만, 현재 프로젝트 방향은 웹 서비스가 아니라 `Godot 로컬 클라이언트 + 로컬/별도 백엔드` 다.

이 문서는 현재 구현 상태와 백엔드 연결 전략을 정리한다.

## 2. 현재 구현 상태

현재 저장소에 있는 것은 다음이다.

- Godot 클라이언트
- 설정 패널
- 외부 자산 라이브러리 로더
- VN 레이어 렌더러
- 퀵세이브/컨티뉴
- HTTP 백엔드 클라이언트
- stub 백엔드 모드

현재 저장소에 없는 것은 다음이다.

- 실제 `/health` 서버
- 실제 `/v1/story/turn` 서버
- 스트리밍 응답 서버
- 모델 호출 어댑터

따라서 현재 백엔드 연결이 안 되는 문제는 자연스러운 상태다.  
지금 단계에서는 `stub 모드로 클라이언트 완성 -> 이후 로컬 서버 추가` 순서가 맞다.

## 3. 권장 아키텍처

```text
Godot Client
|- SettingsManager
|- AssetLibrary
|- NarrativeDirector
|- AiClient
|- SaveManager

Local Backend (별도 프로세스)
|- /health
|- /v1/story/turn
|- Prompt builder
|- Model adapter
|- Response validator
```

핵심 원칙:

- Godot 는 UI/상태/렌더링 담당
- 백엔드는 텍스트 생성과 JSON 응답 담당
- 둘은 HTTP JSON 으로 느슨하게 결합

## 4. 현재 연결 방식

설정 파일 위치:

- `user://settings.json`

현재 핵심 필드:

- `asset_library_path`
- `backend_mode`
- `backend_base_url`
- `use_stub_backend`
- `last_validation_status`

기본값:

- `backend_base_url = http://127.0.0.1:8000`
- `backend_mode = http`
- `use_stub_backend = false`

주의:

- `use_stub_backend = false` 이고 서버가 없으면 메인 메뉴에서 시작 버튼이 비활성화된다.
- 서버가 아직 없다면 반드시 stub 모드를 켜야 한다.

## 5. Health check 정책

클라이언트는 시작 시 `GET /health` 를 호출한다.

성공 조건:

- HTTP 200 대 응답

현재는 응답 body 내용을 세부 파싱하지 않는다.  
즉, 최소한 200 만 반환해도 `healthy` 로 본다.

권장 응답 예시:

```json
{
  "status": "ok"
}
```

## 6. Turn request 정책

클라이언트는 턴 생성 시 `POST /v1/story/turn` 로 JSON 을 보낸다.  
응답은 반드시 구조화된 JSON 이어야 하며, 현재 스키마를 벗어나면 실패 처리된다.

중요:

- 자동 stub fallback 없음
- HTTP 실패 시 사용자에게 오류를 보여주고 턴을 중단
- 응답이 잘못되면 schema error 로 처리

이 정책은 디버깅을 쉽게 하기 위한 것이다.  
백엔드 문제가 있을 때 클라이언트가 조용히 다른 경로로 넘어가면 원인 파악이 더 어려워진다.

## 7. 지금 자주 막히는 지점

### 7.1 서버 자체가 없음

현재 저장소에는 서버 코드가 없다.  
이 경우 해결책은 문서 수정이 아니라 아래 둘 중 하나다.

- 당장은 stub 모드 사용
- 이후 별도 `backend/` 프로젝트 추가

### 7.2 `/health` 미구현

서버를 띄웠더라도 `/health` 가 없으면 메뉴에서 ready 상태가 되지 않는다.

### 7.3 URL 오입력

설정 패널의 `Backend Base URL` 은 베이스 주소만 넣는 것이 안전하다.

좋음:

- `http://127.0.0.1:8000`

피해야 함:

- `http://127.0.0.1:8000/v1/story/turn`
- `http://127.0.0.1:8000/health`

현재 클라이언트는 어느 정도 sanitize 하지만, 처음부터 베이스 URL 만 넣는 것이 명확하다.

### 7.4 응답 스키마 불일치

다음 항목이 빠지면 실패한다.

- `content`
- `direction`
- `state_update`
- `memory_hint`
- `state_update.content_rating`

### 7.5 존재하지 않는 자산 ID

응답이 성공해도 자산 ID 가 library 에 없으면 fallback 이 걸린다.  
백엔드가 자산 후보 외부의 ID 를 마음대로 생성하면 안 된다.

## 8. 현재 권장 개발 순서

1. Godot 셸은 stub 모드로 먼저 고정
2. 테스트용 외부 라이브러리 준비
3. `/health` 와 `/v1/story/turn` 만 있는 최소 서버 구현
4. stub 응답과 동일한 JSON 구조로 실제 서버 응답 맞추기
5. 그 후에만 프롬프트 품질, 메모리, 장기 상태 확장

이 순서를 거꾸로 가면 어디서 깨지는지 분리하기 어렵다.

## 9. 다음 백엔드 구현 아이디어

가장 작은 서버는 Python/FastAPI 기준으로 충분하다.

최소 요구:

- `GET /health`
- `POST /v1/story/turn`
- 고정 fixture 응답
- 이후 모델 호출 어댑터 추가

첫 버전은 실제 LLM 을 붙이지 않고도 된다.  
먼저 fixture 응답으로 Godot 와의 계약만 고정하는 것이 맞다.

## 10. 결론

현재 프로젝트는 `백엔드 연결이 안 되는 Godot 게임` 이 아니라 `백엔드가 아직 없는 Godot 클라이언트` 상태다.

당장 플레이 가능한 개발 흐름:

- `Settings` 에서 `Use Stub Backend` 켜기

다음 구현 우선순위:

- 실제 로컬 HTTP 서버 추가
