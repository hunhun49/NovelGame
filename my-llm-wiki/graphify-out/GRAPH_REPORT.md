# Graph Report - C:\Users\hunhun0409\Documents\projects\NovelGame\my-llm-wiki\raw  (2026-04-18)

## Corpus Check
- Corpus is ~6,267 words - fits in a single context window. You may not need a graph.

## Summary
- 40 nodes · 62 edges · 9 communities detected
- Extraction: 71% EXTRACTED · 24% INFERRED · 5% AMBIGUOUS · INFERRED: 15 edges (avg confidence: 0.79)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Narrative Memory Design|Narrative Memory Design]]
- [[_COMMUNITY_Turn and Content Orchestration|Turn and Content Orchestration]]
- [[_COMMUNITY_Model and Schema Runtime|Model and Schema Runtime]]
- [[_COMMUNITY_Backend Integration Path|Backend Integration Path]]
- [[_COMMUNITY_Save and Runtime Settings|Save and Runtime Settings]]
- [[_COMMUNITY_Dialogue Interaction UI|Dialogue Interaction UI]]
- [[_COMMUNITY_Scene Fallback and Layer UI|Scene Fallback and Layer UI]]
- [[_COMMUNITY_Asset Lane Separation|Asset Lane Separation]]
- [[_COMMUNITY_Safety Policy Core|Safety Policy Core]]

## God Nodes (most connected - your core abstractions)
1. `Structured Turn Generation` - 8 edges
2. `Rating Lane` - 8 edges
3. `Candidate Filtering Pipeline` - 7 edges
4. `Memory Hierarchy` - 7 edges
5. `Local Backend Architecture` - 6 edges
6. `VN State Snapshot Save` - 6 edges
7. `Asset ID Fallback` - 5 edges
8. `Story Turn Endpoint` - 5 edges
9. `VN Layer Stack` - 5 edges
10. `Backend API Contract` - 4 edges

## Surprising Connections (you probably didn't know these)
- `Audio Candidate Orchestration` --references--> `Story Turn Endpoint`  [AMBIGUOUS]
  raw/07_Sound_Orchestration.md → raw/05_Web_Infra_Optimization.md
- `Prompt Builder` --semantically_similar_to--> `FastAPI Local Server`  [INFERRED] [semantically similar]
  raw/local_ai_server_prompt.md → raw/10_Ollama_Local_Backend.md
- `Structured Turn Generation` --shares_data_with--> `VN State Snapshot Save`  [INFERRED]
  raw/01_Prompt_Congnition_Arch.md → raw/08_Save_History_Management.md
- `Schema Repair` --semantically_similar_to--> `Response Schema Validation`  [INFERRED] [semantically similar]
  raw/10_Ollama_Local_Backend.md → raw/01_Prompt_Congnition_Arch.md
- `Asset ID Fallback` --shares_data_with--> `Asset Library Manifest`  [INFERRED]
  raw/01_Prompt_Congnition_Arch.md → raw/03_Visual_Orchestration.md

## Hyperedges (group relationships)
- **Backend Turn Generation Stack** — prompt_cognition_arch_backend_api_contract, prompt_cognition_arch_structured_turn_generation, web_infra_local_backend_architecture, ollama_backend_fastapi_server, ollama_backend_ollama_stack, ollama_backend_schema_repair [INFERRED 0.89]
- **VN Runtime Presentation Stack** — visual_orch_asset_library, visual_orch_candidate_filtering, visual_orch_layered_mode, visual_orch_cg_mode, visual_layer_vn_layer_stack, vn_dialog_ui_vn_dialog_ui, vn_dialog_ui_typing_effect, sound_orch_audio_orchestration [INFERRED 0.86]
- **Content Lane Governance** — safety_guardrails_rating_lane, safety_guardrails_safety_policy, safety_guardrails_asset_lane_separation, safety_guardrails_player_toggles, visual_orch_candidate_filtering, sound_orch_audio_orchestration [INFERRED 0.84]

## Communities

