# NovelGame

Godot 기반 로컬 AI 비주얼 노벨 프로젝트입니다.  
텍스트는 실시간으로 생성하고, 이미지는 사용자가 준비한 자산 라이브러리에서 선택해 출력하는 구조를 목표로 합니다.

## 현재 상태

- Godot 클라이언트 기본 구조 구현
- 메인 메뉴, 설정, 세계관/인물 작성 UI 구현
- 외부 이미지 자산 라이브러리 로딩
- 배경 / 스프라이트 / CG 렌더링
- 세이브 / 로드 / 롤백 기본 구조
- 로컬 HTTP 백엔드 연동 인터페이스
- 백엔드가 없을 때 사용하는 `stub` 모드

## 작업 규칙

- 별도 요청이 없으면 사용자에게 보이는 UI 문구, 상태 메시지, 작성 폼 문구는 한국어를 기본으로 작업합니다.
- 코드 식별자, 파일명, 클래스명은 기존 개발 규칙에 따라 영어를 유지할 수 있습니다.
- 새로 추가하거나 수정하는 UI 문자열도 한국어를 기본으로 맞춥니다.

## 실행 방법

### 1. Godot 프로젝트 열기

- 프로젝트 파일: `godot-novel-maker/project.godot`

### 2. 백엔드가 없으면 stub 모드 사용

메인 메뉴 또는 설정 화면에서:

- `Use Stub Backend` 활성화
- 필요하면 데모 라이브러리 또는 외부 자산 폴더 선택

이 상태에서 UI, 자산 출력, 저장/불러오기 흐름을 먼저 검증할 수 있습니다.

### 3. 실제 백엔드 연결

설정 화면에서:

- `Backend Base URL` 입력
- `Check Backend` 실행

기본 연동 경로:

- `GET /health`
- `POST /v1/story/turn`

기본 URL은 `http://127.0.0.1:8000` 입니다.

### 4. Ollama 로컬 백엔드

이 저장소에는 Godot 클라이언트가 바로 연결할 수 있는 최소 예제가 `backend/` 폴더에 포함됩니다.

권장 구조:

- Godot -> FastAPI -> Ollama

현재 기본 권장 모델은 `gemma4:e4b` 입니다. `qwen2.5:14b`는 비교 기준선으로 유지하고, `qwen2.5:7b`는 VRAM 또는 응답 속도를 더 우선할 때 쓰는 경량 대안입니다.
백엔드 기본값도 `gemma4:e4b` 프로필로 맞춰져 있어서, 아래 예시 그대로 실행하면 됩니다. 세부 튜닝이나 7B override는 `backend/README.md`를 보면 됩니다.

빠른 시작:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
ollama pull gemma4:e4b
uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```

Ollama 서버가 아직 켜져 있지 않다면, 다른 터미널에서 `ollama serve` 를 먼저 실행합니다.

그 후 게임 설정에서:

- `Use Stub Backend` 비활성화
- `Backend Base URL = http://127.0.0.1:8000`
- `Check Backend` 실행

## 자산 라이브러리

자산은 `res://` 내부가 아니라 사용자가 선택한 외부 폴더에서 읽습니다.  
루트에는 반드시 `manifest.json`이 있어야 합니다.

예시 구조:

```text
my-library/
|- manifest.json
|- backgrounds/
|- sprites/
|- cgs/
```

## 문서

- `docs/01_Prompt_Congnition_Arch.md`
- `docs/03_Visual_Orchestration.md`
- `docs/05_Web_Infra_Optimization.md`
- `docs/10_Ollama_Local_Backend.md`
- `docs/06_Visual_Layer_System.md`
- `docs/08_Save_History_Management.md`

## Session Prompt Cache

- 로컬 백엔드는 선택적 `session.id` 와 `session.reset_prompt_cache` 를 지원합니다.
- 이 세션 캐시는 장기 기억이 아니라 `프롬프트용 중간 요약 캐시` 로만 동작합니다.
- save/load 이후 첫 턴에서는 같은 `session_id` 를 유지하되 cache reset 흐름을 타도록 구현했습니다.

## Model Compare Fixtures

- 고정 fixture 기반 비교 스크립트: `backend/tools/compare_models.py`
- 기본 비교 모델: `qwen2.5:14b`, `gemma4:e4b`
