#!/usr/bin/env python3
"""
Unicode search helper for Noctalia launcher.
Searches Unicode characters by name, codepoint (hex/decimal), or character literal.
Outputs a minimal JSON array of [char, name] pairs on stdout.
"""

import sys
import os
import re
import json
import unicodedata

# Ensure UTF-8 output
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

CACHE_DIR = os.path.expanduser("~/.cache/noctalia")
CACHE_FILE = os.path.join(CACHE_DIR, "unicode_chars.json")
RECENT_FILE = os.path.join(CACHE_DIR, "unicode_recent.json")
MAX_RECENT = 25
MAX_RESULTS = 50

# Curated default list of commonly needed characters when query is empty
POPULAR_CODEPOINTS = [
    # Arrows
    0x2192, 0x2190, 0x2191, 0x2193, 0x21D2, 0x21D0, 0x2194, 0x21A9, 0x21AA,
    # Checks, Crosses & Stars
    0x2713, 0x2714, 0x2705, 0x2717, 0x2718, 0x274C, 0x2605, 0x2606, 0x2728,
    # Symbols & Emoji
    0x1F525, 0x1F44D, 0x1F44E, 0x1F389, 0x1F680, 0x2764, 0x1F60A, 0x1F602, 0x1F480, 0x1F4A1, 0x26A0,
    # Typography & Punctuation
    0x2014, 0x2013, 0x2026, 0x2022, 0x00B0, 0x00A9, 0x00AE, 0x2122, 0x00A7, 0x00B6, 0x00BF, 0x00A1,
    # Currency
    0x20AC, 0x0024, 0x00A3, 0x00A5, 0x20BD, 0x20BF, 0x20B9,
    # Math
    0x221E, 0x2248, 0x2260, 0x2264, 0x2265, 0x00B1, 0x00D7, 0x00F7, 0x221A, 0x2211, 0x222B,
    # Greek
    0x03C0, 0x03BB, 0x03A9, 0x0394, 0x03BC, 0x03C3, 0x03B8, 0x03B1, 0x03B2,
]

EXPANSIONS = {
    "RIGHT": "RIGHTWARDS",
    "LEFT": "LEFTWARDS",
    "UP": "UPWARDS",
    "DOWN": "DOWNWARDS",
    "LAMBDA": "LAMDA",
}


def build_cache():
    """Build pre-indexed unicode list skipping massive CJK/Hangul algorithmic blocks."""
    items = []
    for cp in range(0x110000):
        try:
            ch = chr(cp)
            name = unicodedata.name(ch)
            # Skip massive repetitive algorithmic name blocks (CJK ~90k, Hangul ~11k)
            if not name.startswith(("CJK UNIFIED IDEOGRAPH", "HANGUL SYLLABLE")):
                items.append([cp, ch, name])
        except ValueError:
            pass

    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        with open(CACHE_FILE, "w", encoding="utf-8") as f:
            json.dump(items, f, ensure_ascii=False, separators=(",", ":"))
    except OSError:
        pass
    return items