### Community 0 - "Narrative Memory Design"
Cohesion: 0.28
Nodes (9): Emotion-Driven Speech Shift, Relationship Language Stages, Structured Speech Profile, Style Anchor Rationale, Prompt Builder, Vector Memory Backend, Continuity Check, Memory Hierarchy (+1 more)

### Community 1 - "Turn and Content Orchestration"
Cohesion: 0.53
Nodes (6): Structured Turn Generation, Rating Lane, Audio Candidate Orchestration, Candidate Filtering Pipeline, Filtered Candidate Rationale, CG Scene Mode

### Community 2 - "Model and Schema Runtime"
Cohesion: 0.4
Nodes (6): FastAPI Local Server, Ollama Backend, Qwen 2.5 14B Profile, Schema Repair, Backend API Contract, Response Schema Validation

### Community 3 - "Backend Integration Path"
Cohesion: 0.5
Nodes (5): Backend Separation Rationale, Stub Backend Mode, Health Endpoint, Local Backend Architecture, Story Turn Endpoint

### Community 4 - "Save and Runtime Settings"
Cohesion: 0.5
Nodes (4): Player Content Toggles, Settings and Save Separation, Resume State Rationale, VN State Snapshot Save

### Community 5 - "Dialogue Interaction UI"
Cohesion: 0.67
Nodes (3): Input Lock During Typing, Typing Effect, VN Dialogue UI

### Community 6 - "Scene Fallback and Layer UI"
Cohesion: 1.0
Nodes (3): Asset ID Fallback, VN Layer Stack, Layered Scene Mode

### Community 7 - "Asset Lane Separation"
Cohesion: 1.0
Nodes (2): General and Adult Asset Separation, Asset Library Manifest

### Community 8 - "Safety Policy Core"
Cohesion: 1.0
Nodes (2): Local Stack Freedom Rationale, Safety Guardrails

## Ambiguous Edges - Review These
- `Memory Hierarchy` → `Vector Memory Backend`  [AMBIGUOUS]
  raw/local_ai_server_prompt.md · relation: shares_data_with
- `Story Turn Endpoint` → `Audio Candidate Orchestration`  [AMBIGUOUS]
  raw/07_Sound_Orchestration.md · relation: references
- `Settings and Save Separation` → `Player Content Toggles`  [AMBIGUOUS]
  raw/09_Anti_Filter_Safety_Mechanism.md · relation: shares_data_with

## Knowledge Gaps
- **10 isolated node(s):** `Stub Backend Mode`, `Emotion-Driven Speech Shift`, `Style Anchor Rationale`, `Filtered Candidate Rationale`, `Continuity Check` (+5 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Asset Lane Separation`** (2 nodes): `General and Adult Asset Separation`, `Asset Library Manifest`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Safety Policy Core`** (2 nodes): `Local Stack Freedom Rationale`, `Safety Guardrails`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Memory Hierarchy` and `Vector Memory Backend`?**
  _Edge tagged AMBIGUOUS (relation: shares_data_with) - confidence is low._
- **What is the exact relationship between `Story Turn Endpoint` and `Audio Candidate Orchestration`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `Settings and Save Separation` and `Player Content Toggles`?**
  _Edge tagged AMBIGUOUS (relation: shares_data_with) - confidence is low._
- **Why does `Memory Hierarchy` connect `Narrative Memory Design` to `Turn and Content Orchestration`, `Save and Runtime Settings`?**
  _High betweenness centrality (0.342) - this node is a cross-community bridge._
- **Why does `Structured Turn Generation` connect `Turn and Content Orchestration` to `Narrative Memory Design`, `Model and Schema Runtime`, `Backend Integration Path`, `Save and Runtime Settings`, `Scene Fallback and Layer UI`?**
  _High betweenness centrality (0.299) - this node is a cross-community bridge._
- **Why does `VN State Snapshot Save` connect `Save and Runtime Settings` to `Narrative Memory Design`, `Turn and Content Orchestration`, `Scene Fallback and Layer UI`?**
  _High betweenness centrality (0.209) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `Memory Hierarchy` (e.g. with `Structured Speech Profile` and `VN State Snapshot Save`) actually correct?**
  _`Memory Hierarchy` has 3 INFERRED edges - model-reasoned connections that need verification._