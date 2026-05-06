#!/usr/bin/env python3
"""Split monolithic palette/melodies/*.scd and palette/rhythm/*.scd files
into one-file-per-unit structure.

Strategy A (melodies short/long/xlong/epic, kicks STOCKAGE bloc):
    Each top-level `~varname = ...;` (statement) becomes its own file.

Strategy B (rhythm drum_kits, patterns_genre, percussions, sequences, fills):
    Each top-level `(...)` block becomes its own file. Filename derived from
    the closest preceding `// === NAME ===` header comment.
"""

from __future__ import annotations
import os
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PAL = ROOT / "palette"


# ---------------------------------------------------------------------------
# Tokenizer-aware bracket scanner. Tracks (), [], strings, line/block comments.
# Returns the list of top-level statements/blocks with character positions.
# ---------------------------------------------------------------------------

def scan_top_level(src: str):
    """Yield (start, end, kind) for each top-level item.

    kind = 'block' if the item is a `(...)` paren block at depth 0
           'stmt'  if it's a top-level statement (ends at `;` at depth 0)
    Whitespace and comments between items are skipped (start points at first
    non-ws char of the item).
    """
    i = 0
    n = len(src)
    items = []

    def skip_ws_and_comments(j):
        while j < n:
            c = src[j]
            if c in " \t\r\n":
                j += 1
            elif src.startswith("//", j):
                # line comment
                k = src.find("\n", j)
                j = n if k == -1 else k + 1
            elif src.startswith("/*", j):
                k = src.find("*/", j + 2)
                j = n if k == -1 else k + 2
            else:
                return j
        return j

    while i < n:
        i = skip_ws_and_comments(i)
        if i >= n:
            break

        start = i
        c = src[i]
        if c == "(":
            # consume balanced paren block
            depth = 0
            in_str = False
            in_sym = False
            j = i
            while j < n:
                ch = src[j]
                if in_str:
                    if ch == "\\":
                        j += 2
                        continue
                    if ch == '"':
                        in_str = False
                    j += 1
                    continue
                if in_sym:
                    # symbol literal: 'foo bar'
                    if ch == "\\":
                        j += 2
                        continue
                    if ch == "'":
                        in_sym = False
                    j += 1
                    continue
                if ch == '"':
                    in_str = True
                    j += 1
                    continue
                if ch == "'":
                    in_sym = True
                    j += 1
                    continue
                if src.startswith("//", j):
                    k = src.find("\n", j)
                    j = n if k == -1 else k + 1
                    continue
                if src.startswith("/*", j):
                    k = src.find("*/", j + 2)
                    j = n if k == -1 else k + 2
                    continue
                if ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                    if depth == 0:
                        j += 1
                        # consume optional trailing `;`
                        k = j
                        while k < n and src[k] in " \t":
                            k += 1
                        if k < n and src[k] == ";":
                            j = k + 1
                        items.append((start, j, "block"))
                        i = j
                        break
                j += 1
            else:
                raise ValueError(f"unbalanced ( at offset {start}")
        else:
            # top-level statement -> read until `;` at depth 0 of [] and ()
            depth_p = 0
            depth_b = 0
            in_str = False
            in_sym = False
            j = i
            while j < n:
                ch = src[j]
                if in_str:
                    if ch == "\\":
                        j += 2
                        continue
                    if ch == '"':
                        in_str = False
                    j += 1
                    continue
                if in_sym:
                    if ch == "\\":
                        j += 2
                        continue
                    if ch == "'":
                        in_sym = False
                    j += 1
                    continue
                if ch == '"':
                    in_str = True
                    j += 1
                    continue
                if ch == "'":
                    in_sym = True
                    j += 1
                    continue
                if src.startswith("//", j):
                    k = src.find("\n", j)
                    j = n if k == -1 else k + 1
                    continue
                if src.startswith("/*", j):
                    k = src.find("*/", j + 2)
                    j = n if k == -1 else k + 2
                    continue
                if ch == "(":
                    depth_p += 1
                elif ch == ")":
                    depth_p -= 1
                elif ch == "[":
                    depth_b += 1
                elif ch == "]":
                    depth_b -= 1
                elif ch == ";" and depth_p == 0 and depth_b == 0:
                    j += 1
                    items.append((start, j, "stmt"))
                    i = j
                    break
                j += 1
            else:
                # EOF without `;` -- emit rest as stmt
                items.append((start, n, "stmt"))
                i = n
    return items


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def slugify(s: str) -> str:
    s = s.lower().strip()
    s = re.sub(r"[\(\)\[\]\{\}]", " ", s)
    s = re.sub(r"[^a-z0-9_\- ]+", "", s)
    s = re.sub(r"\s+", "_", s)
    s = re.sub(r"_+", "_", s).strip("_-")
    return s or "block"


