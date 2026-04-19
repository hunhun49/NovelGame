# Graph Report - C:\Users\hunhun0409\Documents\projects\NovelGame\my-llm-wiki\wiki  (2026-04-18)

## Corpus Check
- 9 files · ~1,409 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 9 nodes · 23 edges · 2 communities detected
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_index + 메인 메뉴와 플레이 UI|index + 메인 메뉴와 플레이 UI]]
- [[_COMMUNITY_Godot 전역 서비스 + 자산 라이브러리와 오디오|Godot 전역 서비스 + 자산 라이브러리와 오디오]]

## God Nodes (most connected - your core abstractions)
1. `index` - 8 edges
2. `Godot 전역 서비스` - 6 edges
3. `스토리 턴 파이프라인` - 6 edges
4. `메인 메뉴와 플레이 UI` - 5 edges
5. `세이브와 세션 상태` - 5 edges
6. `백엔드 API와 모델 파이프라인` - 4 edges
7. `자산 라이브러리와 오디오` - 4 edges
8. `콘텐츠 제작 도구` - 4 edges
9. `프로젝트 구조와 실행` - 4 edges

## Surprising Connections (you probably didn't know these)
- `스토리 턴 파이프라인` --references--> `Godot 전역 서비스`  [EXTRACTED]
  wiki/스토리 턴 파이프라인.md → wiki/Godot 전역 서비스.md
- `세이브와 세션 상태` --references--> `Godot 전역 서비스`  [EXTRACTED]
  wiki/세이브와 세션 상태.md → wiki/Godot 전역 서비스.md
- `index` --references--> `Godot 전역 서비스`  [EXTRACTED]
  wiki/index.md → wiki/Godot 전역 서비스.md
- `프로젝트 구조와 실행` --references--> `Godot 전역 서비스`  [EXTRACTED]
  wiki/프로젝트 구조와 실행.md → wiki/Godot 전역 서비스.md
- `index` --references--> `콘텐츠 제작 도구`  [EXTRACTED]
  wiki/index.md → wiki/콘텐츠 제작 도구.md

## Communities

### Community 0 - "index + 메인 메뉴와 플레이 UI"
Cohesion: 0.8
Nodes (6): 백엔드 API와 모델 파이프라인, 세이브와 세션 상태, 프로젝트 구조와 실행, 스토리 턴 파이프라인, index, 메인 메뉴와 플레이 UI

### Community 1 - "Godot 전역 서비스 + 자산 라이브러리와 오디오"
Cohesion: 1.0
Nodes (3): 콘텐츠 제작 도구, 자산 라이브러리와 오디오, Godot 전역 서비스

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `index` connect `index + 메인 메뉴와 플레이 UI` to `Godot 전역 서비스 + 자산 라이브러리와 오디오`?**
  _High betweenness centrality (0.171) - this node is a cross-community bridge._
- **Why does `Godot 전역 서비스` connect `Godot 전역 서비스 + 자산 라이브러리와 오디오` to `index + 메인 메뉴와 플레이 UI`?**
  _High betweenness centrality (0.080) - this node is a cross-community bridge._
- **Why does `스토리 턴 파이프라인` connect `index + 메인 메뉴와 플레이 UI` to `Godot 전역 서비스 + 자산 라이브러리와 오디오`?**
  _High betweenness centrality (0.067) - this node is a cross-community bridge._