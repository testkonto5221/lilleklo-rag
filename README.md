# RAG.md — Local Knowledge Base

Lilleklo has a fully local, private RAG (Retrieval-Augmented Generation) knowledge base.
Documents are stored as vector embeddings on disk — nothing leaves the Raspberry Pi.

## Quick Reference

```bash
rag add <file|url|-> [source_name]   # Ingest a document
rag query <question> [n]             # Search the knowledge base
rag remove <source_name>             # Delete a document by name
rag list                             # Show all ingested sources
```

## Adding Documents

**From a file:**
```bash
rag add /path/to/document.pdf
rag add /path/to/notes.txt "my-notes"
rag add /path/to/report.md
```

**From a URL:**
```bash
rag add https://example.com/article "article-name"
```

**From stdin (piped text):**
```bash
echo "Some text to remember" | rag add - "quick-note"
cat somefile.txt | rag add - "somefile"
```

**From raw text directly:**
```bash
rag add "Short note to store verbatim" "note-name"
```

If no source name is given, the filename or URL is used automatically.
Adding a document with an existing source name **replaces** the old version.

## Querying

```bash
rag query "What did the report say about energy costs?"
rag query "summarize the contract terms" 3       # return top 3 results
```

Results include the source name, chunk number, and relevance score (0–1).
Higher score = more relevant.

## Removing Documents

```bash
rag remove report.pdf
rag remove "my-notes"
```

If the source name is wrong, the command will show available sources as a hint.

## Listing Sources

```bash
rag list
```

Shows all ingested source names and their chunk counts.

## Supported Formats

| Format | Notes |
|--------|-------|
| PDF | Text extracted via pdfplumber; scanned/image-only PDFs won't work |
| Plain text (.txt, .md, .csv, etc.) | Any UTF-8 text file |
| Web pages (URLs) | HTML stripped, plain text extracted |
| Raw text | Pass as a string argument or via stdin |

## Technical Details

- **Embedding model:** `all-MiniLM-L6-v2` (runs locally, ~22MB, no internet needed after first load)
- **Vector store:** ChromaDB (persistent, stored at `workspace/rag/db/`)
- **Chunk size:** ~800 characters with 100-character overlap
- **Python venv:** `workspace/rag/venv/` (isolated from system Python)

## Via Telegram

Lars can instruct Lilleklo to manage the knowledge base directly from Telegram:

- "Add this to my knowledge base: [text]"
- "Ingest this URL: https://..."
- "Ingest the file at ~/documents/report.pdf"
- "What's in my knowledge base about X?"
- "Remove report.pdf from the knowledge base"
- "List everything in the knowledge base"

> **File attachments via Telegram:** Untested — depends on whether openclaw passes
> Telegram file metadata to the agent. If it does, Lilleklo can download and ingest
> attachments directly. Test by sending a file to the bot.

## Using RAG in Responses

Before answering questions that might be covered by the knowledge base, query it first:

```bash
rag query "relevant question here" 5
```

Incorporate the results as context in your answer. Always cite the source name so Lars
knows where the information came from.
