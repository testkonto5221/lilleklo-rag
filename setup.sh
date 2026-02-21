#!/bin/bash
# Setup script for lilleklo-rag
# Run this on the target machine to install the RAG system.

set -e

VENV_DIR="$HOME/.openclaw/workspace/rag/venv"
BIN_DIR="$HOME/.local/bin"

echo "Creating virtual environment at $VENV_DIR ..."
python3 -m venv "$VENV_DIR"

echo "Installing dependencies ..."
"$VENV_DIR/bin/pip" install --upgrade pip -q
"$VENV_DIR/bin/pip" install -r requirements.txt

echo "Installing rag CLI to $BIN_DIR ..."
mkdir -p "$BIN_DIR"
cp rag "$BIN_DIR/rag"

# Update shebang to point to the correct venv python
sed -i "1s|.*|#!$VENV_DIR/bin/python3|" "$BIN_DIR/rag"
chmod +x "$BIN_DIR/rag"

echo ""
echo "Done! Run 'rag' to get started."
echo "The embedding model (~90MB) will download automatically on first use."
