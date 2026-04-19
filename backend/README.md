# Ollama Local Backend

이 폴더는 Godot 클라이언트가 호출하는 최소 로컬 백엔드 예제입니다.

현재 클라이언트 계약:

- `GET /health`
- `POST /v1/story/turn`

이 서버는 그 계약을 그대로 유지한 채, 내부에서 Ollama를 호출합니다.

## 구조

권장 실행 흐름:

1. Godot 클라이언트가 `http://127.0.0.1:8000` 으로 요청
2. FastAPI 서버가 요청을 받아 프롬프트 구성
3. FastAPI 서버가 로컬 Ollama에 `/api/generate` 호출
4. Ollama 응답을 게임용 JSON 스키마로 정규화
5. Godot가 그 JSON을 바로 렌더링

즉, 모델을 Godot에 직접 붙이지 않고 백엔드 뒤에 숨기는 구조입니다.

## 설치

Python 3.11+ 기준:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

## 왜 `gemma4:e4b` 를 기본값으로 두나

현재 문서 기준 기본 모델은 `gemma4:e4b` 입니다.

- RP 장면에서 감정선과 캐릭터 유지력이 7B보다 더 안정적입니다.
- 한국어/영어 혼합 프롬프트와 말투 리라이팅을 무난하게 버팁니다.
- JSON 스키마 강제 출력 환경에서 구조화 응답 품질이 비교적 좋습니다.

`qwen2.5:7b` 는 제거 대상이 아니라, VRAM 또는 응답 속도를 더 우선할 때 쓰는 경량 대안으로 둡니다.

## Ollama 준비

권장 모델:

```powershell
ollama pull gemma4:e4b
ollama serve
```

경량 대안:

```powershell
ollama pull qwen2.5:7b
```

## 환경 변수

### 기본 코드값

현재 `backend/main.py` 와 `.env.example` 에 들어 있는 기본값은 아래입니다.
현재는 이 기본값이 곧 권장 운영 프로필입니다.

- `OLLAMA_HOST=http://127.0.0.1:11434`
- `OLLAMA_MODEL=gemma4:e4b`
- `OLLAMA_DIALOGUE_BASE_LANGUAGE=kr`
- `OLLAMA_KEEP_ALIVE=20m`
- `OLLAMA_REQUEST_TIMEOUT_SECONDS=40`
- `OLLAMA_HEALTH_TIMEOUT_SECONDS=5`
- `OLLAMA_NUM_PREDICT=320`
- `OLLAMA_REPEAT_PENALTY=1.10`
- `OLLAMA_NUM_CTX=4096`
- `OLLAMA_CONTEXT_LENGTH=0`
- `OLLAMA_TEMPERATURE=0.4`
- `OLLAMA_TOP_P=0.9`
- `PREWARM_STRATEGY=empty_request`
- `BACKEND_WARM_MIN_VRAM_RATIO=0.85`
- `BACKEND_WARM_MIN_EXPIRES_SECONDS=120`
- `PORT=8000`

### 권장 운영값

현재 프로젝트 기본값은 문서 기준 권장 프로필과 동일합니다.
이 프로필은 RP 장면에서 감정선, 캐릭터 유지력, 한국어/영어 혼합, JSON 스키마 출력의 균형을 먼저 맞추는 쪽에 가깝습니다.

- `OLLAMA_MODEL=gemma4:e4b`
- `OLLAMA_NUM_CTX=4096`
- `OLLAMA_NUM_PREDICT=320`
- `OLLAMA_TEMPERATURE=0.4`
- `OLLAMA_TOP_P=0.9`
- `OLLAMA_REPEAT_PENALTY=1.10`
- `OLLAMA_KEEP_ALIVE=20m`
- `OLLAMA_REQUEST_TIMEOUT_SECONDS=40`
- `BACKEND_WARM_MIN_VRAM_RATIO=0.85`

기본값은 이미 위 프로필로 맞춰져 있지만, PowerShell에서 명시적으로 고정하려면:

```powershell
$env:OLLAMA_HOST = "http://127.0.0.1:11434"
$env:OLLAMA_MODEL = "gemma4:e4b"
$env:OLLAMA_DIALOGUE_BASE_LANGUAGE = "kr"
$env:OLLAMA_KEEP_ALIVE = "20m"
$env:OLLAMA_REQUEST_TIMEOUT_SECONDS = "40"
$env:OLLAMA_HEALTH_TIMEOUT_SECONDS = "5"
$env:OLLAMA_NUM_PREDICT = "320"
$env:OLLAMA_NUM_CTX = "4096"
$env:OLLAMA_TEMPERATURE = "0.4"
$env:OLLAMA_TOP_P = "0.9"
$env:OLLAMA_REPEAT_PENALTY = "1.10"
$env:BACKEND_WARM_MIN_VRAM_RATIO = "0.85"
$env:PORT = "8000"
```

운영 메모:

