# Architecture

Local, private RAG (Retrieval-Augmented Generation) system running on a Raspberry Pi 5.
All processing happens on-device — no data leaves the machine.

## System Overview

```mermaid
graph TB
    User["👤 Lars (Telegram)"]
    Lilleklo["🐾 Lilleklo\nOpenClaw Agent\ngemini-2.5-flash-lite"]
    RAG["rag CLI"]
    Embed["Embedding Model\nall-MiniLM-L6-v2"]
    DB[("ChromaDB\n~/.openclaw/workspace/rag/db/")]
    Sources["📄 Sources\nPDF / URL / Text / MOBI"]

    User -- "Telegram message" --> Lilleklo
    Lilleklo -- "rag add / query / remove / list" --> RAG
    Sources -- "input" --> RAG
    RAG -- "encode text" --> Embed
    Embed -- "384-dim vectors" --> RAG
    RAG -- "store / search" --> DB
    DB -- "relevant chunks" --> RAG
    RAG -- "results" --> Lilleklo
    Lilleklo -- "answer with context" --> User
```

## Ingestion Flow

```mermaid
sequenceDiagram
    participant U as Lars
    participant L as Lilleklo
    participant R as rag CLI
    participant E as Embedding Model
    participant D as ChromaDB

    U->>L: "Add this PDF to the knowledge base"
    L->>R: rag add document.pdf "my-doc"
    R->>R: Extract text (pdfplumber / URL fetch / stdin)
    R->>R: Chunk text (800 chars, 100 overlap)
    R->>E: Encode all chunks
    E-->>R: 384-dim float vectors
    R->>D: Delete existing chunks for "my-doc" (if any)
    R->>D: Store chunks + vectors + metadata
    D-->>R: ✓
    R-->>L: "Added 'my-doc' — 42 chunk(s)"
    L-->>U: ✅ Ingested
```

## Query Flow

```mermaid
sequenceDiagram
    participant U as Lars
    participant L as Lilleklo
    participant R as rag CLI
    participant E as Embedding Model
    participant D as ChromaDB

    U->>L: "What does the report say about X?"
    L->>R: rag query "What does the report say about X?" 5
    R->>E: Encode query
    E-->>R: 384-dim query vector
    R->>D: Cosine similarity search (top 5)
    D-->>R: Ranked chunks + source metadata
    R-->>L: Chunks with source name + relevance score
    L->>L: Compose answer using retrieved context
    L-->>U: Answer with cited sources
```

## Component Breakdown

```mermaid
graph LR
    subgraph Pi5["Raspberry Pi 5 (on-device)"]
        subgraph OpenClaw["OpenClaw Platform"]
            Agent["Lilleklo Agent\ngemini-2.5-flash-lite"]
            Hooks["Internal Hooks\nsession-memory\nboot-md"]
            Workspace["Workspace\nSOUL / AGENTS / TOOLS\nMEMORY / RAG.md"]
        end

        subgraph RAGSystem["RAG System"]
            CLI["rag CLI\n~/.local/bin/rag"]
            Venv["Python venv\nworkspace/rag/venv/"]
            Model["all-MiniLM-L6-v2\n~90MB, CPU inference"]
            VectorDB[("ChromaDB\nworkspace/rag/db/")]
        end

        subgraph Inputs["Supported Inputs"]
            PDF["PDF files\npdfplumber"]
            URLs["Web URLs\nHTML → text"]
            Text["Plain text\nstdin / string"]
        end
    end

    Telegram["📱 Telegram Bot"] --> Agent
    Agent --> CLI
    CLI --> Venv
    Venv --> Model
    Venv --> VectorDB
    Inputs --> CLI
```

## Data Storage

```mermaid
graph TD
    subgraph DB["ChromaDB Collection: knowledge"]
        Doc1["Chunk\nid: abc123-chunk-0\ndocument: text content\nmetadata: source, chunk index\nembedding: [0.12, -0.34, ...]"]
        Doc2["Chunk\nid: abc123-chunk-1\n..."]
        Doc3["Chunk\nid: xyz789-chunk-0\n..."]
    end

    Q["Query vector"] -- "cosine similarity" --> DB
    DB -- "top-N ranked results" --> R["Results"]
```

## CLI Commands

```mermaid
graph LR
    CLI["rag"]
    CLI --> Add["add\nIngest document\nfile · url · stdin · text"]
    CLI --> Query["query\nSemantic search\nreturns top-N chunks"]
    CLI --> Remove["remove\nDelete by source name\nremoves all chunks"]
    CLI --> List["list\nShow all sources\nwith chunk counts"]
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Agent | OpenClaw + gemini-2.5-flash-lite (via OpenRouter) |
| CLI | Python 3.13, single-file script |
| Embeddings | `sentence-transformers` / `all-MiniLM-L6-v2` |
| Vector store | ChromaDB 1.5 (persistent, embedded) |
| PDF extraction | pdfplumber |
| Runtime | Python venv (isolated from system Python) |
| Hardware | Raspberry Pi 5, 8GB RAM, ARM64 |


## Recent changes (last 2 commits)

- **HTML ingestion improvements**: `rag` now includes a robust `HTMLTextExtractor` based on `html.parser` that strips scripts/styles, decodes entities, preserves headings, lists and table structure, and extracts metadata such as `title` and `description` for each source.
- **Text quality pipeline**: added `validate_url()`, `normalize_text()` (whitespace/boilerplate removal, encoding heuristics) and `semantic_chunk_text()` to produce cleaner, semantically-bounded chunks before embedding.
- **Resilience & observability**: basic `logging` configuration and placeholders for retry logic (`tenacity`) were added to improve fetch reliability and debugging.
- **Table & caption handling**: table rows and figure captions are converted into readable text so tabular content is preserved in chunks.
- These updates improve HTML/source ingestion quality and retrieval relevance; embedding model (`all-MiniLM-L6-v2`) and ChromaDB usage remain unchanged.

## Diagrams — quick explanations

- **System Overview**: shows the end-to-end interaction: the user sends a message to the Lilleklo agent, the agent calls the `rag` CLI to add/query sources, `rag` encodes text via the embedding model and stores/searches vectors in ChromaDB, and Lilleklo composes answers using retrieved chunks.
- **Ingestion Flow**: step-by-step of `rag add`: extract text (PDF/URL/stdin), normalize and semantically chunk the text, encode chunks to embeddings, and persist chunks + metadata to ChromaDB. Recent changes mainly affect the extraction and chunking steps.
- **Query Flow**: a query is encoded to a vector, used to run a cosine-similarity search in ChromaDB, top-N chunks are returned with source metadata and relevance scores, and Lilleklo composes an answer citing sources.
- **Component Breakdown**: maps physical/runtime pieces on the Pi (OpenClaw agent, Python venv, embedding model, ChromaDB) and supported input types (PDF, URL, text). It clarifies which components run on-device.
- **Data Storage**: describes the ChromaDB collection and what each stored chunk contains (id, source name, chunk index, embedding vector and metadata) — used for fast similarity search and provenance.
- **CLI Commands**: `rag add` (ingest), `rag query` (semantic search), `rag remove` (delete by source name), `rag list` (show sources and chunk counts). Each command maps to the flows shown above.
