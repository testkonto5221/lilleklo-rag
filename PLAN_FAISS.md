# FAISS Integration Plan

This document defines a pragmatic, implementation-focused plan to integrate FAISS as the vector index for the RAG project. It covers objectives, architecture, data flow, implementation details, testing, deployment, monitoring, rollback, and a realistic timeline with milestones.

**Audience:** engineers implementing the index, ML engineers selecting embedding models, and DevOps who will deploy & monitor the index.

---

## 1. Goals and Success Criteria
- **Goals:**
  - Provide a fast, accurate vector search layer for retrieval-augmented generation (RAG).
  - Scale to millions of vectors with acceptable latency (goal: median <100ms for nearest-neighbor queries at target scale) and predictable memory usage.
  - Support persistence, backups, and easy migration from the existing store.
- **Success criteria:**
  - End-to-end pipeline returns relevant documents that increase final-generation accuracy by a measurable margin (A/B test or offline metric).
  - Index rebuild and restore procedures complete within operational limits (e.g., full rebuild < 2 hours for expected N on chosen infra).
  - Monitoring alerts for query latency, index corruption, and space usage are in place.

## 2. Scope & Constraints
- Include: embeddings pipeline, indexing (FAISS), retrieval API, CLI tooling, migration scripts, unit + integration tests, benchmarks, deployment manifests.
- Exclude: changes to the language model service and UI beyond retrieval parameters.
- Constraints: prefer CPU-based FAISS (`faiss-cpu`) initially; evaluate GPU (`faiss-gpu`) later if throughput requires it.

## 3. High-level Architecture
- Components:
  - Embedding service: produces fixed-size vectors for documents/queries.
  - FAISS index store: vector index files persisted to disk/object store.
  - Metadata DB: stores document metadata and maps vector ids to documents (SQLite/Postgres).
  - Retrieval API: loads FAISS index, accepts query embeddings, returns top-k doc IDs and scores.
  - RAG orchestrator: fetches documents by ID and passes them to the LLM.

- Data flow:
  1. Ingest -> embedding service -> store vector + metadata.
  2. On-write or batched indexing -> FAISS index update.
  3. Query -> embed -> FAISS search -> fetch metadata -> return candidates.

## 4. Data model and storage
- Vector id: unique integer mapped to document UUID in metadata DB.
- Index metadata: record embedding dimension (D), model name & version, index type, creation timestamp.
- Storage options:
  - Local filesystem for dev/smaller deployments.
  - Object storage (S3/GCS) for snapshots and backups in production.

## 5. Index choices & tuning
- Small N (<200k): IndexFlat (exact) for simplicity.
- Large N: HNSW (`IndexHNSWFlat`) or IVF+PQ (`IndexIVFPQ`):
  - HNSW: good recall, no training, recommended default.
  - IVF+PQ: smaller memory footprint, needs training, faster at scale with disk-backed indices.
- Default tuning (starting point): HNSW with `M=32`, `efConstruction=200`, and per-query `efSearch=128`.

## 6. Embeddings
- Use a pinned `sentence-transformers` model; document model name/version in index metadata.
- Normalize vectors to unit length when using inner product for cosine similarity.

## 7. Persistence, snapshots, migration
- Save index: `faiss.write_index(index, path)`; include metadata JSON alongside index file.
- Snapshots: create time-stamped snapshots and upload to object storage; keep N snapshots for rollback.
- Migration sequence:
  1. Export documents + metadata from current store.
  2. Compute embeddings in batch.
  3. Train index (if needed) and build + persist snapshot.
  4. Validate via recall tests on held-out queries.
  5. Cutover with canary traffic; keep previous snapshot as fallback.

## 8. CLI & developer tooling
- Example CLI commands:
  - Build: `rag-faiss build --input data/ --out indexes/ --model all-MiniLM-L6-v2 --index-type hnsw`
  - Query: `rag-faiss query --index indexes/idx.faiss --text "how to..." --k 10`
  - Snapshot: `rag-faiss snapshot --index indexes/idx.faiss --out s3://bucket/snapshots/`

## 9. Implementation tasks
- Phase A — Prototype (1–2 weeks): pick embedding model, implement `FAISSVectorStore`, add basic CLI, validate on small dataset.
- Phase B — Hardening (2–4 weeks): metadata DB, batched updates, snapshots, CI tests.
- Phase C — Rollout (1 week): canary, monitoring, cutover.

## 10. Example `FAISSVectorStore` (concise)
```python
import faiss
import numpy as np

class FAISSVectorStore:
    def __init__(self, dim: int, index: faiss.Index = None):
        self.dim = dim
        self.index = index

    def build_hnsw(self, M=32, ef_construction=200):
        self.index = faiss.IndexHNSWFlat(self.dim, M, faiss.METRIC_INNER_PRODUCT)
        self.index.hnsw.efConstruction = ef_construction

    def add(self, vectors: np.ndarray):
        vectors = vectors.astype('float32')
        self.index.add(vectors)

    def search(self, q: np.ndarray, k: int = 10):
        q = q.astype('float32')
        D, I = self.index.search(q, k)
        return D, I

    def save(self, path: str):
        faiss.write_index(self.index, path)

    def load(self, path: str):
        self.index = faiss.read_index(path)
```

## 11. Benchmarks & tests
- Benchmarks:
  - Build time and memory for varying N
  - Query latency distribution (p50/p90/p99)
  - Recall@k against exact baseline
- Provide `bench` scripts to run these reproducibly.

## 12. Monitoring & alerts
- Emit metrics: query latency histogram, QPS, index size, snapshot success/failure.
- Alerts for high p99 latency, index load failures, snapshot failures.

## 13. Rollback & recovery
- Keep previous snapshot until new index validated for a configurable period.
- Restore flow: download snapshot, load into retrieval API using atomic replace (write-to-temp + rename).

## 14. Security
- Limit write access to index/snapshot storage and retrieval API authentication.

## 15. Timeline & milestones
- Week 1–2: prototype + smoke tests.
- Week 3–4: hardening, snapshots, metadata.
- Week 5: canary and production cutover.

## 16. Pre-cutover checklist
- [ ] Embedding model pinned
- [ ] Snapshot & restore tested
- [ ] Monitoring + alerts configured
- [ ] Migration validated on subset
- [ ] Rollback documented

## 17. References
- FAISS: https://github.com/facebookresearch/faiss

---

Next actions I can take for you:
- Implement `FAISSVectorStore` and a `rag-faiss` CLI module.
- Add benchmark scripts under `bench/` and a small test dataset.
- Add `faiss-cpu` and `sentence-transformers` suggestions to `requirements.txt`.

Which should I do next?