- `OLLAMA_KEEP_ALIVE=20m`: 모델을 메모리에 더 오래 유지해 두 번째 요청부터 지연을 줄임
- `OLLAMA_NUM_PREDICT=320`: 300~500자 분량의 장면이 잘리지 않도록 생성 길이를 확보
- `OLLAMA_NUM_CTX=4096`: 최근 대화, 캐릭터 정보, 세계관 요약을 함께 넣어도 여유를 확보
- `OLLAMA_TEMPERATURE=0.4`, `OLLAMA_TOP_P=0.9`: 말투 자연스러움은 올리되 장면 통제력을 너무 잃지 않는 절충값
- `OLLAMA_REPEAT_PENALTY=1.10`: 반복을 줄이되 과도한 억제로 말투가 깨지지 않게 조정
- `OLLAMA_REQUEST_TIMEOUT_SECONDS=40`: `gemma4:e4b` 첫 로딩과 첫 턴 응답에 더 여유를 둬 timeout 빈도를 낮춤
- `BACKEND_WARM_MIN_VRAM_RATIO=0.85`: partial offload 환경에서도 warm 판정이 과도하게 실패하지 않도록 완화
- `OLLAMA_DIALOGUE_BASE_LANGUAGE=kr`: 현재 코드 기본값과 같은 방향으로 두고, 한국어 서비스 기준 문장을 바로 생성
- VRAM이나 응답 속도가 더 중요하면 `OLLAMA_MODEL=qwen2.5:7b` 로 내리는 편이 가장 현실적인 fallback

현재 프롬프트는 한 턴을 짧은 대사 한 줄이 아니라, narration + dialogue + action을 합쳐 약 300~500자 분량의 장면처럼 만들도록 조정되어 있습니다.
또한 dialogue는 main_personality, speech_style, speech_examples를 prompt anchor로 써서, `Base Dialogue -> Emotion Layer -> Personality Layer -> KR Rewrite` 순서의 단일 호출 하이브리드 전략을 사용합니다.

## 실행

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```

## Ollama 서버 켜기

Windows PowerShell 기준:

```powershell
ollama serve
```

다른 터미널에서 모델을 준비합니다.

```powershell
ollama pull gemma4:e4b
ollama list
```

VRAM 또는 응답 속도를 더 우선하면:

```powershell
ollama pull qwen2.5:7b
```

서버 확인:

```powershell
Invoke-RestMethod http://127.0.0.1:11434/api/tags
```

## Godot 연결

게임 설정 화면에서:

1. `Use Stub Backend` 끄기
2. `Backend Base URL` 을 `http://127.0.0.1:8000` 로 설정
3. `Check Backend` 실행

## 왜 이 구조가 맞는가

- API 키가 필요해져도 나중에 백엔드에만 추가하면 됨
- JSON 보정과 fallback 처리를 Godot가 아니라 서버에서 맡을 수 있음
- Ollama 모델을 바꿔도 클라이언트 수정이 거의 없음
- 로그와 디버깅을 백엔드에서 집중 관리 가능

## 현재 예제의 한계

- 프롬프트가 아직 단순함
- 장기 기억 저장은 구현하지 않음
- 캐릭터 감정 전환 로직은 최소 수준임
- 모델이 JSON을 틀리게 내면 fallback 응답으로 복구함

즉, 기본값은 이제 `gemma4:e4b` 이며, `qwen2.5:14b` 는 비교 기준선으로 유지하고 저사양 PC나 더 빠른 응답이 필요할 때만 `qwen2.5:7b` 로 내려 쓰는 편이 안전합니다.

이 예제는 `stub` 대체용 최소 서버입니다. 이후 품질 개선은 백엔드에서 진행하면 됩니다.

## Session Prompt Cache

- `/v1/story/turn` 요청은 선택적으로 `session` 객체를 받을 수 있습니다.
- 형식:

```json
{
  "session": {
    "id": "session_...",
    "reset_prompt_cache": false
  }
}
```

- `session.id` 는 플레이스루 단위 식별자입니다.
- `reset_prompt_cache=true` 이면 서버는 해당 세션의 prompt cache와 turn cache를 비우고 현재 흐름부터 다시 쌓습니다.
- 이 캐시는 장기 기억 시스템이 아니라 `프롬프트용 중간 요약 캐시` 입니다.
- `memory_hint.summary_candidate` 는 후보로만 저장되며 prompt에 그대로 다시 넣지 않습니다.

## SQLite Cache

- 기본 SQLite 경로는 `backend/backend_state.sqlite3` 입니다.
- 환경변수로 바꾸려면 `BACKEND_SQLITE_PATH` 를 지정하면 됩니다.

## Model Compare Script

- 고정 fixture 비교 스크립트는 `backend/tools/compare_models.py` 입니다.
- 기본 fixture 경로는 `backend/fixtures/story_turn/*.json` 입니다.
- 기본 비교 모델은 `qwen2.5:14b`, `gemma4:e4b` 입니다.
