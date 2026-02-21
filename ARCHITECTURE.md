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
