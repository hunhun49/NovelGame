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

## Ollama 준비

예시:

```powershell
ollama pull qwen2.5:7b
ollama serve
```

## 환경 변수

`.env.example` 기준:

- `OLLAMA_HOST=http://127.0.0.1:11434`
- `OLLAMA_MODEL=qwen2.5:7b`
- `OLLAMA_KEEP_ALIVE=20m`
- `OLLAMA_REQUEST_TIMEOUT_SECONDS=25`
- `OLLAMA_NUM_PREDICT=140`
- `OLLAMA_NUM_CTX=2048`
- `PORT=8000`

PowerShell 예시:

```powershell
$env:OLLAMA_HOST = "http://127.0.0.1:11434"
$env:OLLAMA_MODEL = "qwen2.5:7b"
$env:OLLAMA_KEEP_ALIVE = "20m"
$env:OLLAMA_REQUEST_TIMEOUT_SECONDS = "25"
$env:OLLAMA_NUM_PREDICT = "140"
$env:OLLAMA_NUM_CTX = "2048"
$env:PORT = "8000"
```

속도 우선 권장값:

- `OLLAMA_KEEP_ALIVE=20m`: 모델을 메모리에 더 오래 유지해 두 번째 요청부터 지연을 줄임
- `OLLAMA_NUM_PREDICT=140`: 생성 길이를 줄여 응답 시간을 단축
- `OLLAMA_NUM_CTX=2048`: 지나치게 큰 컨텍스트 비용을 피함
- `OLLAMA_REQUEST_TIMEOUT_SECONDS=25`: 오래 멈춘 요청을 빠르게 fallback 처리
- 더 빠른 체감이 필요하면 `OLLAMA_MODEL=qwen2.5:3b` 같은 더 가벼운 모델로 바꾸는 편이 가장 효과가 큼

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
ollama pull qwen2.5:7b
ollama list
```

속도를 더 우선하면:

```powershell
ollama pull qwen2.5:3b
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

이 예제는 `stub` 대체용 최소 서버입니다. 이후 품질 개선은 백엔드에서 진행하면 됩니다.