def load_items():
    """Load items from cache file or generate if absent."""
    if os.path.isfile(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return build_cache()


def record_recent(char_str):
    """Save used character to recent history file."""
    if not char_str:
        return
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        recent = []
        if os.path.isfile(RECENT_FILE):
            with open(RECENT_FILE, "r", encoding="utf-8") as f:
                recent = json.load(f)
        if char_str in recent:
            recent.remove(char_str)
        recent.insert(0, char_str)
        recent = recent[:MAX_RECENT]
        with open(RECENT_FILE, "w", encoding="utf-8") as f:
            json.dump(recent, f, ensure_ascii=False, separators=(",", ":"))
    except Exception:
        pass


def get_recent_chars():
    try:
        if os.path.isfile(RECENT_FILE):
            with open(RECENT_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
    except Exception:
        pass
    return []


def default_results():
    results = []
    seen = set()

    for ch in get_recent_chars():
        if len(ch) >= 1:
            cp = ord(ch[0])
            if cp not in seen:
                try:
                    name = unicodedata.name(ch[0])
                    results.append([ch[0], name])
                    seen.add(cp)
                except ValueError:
                    pass

    for cp in POPULAR_CODEPOINTS:
        if cp not in seen:
            try:
                ch = chr(cp)
                name = unicodedata.name(ch)
                results.append([ch, name])
                seen.add(cp)
            except ValueError:
                pass

    return results[:MAX_RESULTS]


def calculate_score(name, cp, query_words, raw_upper):
    if name == raw_upper:
        return 10000

    score = 1000
    name_words = name.split()
    exact_words_matched = 0

    for w in query_words:
        alt = EXPANSIONS.get(w)
        if w in name_words or (alt and alt in name_words):
            exact_words_matched += 1
        elif any(nw.startswith(w) for nw in name_words):
            score += 150
        elif w in name:
            score += 50

    score += exact_words_matched * 1200
    if exact_words_matched == len(query_words):
        score += 800

    if name_words:
        first_q = query_words[0]
        alt_first = EXPANSIONS.get(first_q)
        if name_words[0] == first_q or (alt_first and name_words[0] == alt_first):
            score += 400
        elif name_words[0].startswith(first_q):
            score += 200

    if name.startswith(raw_upper):
        score += 200

    if cp <= 0xFFFF:
        score += 200

    if 0x2190 <= cp <= 0x27FF or 0x2000 <= cp <= 0x206F:
        score += 200

    score -= len(name) * 3
    extra_words = max(0, len(name_words) - len(query_words))
    score -= extra_words * 80

    return score


def search(query, limit=MAX_RESULTS):
    raw = query.strip()
    if not raw:
        return default_results()

    results = []
    seen = set()

    # 1. Exact single character match (e.g. pasted symbol)
    if len(raw) == 1:
        cp = ord(raw)
        try:
            name = unicodedata.name(raw)
            results.append([raw, name])
            seen.add(cp)
        except ValueError:
            pass

    # 2. Hex codepoint match: U+2192, 0x2192, or 2192
    hex_match = re.match(r"^(?:[Uu]\+?|0[Xx])?([0-9a-fA-F]{1,6})$", raw)
    if hex_match:
        try:
            cp = int(hex_match.group(1), 16)
            if cp <= 0x10FFFF and cp not in seen:
                ch = chr(cp)
                try:
                    name = unicodedata.name(ch)
                    results.append([ch, name])
                    seen.add(cp)
                except ValueError:
                    pass
        except ValueError:
            pass

    # 3. Decimal codepoint match: #8594
    dec_match = re.match(r"^#([0-9]{1,7})$", raw)
    if dec_match:
        try:
            cp = int(dec_match.group(1), 10)
            if cp <= 0x10FFFF and cp not in seen:
                ch = chr(cp)
                try:
                    name = unicodedata.name(ch)
                    results.append([ch, name])
                    seen.add(cp)
                except ValueError:
                    pass
        except ValueError:
            pass

    # 4. Name search
    q_upper = raw.upper()
    words = q_upper.split()

    items = load_items()
    scored = []

    for cp, ch, name in items:
        if cp in seen:
            continue

        match_all = True
        for w in words:
            alt = EXPANSIONS.get(w)
            if (w not in name) and (not alt or alt not in name):
                match_all = False
                break

        if not match_all:
            continue

        final_score = calculate_score(name, cp, words, q_upper)
        scored.append((final_score, cp, ch, name))

    scored.sort(key=lambda x: x[0], reverse=True)

    for item in scored[: limit - len(results)]:
        score, cp, ch, name = item
        results.append([ch, name])

    # 5. Fallback exact lookup (e.g. CJK or Hangul full name)
    if len(results) == 0:
        try:
            ch = unicodedata.lookup(q_upper)
            results.append([ch, q_upper])
        except KeyError:
            pass

    return results[:limit]


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--record":
        if len(sys.argv) > 2:
            record_recent(sys.argv[2])
        sys.exit(0)

    if len(sys.argv) > 1 and sys.argv[1] == "--build-cache":
        build_cache()
        print("Cache built successfully.")
        sys.exit(0)

    query = sys.argv[1] if len(sys.argv) > 1 else ""
    results = search(query)
    print(json.dumps(results, ensure_ascii=False, separators=(",", ":")))


if __name__ == "__main__":
    main()