def find_block_header(src: str, block_start: int) -> str | None:
    """Look immediately before block_start for the closest header comment.

    Walks backward over whitespace/blank lines, then tries to identify the
    nearest comment header preceding the block. Recognized forms:

      // === NAME ===
      // ----- NAME -----
      // =====================
      // NAME
      // =====================
      // ---- NAME (extra) ----
    """
    # Walk back, collecting at most ~12 preceding non-empty comment lines
    # (skipping blank lines).
    end = block_start
    # find start of the line containing block_start
    while end > 0 and src[end - 1] != "\n":
        end -= 1
    # collect lines going backward
    lines = []
    pos = end
    while pos > 0:
        # back up one line
        line_end = pos - 1  # the \n
        line_start = src.rfind("\n", 0, line_end)
        line_start = 0 if line_start == -1 else line_start + 1
        line = src[line_start:line_end]
        stripped = line.strip()
        if stripped == "":
            # blank line: only allowed BEFORE we have any header line
            if lines:
                break
            pos = line_start
            continue
        if not stripped.startswith("//"):
            break
        lines.append(stripped)
        pos = line_start
        if len(lines) >= 12:
            break
    if not lines:
        return None
    # lines is in reverse order: lines[0] is the line directly above the block
    # Look at lines[0] first
    def extract(comment_line: str) -> str | None:
        s = comment_line.lstrip("/").strip()
        # strip leading/trailing runs of = or -
        s = re.sub(r"^[=\-\s]+", "", s)
        s = re.sub(r"[=\-\s]+$", "", s)
        # Remove any "(extra)" trailing parens content
        s = re.sub(r"\([^)]*\)\s*$", "", s).strip()
        if not s:
            return None
        # Reject if pure separators leftover
        if re.fullmatch(r"[=\-\s]+", s):
            return None
        return s

    # Form A: line 0 is `// === NAME ===` or `// ---- NAME ----`
    # Some lines could be just `// =====` (separator). Detect those.
    def is_separator(line: str) -> bool:
        s = line.lstrip("/").strip()
        return bool(re.fullmatch(r"[=\-\s]+", s))

    # If lines[0] is a NAME-bearing line:
    if not is_separator(lines[0]):
        cand = extract(lines[0])
        if cand:
            return cand
    # Otherwise lines[0] is a separator -> look for `// NAME` between two separators
    if is_separator(lines[0]) and len(lines) >= 3 and is_separator(lines[2]):
        cand = extract(lines[1])
        if cand:
            return cand
    # Try lines[1] anyway
    if len(lines) >= 2:
        cand = extract(lines[1])
        if cand:
            return cand
    return None


VAR_RE = re.compile(r"^\s*~([a-zA-Z][a-zA-Z0-9_]*)\s*=", re.MULTILINE)


def find_stmt_var(src: str, start: int, end: int) -> str | None:
    m = VAR_RE.search(src, start, end)
    return m.group(1) if m else None


def find_inner_var_in_block(src: str, start: int, end: int) -> str | None:
    """For kicks-style: a block contains a list of `~kK1 = ...; ~kK2 = ...;`.
    But strategy B treats the whole block as one unit. Fallback for naming
    when no header found.
    """
    m = VAR_RE.search(src, start, end)
    return m.group(1) if m else None


# ---------------------------------------------------------------------------
# Splitting drivers
# ---------------------------------------------------------------------------

def write_unit(out_path: Path, header_comment: str, body: str):
    out_path.parent.mkdir(parents=True, exist_ok=True)
    txt = f"// =========================================================\n//  {header_comment}\n// =========================================================\n{body}\n"
    out_path.write_text(txt, encoding="utf-8")


