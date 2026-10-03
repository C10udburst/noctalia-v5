#!/bin/sh
# Ultra-fast Nix package search using fzf.
# Usage: search.sh <query> [index_tsv_file] [limit]

QUERY="$1"
INDEX_FILE="$2"
LIMIT="${3:-50}"

# Clean environment to prevent custom user options from modifying output structure
export FZF_DEFAULT_OPTS=""

# Resolve index file if not provided or missing
if [ -z "$INDEX_FILE" ] || [ ! -f "$INDEX_FILE" ]; then
    INDEX_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/noctalia-nix/nix-desktop-index.tsv"
    if [ ! -f "$INDEX_FILE" ]; then
        exit 2
    fi
fi

# If query is empty, return top packages
if [ -z "$QUERY" ]; then
    head -n "$LIMIT" "$INDEX_FILE"
    exit 0
fi

# Run fzf with native fuzzy search, field indexing, and length/begin tiebreaking
if command -v fzf >/dev/null 2>&1; then
    fzf --filter="$QUERY" \
        --delimiter="\t" \
        --nth=1,2,3 \
        --tiebreak=begin,length,index \
        < "$INDEX_FILE" 2>/dev/null | head -n "$LIMIT"
    exit 0
fi

# Fallback to case-insensitive grep if fzf is not installed
grep -i "$QUERY" "$INDEX_FILE" 2>/dev/null | head -n "$LIMIT"
exit 0
