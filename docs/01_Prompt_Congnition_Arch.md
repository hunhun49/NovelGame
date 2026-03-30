# [기획서 01] Gemini 3 Flash 기반 AI 인지 및 프롬프트 아키텍처

## 1. 프롬프트 계층 구조 (Layered Prompting)
Gemini 3 Flash의 향상된 지시 이행 능력을 활용하여 정보를 3단계로 분리 주입합니다.

### 1.1 하이 레벨 지시문 (System Instruction)
- **Role:** 세계관을 주관하는 '스토리 마스터' 및 '게임 엔진'.
- **Constraint:** 소설적 허구와 실제 시스템 데이터(JSON)를 엄격히 분리하여 출력.
- **Narrative Style:** 유저가 선택한 문체(예: 만문보, 1인칭 주인공 시점 등)를 유지하는 고차원 언어 모델링 지시.

### 1.2 컨텍스트 관리 (Context Management)
- **고정 컨텍스트 (Static):** 세계관 물리 법칙, 고정 캐릭터 설정, 핵심 로어북.
- **가변 컨텍스트 (Dynamic):** 현재까지의 줄거리 요약(Summary), 최근 대화 이력 30턴.
- **Gemini 3 Context Caching:** 반복되는 세계관 및 페르소나 데이터는 'Context Caching' 기능을 통해 캐싱하여 첫 응답 속도(TTFT)를 500ms 이내로 단축.

## 2. 응답 구조화 (Structured Output)
단순 텍스트가 아닌 시스템 제어용 데이터를 포함한 확장 JSON 모드를 사용합니다.
```json
{
  "logic": {
    "thought_process": "AI가 상황을 어떻게 해석했는지에 대한 내부 추론",
    "world_event_flag": "사건 발생 ID 또는 null"
  },
  "content": {
    "narration": "소설적 묘사",
    "dialogue": "캐릭터 대사",
    "action": "캐릭터 행동 및 주변 환경 변화"
  },
  "metadata": {
    "mood_score": 0.85, 
    "pacing": "fast",
    "speaker_id": "char_01"
  }
}