def split_strategy_A(src_path: Path, out_dir: Path, prefix_filter: str | None = None):
    """Each top-level statement `~var = ...;` -> file <var>.scd wrapped in
    `(...)` block.

    If the source file is a single big `(...)` block wrapping many
    `~var = ...;` statements (cas: short.scd, long.scd, ...), unwrap the
    outer block and split the inner statements.
    """
    src = src_path.read_text(encoding="utf-8")
    items = scan_top_level(src)

    # Detect "single big block" pattern: only one top-level item which is a block.
    # In that case, descend into the block content.
    if len(items) == 1 and items[0][2] == "block":
        s, e, _ = items[0]
        # strip outer ( ... ) (and optional trailing ;)
        text = src[s:e].rstrip()
        if text.endswith(";"):
            text = text[:-1].rstrip()
        # text looks like "( ... )"
        assert text[0] == "(" and text[-1] == ")"
        inner = text[1:-1]
        # parse inner as top-level statements
        inner_items = scan_top_level(inner)
        count = 0
        for (s2, e2, kind) in inner_items:
            if kind != "stmt":
                continue
            var = find_stmt_var(inner, s2, e2)
            if var is None:
                continue
            if prefix_filter and not var.startswith(prefix_filter):
                continue
            body_raw = inner[s2:e2].strip()
            wrapped = f"(\n{body_raw}\n)"
            header = f"~{var} -- extrait de {src_path.name}"
            write_unit(out_dir / f"{var}.scd", header, wrapped)
            count += 1
        return count

    count = 0
    for (s, e, kind) in items:
        if kind != "stmt":
            continue
        var = find_stmt_var(src, s, e)
        if var is None:
            continue
        if prefix_filter and not var.startswith(prefix_filter):
            continue
        body_raw = src[s:e].strip()
        # wrap in single top-level (...) block
        wrapped = f"(\n{body_raw}\n)"
        header = f"~{var} -- extrait de {src_path.name}"
        write_unit(out_dir / f"{var}.scd", header, wrapped)
        count += 1
    return count


def split_strategy_B(src_path: Path, out_dir: Path):
    """Each top-level `(...)` block -> file. Naming = slug of preceding header."""
    src = src_path.read_text(encoding="utf-8")
    items = scan_top_level(src)
    count = 0
    used_slugs: dict[str, int] = {}
    # also pick up top-level statements (assignations directes ~xxx = ...;)
    blocks_only = [it for it in items if it[2] == "block"]
    stmts_only = [it for it in items if it[2] == "stmt"]

    for (s, e, _kind) in blocks_only:
        body_raw = src[s:e].rstrip()
        # strip trailing `;` if present (we re-add as bare block)
        if body_raw.endswith(";"):
            body_raw = body_raw[:-1].rstrip()
        header_text = find_block_header(src, s)
        if not header_text:
            inner = find_inner_var_in_block(src, s, e)
            header_text = inner if inner else "block"
        slug = slugify(header_text)
        n = used_slugs.get(slug, 0) + 1
        used_slugs[slug] = n
        fname_slug = slug if n == 1 else f"{slug}_{n}"
        write_unit(out_dir / f"{fname_slug}.scd",
                   f"{header_text} -- extrait de {src_path.name}",
                   body_raw)
        count += 1

    # Strategy A fallback for top-level `~xx = ...;` statements
    for (s, e, _kind) in stmts_only:
        var = find_stmt_var(src, s, e)
        if var is None:
            continue
        body_raw = src[s:e].strip()
        wrapped = f"(\n{body_raw}\n)"
        header = f"~{var} -- extrait de {src_path.name}"
        write_unit(out_dir / f"{var}.scd", header, wrapped)
        count += 1

    return count


def backup(src_path: Path):
    rel = src_path.relative_to(ROOT)
    dst = ROOT / "_migrate" / (str(rel).replace("/", "_") + ".bak")
    dst.parent.mkdir(parents=True, exist_ok=True)
    if not dst.exists():
        shutil.copy2(src_path, dst)
    return dst


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    summary = []

    melodies_jobs = [
        ("short.scd", "short", "m"),
        ("long.scd", "long", "ml"),
        ("xlong.scd", "xlong", "mxl"),
        ("epic.scd", "epic", "mepic"),
    ]
    for fname, subdir, prefix in melodies_jobs:
        src = PAL / "melodies" / fname
        if not src.exists():
            print(f"skip (missing): {src}")
            continue
        backup(src)
        out_dir = PAL / "melodies" / subdir
        n = split_strategy_A(src, out_dir, prefix_filter=prefix)
        summary.append((str(src.relative_to(ROOT)), n, "A"))

    rhythm_files = ["drum_kits.scd", "patterns_genre.scd", "kicks.scd",
                    "percussions.scd", "sequences.scd", "fills.scd"]
    for fname in rhythm_files:
        src = PAL / "rhythm" / fname
        if not src.exists():
            print(f"skip (missing): {src}")
            continue
        backup(src)
        out_dir = PAL / "rhythm" / fname.removesuffix(".scd")
        n = split_strategy_B(src, out_dir)
        summary.append((str(src.relative_to(ROOT)), n, "B"))

    print("\n=== SPLIT SUMMARY ===")
    total = 0
    for path, n, strat in summary:
        print(f"  [{strat}] {path}: {n} unites")
        total += n
    print(f"  TOTAL: {total} fichiers generes")


if __name__ == "__main__":
    main()
