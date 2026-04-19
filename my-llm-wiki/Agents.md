# LLM Wiki Rules

## 역할
이 프로젝트는 LLM 기반 지식 위키다.

## 규칙
- raw/는 절대 수정하지 않는다
- wiki/에서만 정리한다
- 모든 문서는 markdown으로 작성
- 반드시 [[문서 링크]] 연결
- 중복 문서 금지

## 문서 구조

# Title

## Summary
짧은 요약

## Key Points
- ...

## Related
- [[다른 문서]]

## Sources
- raw/파일명

## graphify

This project has a graphify knowledge graph at graphify-out/.
The curated wiki also has its own graph at wiki/graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- Before restructuring or extending wiki docs, read wiki/graphify-out/GRAPH_REPORT.md for the curated wiki structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- After modifying code files in this session, run `graphify update .` to keep the graph current (AST-only, no API cost)
- After modifying `wiki/*.md`, run `powershell -File scripts/rebuild_wiki_graph.ps1`
