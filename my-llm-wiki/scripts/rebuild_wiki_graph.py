import json
import re
from hashlib import sha1
from pathlib import Path

from graphify.analyze import god_nodes, suggest_questions, surprising_connections
from graphify.build import build_from_json
from graphify.cluster import cluster, score_all
from graphify.export import to_html, to_json
from graphify.report import generate


ROOT = Path(__file__).resolve().parent.parent
WIKI_DIR = ROOT / "wiki"
OUT_DIR = WIKI_DIR / "graphify-out"
LINK_RE = re.compile(r"\[\[([^\]|#]+)(?:[#|][^\]]*)?\]\]")


def slugify(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def make_node_id(path: Path) -> str:
    slug = slugify(path.stem)
    digest = sha1(path.name.encode("utf-8")).hexdigest()[:10]
    if slug:
        return f"wiki_{slug}_{digest}"
    return f"wiki_doc_{digest}"


def count_words(text: str) -> int:
    return len(re.findall(r"\S+", text))


def parse_docs():
    docs = []
    for path in sorted(WIKI_DIR.glob("*.md")):
        text = path.read_text(encoding="utf-8")
        docs.append(
            {
                "path": path,
                "title": path.stem,
                "text": text,
                "links": [match.strip() for match in LINK_RE.findall(text)],
            }
        )
    return docs


def build_extraction(docs):
    title_to_id = {doc["title"]: make_node_id(doc["path"]) for doc in docs}
    nodes = []
    edges = []

    for doc in docs:
        node_id = title_to_id[doc["title"]]
        nodes.append(
            {
                "id": node_id,
                "label": doc["title"],
                "file_type": "document",
                "source_file": f"wiki/{doc['path'].name}",
                "source_location": f"# {doc['title']}",
                "source_url": None,
                "captured_at": None,
                "author": None,
                "contributor": None,
            }
        )

        seen_targets = set()
        for link in doc["links"]:
            if link not in title_to_id:
                continue
            if link == doc["title"] or link in seen_targets:
                continue
            seen_targets.add(link)
            edges.append(
                {
                    "source": node_id,
                    "target": title_to_id[link],
                    "relation": "references",
                    "confidence": "EXTRACTED",
                    "confidence_score": 1.0,
                    "source_file": f"wiki/{doc['path'].name}",
                    "source_location": "## Related",
                    "weight": 1.0,
                }
            )

    return {
        "nodes": nodes,
        "edges": edges,
        "hyperedges": [],
        "input_tokens": 0,
        "output_tokens": 0,
    }


def label_communities(graph, communities):
    labels = {}
    for cid, node_ids in communities.items():
        titles = sorted(graph.nodes[node_id]["label"] for node_id in node_ids)
        if not titles:
            labels[cid] = f"Wiki Cluster {cid}"
        elif len(titles) == 1:
            labels[cid] = titles[0]
        else:
            labels[cid] = f"{titles[0]} + {titles[1]}"
    return labels


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    docs = parse_docs()
    extraction = build_extraction(docs)
    graph = build_from_json(extraction)
    communities = cluster(graph)
    cohesion = score_all(graph, communities)
    labels = label_communities(graph, communities)

    detection = {
        "total_files": len(docs),
        "total_words": sum(count_words(doc["text"]) for doc in docs),
        "needs_graph": False,
        "warning": None,
        "files": {
            "code": [],
            "document": [f"wiki/{doc['path'].name}" for doc in docs],
            "paper": [],
            "image": [],
            "video": [],
        },
        "skipped_sensitive": [],
    }

    questions = suggest_questions(graph, communities, labels)
    report = generate(
        graph,
        communities,
        cohesion,
        labels,
        god_nodes(graph),
        surprising_connections(graph, communities),
        detection,
        {"input": 0, "output": 0},
        str(WIKI_DIR.resolve()),
        suggested_questions=questions,
    )

    (OUT_DIR / "GRAPH_REPORT.md").write_text(report, encoding="utf-8")
    to_json(graph, communities, str(OUT_DIR / "graph.json"))
    to_html(graph, communities, str(OUT_DIR / "graph.html"), community_labels=labels)
    (OUT_DIR / "graphify_extract.json").write_text(
        json.dumps(extraction, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    (OUT_DIR / "analysis.json").write_text(
        json.dumps(
            {
                "communities": {str(k): v for k, v in communities.items()},
                "cohesion": {str(k): v for k, v in cohesion.items()},
                "labels": {str(k): v for k, v in labels.items()},
                "questions": questions,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )

    print(
        json.dumps(
            {
                "files": len(docs),
                "nodes": graph.number_of_nodes(),
                "edges": graph.number_of_edges(),
                "communities": len(communities),
                "output_dir": str(OUT_DIR),
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
